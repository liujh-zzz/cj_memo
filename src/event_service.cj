package cj_memo

// event_service.cj
// 事件 CRUD + 标记完成 + 提醒扫描。

import stdx.encoding.json.*
import std.collection.ArrayList

public class EventService {
    public let eventRepo: JsonEventRepo
    public let userRepo: JsonUserRepo
    public let rewardService: RewardService

    public init(eventRepo: JsonEventRepo, userRepo: JsonUserRepo, rewardService: RewardService) {
        this.eventRepo = eventRepo
        this.userRepo = userRepo
        this.rewardService = rewardService
    }

    public func create(
        userId: Int64, title: String, content: String,
        tags: ArrayList<String>, priority: EventPriority,
        deadline: Int64, remindMinutes: Int32
    ): SvcResult {
        if (title.size < 1 || title.size > 50) {
            return err(400, "标题长度应为 1-50 字符")
        }
        if (content.size > 500) {
            return err(400, "详情最多 500 字符")
        }
        let now = TimeUtil.nowMs()
        if (deadline <= now) {
            return err(400, "截止时间必须晚于当前时间")
        }
        if (remindMinutes < 0) {
            return err(400, "提醒时长不能为负")
        }
        let id = eventRepo.nextId()
        let n = Note(id, userId, title, content, tags, priority, deadline, remindMinutes,
                     EventStatus.Pending, 0, false, now, now)
        eventRepo.insert(n)
        let obj = JsonObject()
        obj.put("eventId", JsonInt(id))
        ok(okJsonJv(obj))
    }

    public func list(
        userId: Int64, statusOpt: Option<EventStatus>,
        priorityOpt: Option<EventPriority>, queryOpt: Option<String>
    ): SvcResult {
        var all = eventRepo.listByUser(userId)
        let filtered = ArrayList<Note>()
        match (statusOpt) {
            case Some(s) =>
                for (n in all) { if (n.status.equals(s)) { filtered.add(n) } }
            case None =>
                for (n in all) { filtered.add(n) }
        }
        var narrowed = filtered
        match (priorityOpt) {
            case Some(p) =>
                let tmp = ArrayList<Note>()
                for (n in narrowed) { if (n.priority.equals(p)) { tmp.add(n) } }
                narrowed = tmp
            case None => ()
        }
        match (queryOpt) {
            case Some(q) =>
                let kw = q.toAsciiLower()
                let tmp = ArrayList<Note>()
                for (n in narrowed) {
                    if (matchesQuery(n, kw)) { tmp.add(n) }
                }
                narrowed = tmp
            case None => ()
        }
        let now = TimeUtil.nowMs()
        var mutated = false
        var i: Int64 = 0
        while (i < filtered.size) {
            let n = filtered[i]
            if (n.status.equals(EventStatus.Pending) && n.deadline < now) {
                n.status = EventStatus.Expired
                n.updatedAt = now
                eventRepo.update(n)
                mutated = true
            }
            i++
        }
        if (mutated) {
            all = eventRepo.listByUser(userId)
            filtered.clear()
            match (statusOpt) {
                case Some(s) =>
                    for (n in all) { if (n.status.equals(s)) { filtered.add(n) } }
                case None =>
                    for (n in all) { filtered.add(n) }
            }
            narrowed = filtered
            match (priorityOpt) {
                case Some(p) =>
                    let tmp = ArrayList<Note>()
                    for (n in narrowed) { if (n.priority.equals(p)) { tmp.add(n) } }
                    narrowed = tmp
                case None => ()
            }
            match (queryOpt) {
                case Some(q) =>
                    let kw = q.toAsciiLower()
                    let tmp = ArrayList<Note>()
                    for (n in narrowed) {
                        if (matchesQuery(n, kw)) { tmp.add(n) }
                    }
                    narrowed = tmp
                case None => ()
            }
        }
        sortByPriorityThenDeadline(narrowed)
        let arr = JsonArray()
        for (n in narrowed) { arr.add(noteListJson(n)) }
        ok(okJsonJv(arr))
    }

    public func update(
        userId: Int64, eventId: Int64, title: String, content: String,
        tags: ArrayList<String>, priority: EventPriority,
        deadline: Int64, remindMinutes: Int32
    ): SvcResult {
        match (eventRepo.findById(eventId)) {
            case Some(n) =>
                if (n.userId != userId) { return err(403, "无权限操作该事件") }
                if (!n.status.equals(EventStatus.Pending)) {
                    return err(400, "已完成 / 已过期事件不可编辑")
                }
                if (title.size < 1 || title.size > 50) {
                    return err(400, "标题长度应为 1-50 字符")
                }
                if (content.size > 500) {
                    return err(400, "详情最多 500 字符")
                }
                n.title = title
                n.content = content
                n.tags = tags
                n.priority = priority
                n.deadline = deadline
                n.remindMinutes = remindMinutes
                n.updatedAt = TimeUtil.nowMs()
                n.reminded = false
                eventRepo.update(n)
                let obj = JsonObject()
                obj.put("eventId", JsonInt(n.id))
                ok(okJsonJv(obj))
            case None => err(404, "事件不存在")
        }
    }

