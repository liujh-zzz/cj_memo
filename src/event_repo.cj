package cj_memo

// event_repo.cj
// Event repository interface + JSON file implementation.

import stdx.encoding.json.*
import std.collection.ArrayList
import std.sync.Mutex

public interface EventRepo {
    func findById(id: Int64): Option<Note>
    func listByUser(userId: Int64): ArrayList<Note>
    func listByUserAndStatus(userId: Int64, status: EventStatus): ArrayList<Note>
    func list(): ArrayList<Note>
    func insert(note: Note): Unit
    func update(note: Note): Unit
    func delete(id: Int64): Unit
}

public class JsonEventRepo <: EventRepo {
    private var notes: ArrayList<Note>
    private let path: String
    private let lock: Mutex

    public init(path: String) {
        this.notes = ArrayList<Note>()
        this.path = path
        this.lock = Mutex()
        load()
    }

    private func load(): Unit {
        let body = readFile(path)
        if (body.size == 0) { return }
        try {
            let jv = JsonValue.fromStr(body)
            if (!isObject(jv)) { return }
            let obj = jv.asObject()
            match (obj.get("events")) {
                case Some(v) =>
                    if (!isArray(v)) { return }
                    let arr = v.asArray()
                    var i: Int64 = 0
                    while (i < arr.size()) {
                        let item = arr[i]
                        if (isObject(item)) {
                            notes.add(parseNote(item.asObject()))
                        }
                        i++
                    }
                case None => ()
            }
        } catch (_: Exception) {
            // ignore
        }
    }

    public func save(): Unit {
        let arr = JsonArray()
        for (n in notes) {
            arr.add(noteToJson(n))
        }
        let root = JsonObject()
        root.put("events", arr)
        writeFile(path, root.toString())
    }

    public func findById(id: Int64): Option<Note> {
        lock.lock()
        try {
            for (n in notes) { if (n.id == id) { return Some(n) } }
            None
        } finally { lock.unlock() }
    }

    public func listByUser(userId: Int64): ArrayList<Note> {
        lock.lock()
        try {
            let r = ArrayList<Note>()
            for (n in notes) { if (n.userId == userId) { r.add(n) } }
            r
        } finally { lock.unlock() }
    }

    public func listByUserAndStatus(userId: Int64, status: EventStatus): ArrayList<Note> {
        lock.lock()
        try {
            let r = ArrayList<Note>()
            for (n in notes) { if (n.userId == userId && n.status.equals(status)) { r.add(n) } }
            r
        } finally { lock.unlock() }
    }

    public func list(): ArrayList<Note> {
        lock.lock()
        try {
            let r = ArrayList<Note>()
            for (n in notes) { r.add(n) }
            r
        } finally { lock.unlock() }
    }

    public func insert(note: Note): Unit {
        lock.lock()
        try {
            notes.add(note)
            save()
        } finally { lock.unlock() }
    }

    public func update(note: Note): Unit {
        lock.lock()
        try {
            var i: Int64 = 0
            while (i < notes.size) {
                if (notes[i].id == note.id) {
                    notes[i] = note
                    save()
                    return
                }
                i++
            }
        } finally { lock.unlock() }
    }

    public func delete(id: Int64): Unit {
        lock.lock()
        try {
            var i: Int64 = 0
            while (i < notes.size) {
                if (notes[i].id == id) {
                    notes.remove(i..(i + 1))
                    save()
                    return
                }
                i++
            }
        } finally { lock.unlock() }
    }

    public func nextId(): Int64 {
        lock.lock()
        try {
            var max: Int64 = 0
            for (n in notes) { if (n.id > max) { max = n.id } }
            max + 1
        } finally { lock.unlock() }
    }
}

func parseNote(obj: JsonObject): Note {
    let tags = ArrayList<String>()
    match (obj.get("tags")) {
        case Some(v) =>
            if (isArray(v)) {
                let arr = v.asArray()
                var i: Int64 = 0
                while (i < arr.size()) {
                    let it = arr[i]
                    if (isString(it)) { tags.add(it.asString().getValue()) }
                    i++
                }
            }
        case None => ()
    }

    Note(
        getInt(obj, "id"),
        getInt(obj, "userId"),
        getString(obj, "title"),
        getString(obj, "content"),
        tags,
        EventPriority.fromInt(Int8(getInt(obj, "priority"))),
        getInt(obj, "deadline"),
        getInt32(obj, "remindMinutes"),
        EventStatus.fromInt(Int8(getInt(obj, "status"))),
        getInt(obj, "finishTime"),
        getBool(obj, "reminded"),
        getInt(obj, "createdAt"),
        getInt(obj, "updatedAt")
    )
}

func noteToJson(n: Note): JsonValue {
    let obj = JsonObject()
    obj.put("id", JsonInt(n.id))
    obj.put("userId", JsonInt(n.userId))
    obj.put("title", JsonString(n.title))
    obj.put("content", JsonString(n.content))
    let tagArr = JsonArray()
    for (t in n.tags) { tagArr.add(JsonString(t)) }
    obj.put("tags", tagArr)
    obj.put("priority", JsonInt(Int64(n.priority.toInt())))
    obj.put("deadline", JsonInt(n.deadline))
    obj.put("remindMinutes", JsonInt(Int64(n.remindMinutes)))
    obj.put("status", JsonInt(Int64(n.status.toInt())))
    obj.put("finishTime", JsonInt(n.finishTime))
    obj.put("reminded", JsonBool(n.reminded))
    obj.put("createdAt", JsonInt(n.createdAt))
    obj.put("updatedAt", JsonInt(n.updatedAt))
    obj
}