    public func delete(userId: Int64, eventId: Int64): SvcResult {
        match (eventRepo.findById(eventId)) {
            case Some(n) =>
                if (n.userId != userId) { return err(403, "无权限") }
                eventRepo.delete(eventId)
                let obj = JsonObject()
                obj.put("eventId", JsonInt(eventId))
                ok(okJsonJv(obj))
            case None => err(404, "事件不存在")
        }
    }

    public func complete(userId: Int64, eventId: Int64): SvcResult {
        match (eventRepo.findById(eventId)) {
            case Some(n) =>
                if (n.userId != userId) { return err(403, "无权限") }
                if (n.status.equals(EventStatus.Completed)) {
                    return err(400, "事件已经完成")
                }
                let now = TimeUtil.nowMs()
                let onTime = now <= n.deadline
                n.status = EventStatus.Completed
                n.finishTime = now
                n.updatedAt = now
                eventRepo.update(n)
                let (gained, promote) = rewardService.grantForCompletion(userId, onTime)
                let phrase = Encouragement.pickRandom()
                let userOpt = userRepo.findById(userId)
                var totalPoints: Int32 = 0
                var level: Int8 = 1
                match (userOpt) {
                    case Some(u) =>
                        totalPoints = u.totalPoints
                        level = u.level
                    case None => ()
                }
                let obj = JsonObject()
                obj.put("eventId", JsonInt(n.id))
                obj.put("gainedPoints", JsonInt(Int64(gained)))
                obj.put("totalPoints", JsonInt(Int64(totalPoints)))
                obj.put("level", JsonInt(Int64(level)))
                obj.put("encouragement", JsonString(phrase))
                obj.put("promote", JsonString(promote))
                obj.put("onTime", JsonBool(onTime))
                ok(okJsonJv(obj))
            case None => err(404, "事件不存在")
        }
    }

    public func scanReminders(userId: Int64): SvcResult {
        let now = TimeUtil.nowMs()
        let window: Int64 = 60_000
        let all = eventRepo.listByUser(userId)
        let arr = JsonArray()
        var i: Int64 = 0
        while (i < all.size) {
            let n = all[i]
            if (n.status.equals(EventStatus.Pending) && !n.reminded) {
                let remindAt = n.deadline - Int64(n.remindMinutes) * 60_000
                if (remindAt >= now - window && remindAt <= now + window) {
                    n.reminded = true
                    n.updatedAt = now
                    eventRepo.update(n)
                    arr.add(noteListJson(n))
                }
            }
            i++
        }
        ok(okJsonJv(arr))
    }
}

func sortByDeadline(notes: ArrayList<Note>): Unit {
    let n = notes.size
    if (n <= 1) { return }
    var i: Int64 = 0
    while (i < n) {
        var j: Int64 = 0
        while (j < n - 1 - i) {
            if (notes[j].deadline > notes[j + 1].deadline) {
                let tmp = notes[j]
                notes[j] = notes[j + 1]
                notes[j + 1] = tmp
            }
            j++
        }
        i++
    }
}

func sortByPriorityThenDeadline(notes: ArrayList<Note>): Unit {
    let n = notes.size
    if (n <= 1) { return }
    var i: Int64 = 0
    while (i < n) {
        var j: Int64 = 0
        while (j < n - 1 - i) {
            let a = notes[j]
            let b = notes[j + 1]
            let swap = a.priority.toInt() < b.priority.toInt() ||
                       (a.priority.toInt() == b.priority.toInt() && a.deadline > b.deadline)
            if (swap) {
                let tmp = notes[j]
                notes[j] = notes[j + 1]
                notes[j + 1] = tmp
            }
            j++
        }
        i++
    }
}

func matchesQuery(n: Note, kw: String): Bool {
    if (n.title.toAsciiLower().contains(kw)) { return true }
    if (n.content.toAsciiLower().contains(kw)) { return true }
    for (t in n.tags) {
        if (t.toAsciiLower().contains(kw)) { return true }
    }
    false
}

func noteListJson(n: Note): JsonValue {
    let obj = JsonObject()
    obj.put("id", JsonInt(n.id))
    obj.put("userId", JsonInt(n.userId))
    obj.put("title", JsonString(n.title))
    obj.put("content", JsonString(n.content))
    let tags = JsonArray()
    for (t in n.tags) { tags.add(JsonString(t)) }
    obj.put("tags", tags)
    obj.put("priority", JsonInt(Int64(n.priority.toInt())))
    obj.put("priorityName", JsonString(n.priority.toString()))
    obj.put("deadline", JsonInt(n.deadline))
    obj.put("remindMinutes", JsonInt(Int64(n.remindMinutes)))
    obj.put("status", JsonInt(Int64(n.status.toInt())))
    obj.put("statusName", JsonString(n.status.toString()))
    obj.put("finishTime", JsonInt(n.finishTime))
    obj.put("createdAt", JsonInt(n.createdAt))
    obj.put("updatedAt", JsonInt(n.updatedAt))
    obj
}