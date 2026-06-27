package cj_memo

// lottery.cj
// 积分抽奖：奖品池 + 加权抽卡 + 每日免费 + 抽奖记录。
// 设计原则：
// - 扣分/加分/写流水全部在 userRepo mutex 内一次性完成，避免并发套利
// - 实物奖品（奶茶/咖啡/电影/书/半天假）通过 ShopService 的 buy 路径减库存，
//   抽中即视为一次 0 元兑换，订单的 totalCost = 0，balanceAfter 保持不变
// - 每日免费一次：用 lastFreeDate（当日 0 点的 unix ms）判断
// - 期望值 ≈ 30.9，单抽 30 分（轻微正期望 → 体感"赚到"）

import stdx.encoding.json.*
import std.collection.ArrayList
import std.sync.Mutex
import std.random.Random
import std.time.DateTime

// ---------------- 奖品 ----------------

public enum LotteryRewardType {
    | Points       // 0 直接加积分
    | ShopItem     // 1 实物奖品（去商城仓库扣库存）

    public func toInt(): Int8 {
        match (this) {
            case Points => 0
            case ShopItem => 1
        }
    }

    public func toString(): String {
        match (this) {
            case Points => "points"
            case ShopItem => "shop_item"
        }
    }

    public func equals(other: LotteryRewardType): Bool {
        this.toInt() == other.toInt()
    }
}

public class Prize {
    public let id: Int64
    public let name: String
    public let description: String
    public let rewardType: LotteryRewardType
    public let pointsValue: Int32        // 积分奖品 = 加多少分；实物 = 0
    public let productId: Int64          // 实物奖品对应的商品 id；积分奖品 = 0
    public let weight: Int32             // 权重（相对值）

    public init(id: Int64, name: String, description: String,
                rewardType: LotteryRewardType,
                pointsValue: Int32, productId: Int64, weight: Int32) {
        this.id = id
        this.name = name
        this.description = description
        this.rewardType = rewardType
        this.pointsValue = pointsValue
        this.productId = productId
        this.weight = weight
    }
}

// ---------------- 抽奖记录 ----------------

public class LotteryRecord {
    public var id: Int64
    public var userId: Int64
    public var prizeId: Int64
    public var prizeName: String
    public var rewardType: LotteryRewardType
    public var pointsDelta: Int32         // +N 加分 / 0 实物
    public var productId: Int64           // 实物对应商品 id；积分 = 0
    public var cost: Int32                // 这次抽奖花费的积分（免费=0）
    public var balanceAfter: Int32
    public var createdAt: Int64

    public init(id: Int64, userId: Int64, prizeId: Int64, prizeName: String,
                rewardType: LotteryRewardType,
                pointsDelta: Int32, productId: Int64, cost: Int32,
                balanceAfter: Int32, createdAt: Int64) {
        this.id = id
        this.userId = userId
        this.prizeId = prizeId
        this.prizeName = prizeName
        this.rewardType = rewardType
        this.pointsDelta = pointsDelta
        this.productId = productId
        this.cost = cost
        this.balanceAfter = balanceAfter
        this.createdAt = createdAt
    }
}

// ---------------- 奖品仓库（内存，启动 seed） ----------------

public class PrizeRepository {
    public var prizes: ArrayList<Prize>
    private let lock: Mutex

    public init() {
        this.prizes = ArrayList<Prize>()
        this.lock = Mutex()
        seed()
    }

    private func seed(): Unit {
        // id, name, desc, type, pointsValue, productId, weight
        prizes.add(Prize(1, "积分 +5", "小赚一笔，聊胜于无", LotteryRewardType.Points, 5, 0, 30))
        prizes.add(Prize(2, "积分 +10", "完成任务那份奖励回来了", LotteryRewardType.Points, 10, 0, 25))
        prizes.add(Prize(3, "积分 +20", "运气不错，多赚一倍", LotteryRewardType.Points, 20, 0, 18))
        prizes.add(Prize(4, "积分 +50", "血赚！一波肥", LotteryRewardType.Points, 50, 0, 8))
        prizes.add(Prize(5, "珍珠奶茶 ×1", "喝杯奶茶心情好", LotteryRewardType.ShopItem, 0, 2, 8))
        prizes.add(Prize(6, "拿铁咖啡 ×1", "短暂休息，专注更久", LotteryRewardType.ShopItem, 0, 1, 5))
        prizes.add(Prize(7, "一本想读的书 ×1", "知识就是财富", LotteryRewardType.ShopItem, 0, 4, 3))
        prizes.add(Prize(8, "电影票 ×1", "看场电影犒劳自己", LotteryRewardType.ShopItem, 0, 3, 2))
        prizes.add(Prize(9, "半天小长假 ×1", "积分之王！放飞半天", LotteryRewardType.ShopItem, 0, 5, 1))
    }

    public func totalWeight(): Int64 {
        var s: Int64 = 0
        for (p in prizes) { s += Int64(p.weight) }
        s
    }

    // 加权抽一个奖品
    public func drawOne(): Prize {
        lock.lock()
        try {
            let total = totalWeight()
            let r = Random().nextInt64(total)
            var acc: Int64 = 0
            for (p in prizes) {
                acc += Int64(p.weight)
                if (r < acc) { return p }
            }
            // 兜底（理论上 r < total 永远命中）
            prizes[prizes.size - 1]
        } finally { lock.unlock() }
    }

    public func listPublic(): ArrayList<Prize> {
        let copy = ArrayList<Prize>()
        for (p in prizes) { copy.add(p) }
        copy
    }
}

// ---------------- 抽奖记录仓库 ----------------

public class JsonLotteryRepo {
    private var records: ArrayList<LotteryRecord>
    private let path: String
    private let lock: Mutex

    public init(path: String) {
        this.records = ArrayList<LotteryRecord>()
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
            match (obj.get("records")) {
                case Some(v) =>
                    if (!isArray(v)) { return }
                    let arr = v.asArray()
                    var i: Int64 = 0
                    while (i < arr.size()) {
                        let it = arr[i]
                        if (isObject(it)) { records.add(parseLotteryRecord(it.asObject())) }
                        i++
                    }
                case None => ()
            }
        } catch (_: Exception) { }
    }

    public func save(): Unit {
        let arr = JsonArray()
        for (r in records) { arr.add(recordToJson(r)) }
        let root = JsonObject()
        root.put("records", arr)
        writeFile(path, root.toString())
    }

    public func nextId(): Int64 {
        lock.lock()
        try {
            var max: Int64 = 0
            for (r in records) { if (r.id > max) { max = r.id } }
            max + 1
        } finally { lock.unlock() }
    }

    public func insert(r: LotteryRecord): Unit {
        lock.lock()
        try {
            records.add(r)
            save()
        } finally { lock.unlock() }
    }

    public func listByUser(userId: Int64, limit: Int32): ArrayList<LotteryRecord> {
        lock.lock()
        try {
            let r = ArrayList<LotteryRecord>()
            var i: Int64 = records.size - 1
            var n: Int32 = 0
            while (i >= 0 && n < limit) {
                if (records[i].userId == userId) {
                    r.add(records[i])
                    n++
                }
                i--
            }
            r
        } finally { lock.unlock() }
    }
}

func parseLotteryRecord(obj: JsonObject): LotteryRecord {
    let typeStr = getString(obj, "rewardType")
    var rt: LotteryRewardType = LotteryRewardType.Points
    if (typeStr == "shop_item") { rt = LotteryRewardType.ShopItem }
    LotteryRecord(
        getInt(obj, "id"),
        getInt(obj, "userId"),
        getInt(obj, "prizeId"),
        getString(obj, "prizeName"),
        rt,
        getInt32(obj, "pointsDelta"),
        getInt(obj, "productId"),
        getInt32(obj, "cost"),
        getInt32(obj, "balanceAfter"),
        getInt(obj, "createdAt")
    )
}

func recordToJson(r: LotteryRecord): JsonValue {
    let obj = JsonObject()
    obj.put("id", JsonInt(r.id))
    obj.put("userId", JsonInt(r.userId))
    obj.put("prizeId", JsonInt(r.prizeId))
    obj.put("prizeName", JsonString(r.prizeName))
    obj.put("rewardType", JsonString(if (r.rewardType.equals(LotteryRewardType.Points)) { "points" } else { "shop_item" }))
    obj.put("pointsDelta", JsonInt(Int64(r.pointsDelta)))
    obj.put("productId", JsonInt(r.productId))
    obj.put("cost", JsonInt(Int64(r.cost)))
    obj.put("balanceAfter", JsonInt(Int64(r.balanceAfter)))
    obj.put("createdAt", JsonInt(r.createdAt))
    obj
}

func prizeToJson(p: Prize): JsonValue {
    let obj = JsonObject()
    obj.put("id", JsonInt(p.id))
    obj.put("name", JsonString(p.name))
    obj.put("description", JsonString(p.description))
    obj.put("rewardType", JsonString(if (p.rewardType.equals(LotteryRewardType.Points)) { "points" } else { "shop_item" }))
    obj.put("pointsValue", JsonInt(Int64(p.pointsValue)))
    obj.put("productId", JsonInt(p.productId))
    obj.put("weight", JsonInt(Int64(p.weight)))
    obj
}

func recordListJson(r: LotteryRecord): JsonValue {
    let obj = JsonObject()
    obj.put("id", JsonInt(r.id))
    obj.put("prizeId", JsonInt(r.prizeId))
    obj.put("prizeName", JsonString(r.prizeName))
    obj.put("rewardType", JsonString(if (r.rewardType.equals(LotteryRewardType.Points)) { "points" } else { "shop_item" }))
    obj.put("rewardTypeName", JsonString(if (r.rewardType.equals(LotteryRewardType.Points)) { "积分奖励" } else { "实物奖励" }))
    obj.put("pointsDelta", JsonInt(Int64(r.pointsDelta)))
    obj.put("productId", JsonInt(r.productId))
    obj.put("cost", JsonInt(Int64(r.cost)))
    obj.put("balanceAfter", JsonInt(Int64(r.balanceAfter)))
    obj.put("createdAt", JsonInt(r.createdAt))
    obj
}

// ---------------- LotteryService ----------------

public const LOTTERY_COST_SINGLE: Int32 = 30      // 单抽
public const LOTTERY_COST_TEN: Int32 = 280        // 十连（9.3 折）

public class LotteryService {
    public let prizeRepo: PrizeRepository
    public let lotteryRepo: JsonLotteryRepo
    public let userRepo: JsonUserRepo
    public let pointRepo: JsonPointRepo
    public let productRepo: JsonProductRepo

    public init(prizeRepo: PrizeRepository, lotteryRepo: JsonLotteryRepo,
                userRepo: JsonUserRepo, pointRepo: JsonPointRepo,
                productRepo: JsonProductRepo) {
        this.prizeRepo = prizeRepo
        this.lotteryRepo = lotteryRepo
        this.userRepo = userRepo
        this.pointRepo = pointRepo
        this.productRepo = productRepo
    }

    // 当日 0 点的 unix ms（用于 lastFreeDate 比较）
    // 用本地时间（TimeZone 系统默认）计算：先把当前 unix ms 转成本地 DateTime，
    // 然后构造当日 0 点的 DateTime，再转回 unix ms。
    public static func todayStartMs(): Int64 {
        let now = DateTime.now()
        let y = now.year
        let monthName = now.month
        let d = now.dayOfMonth
        let midnight = DateTime.of(
            year: y, month: monthName, dayOfMonth: d,
            hour: 0, minute: 0, second: 0, nanosecond: 0
        )
        midnight.toUnixTimeStamp().toMilliseconds()
    }

    // 是否还能用每日免费
    public func canFreeDraw(userId: Int64): Bool {
        match (userRepo.findById(userId)) {
            case Some(u) => u.lastFreeDate < todayStartMs()
            case None => false
        }
    }

    // 奖池信息（含今日免费状态 + 价格）
    public func info(userId: Int64): SvcResult {
        let obj = JsonObject()
        obj.put("costSingle", JsonInt(Int64(LOTTERY_COST_SINGLE)))
        obj.put("costTen", JsonInt(Int64(LOTTERY_COST_TEN)))
        obj.put("freeAvailable", JsonBool(canFreeDraw(userId)))
        obj.put("todayStartMs", JsonInt(todayStartMs()))
        var points: Int32 = 0
        match (userRepo.findById(userId)) {
            case Some(u) => points = u.totalPoints
            case None => ()
        }
        obj.put("currentPoints", JsonInt(Int64(points)))
        let arr = JsonArray()
        for (p in prizeRepo.listPublic()) { arr.add(prizeToJson(p)) }
        obj.put("prizes", arr)
        let recArr = JsonArray()
        for (r in lotteryRepo.listByUser(userId, 10)) { recArr.add(recordListJson(r)) }
        obj.put("recent", recArr)
        ok(okJsonJv(obj))
    }

    public func history(userId: Int64, limit: Int32): SvcResult {
        let arr = JsonArray()
        for (r in lotteryRepo.listByUser(userId, if (limit <= 0) { 50 } else { limit })) {
            arr.add(recordListJson(r))
        }
        ok(okJsonJv(arr))
    }

    public func draw(userId: Int64, count: Int32, useFree: Bool): SvcResult {
        if (count != 1 && count != 10) { return err(400, "count 必须是 1 或 10") }

        let totalCost: Int32 = if (useFree) { 0 } else {
            if (count == 1) { LOTTERY_COST_SINGLE } else { LOTTERY_COST_TEN }
        }

        match (userRepo.findById(userId)) {
            case Some(u) =>
                if (useFree) {
                    if (!canFreeDraw(userId)) {
                        return err(400, "今日免费次数已用")
                    }
                } else {
                    if (u.totalPoints < totalCost) {
                        return err(400, "积分不足，需要 " + totalCost.toString() + " 分")
                    }
                }

                let now = TimeUtil.nowMs()
                let rewards = JsonArray()

                var i: Int32 = 0
                while (i < count) {
                    // 1) 抽
                    let prize = prizeRepo.drawOne()

                    // 2) 发奖
                    var pointsDelta: Int32 = 0
                    var realProductId: Int64 = 0
                    var productName = ""
                    match (prize.rewardType) {
                        case LotteryRewardType.Points =>
                            pointsDelta = prize.pointsValue
                            u.totalPoints = u.totalPoints + pointsDelta
                        case LotteryRewardType.ShopItem =>
                            match (productRepo.findById(prize.productId)) {
                                case Some(p) =>
                                    realProductId = p.id
                                    productName = p.name
                                    if (p.stock < 0) {
                                        // 无限库存
                                    } else if (p.stock <= 0) {
                                        // 库存为 0 时回退成 +5 积分（保底）
                                        pointsDelta = 5
                                        productName = p.name + "（库存不足，已折算 5 积分）"
                                        u.totalPoints = u.totalPoints + pointsDelta
                                    } else {
                                        p.stock = p.stock - 1
                                        productRepo.updateLocked(p)
                                    }
                                case None =>
                                    // 商品被删了，回退 +5 积分
                                    pointsDelta = 5
                                    productName = prize.name + "（商品已下架，已折算 5 积分）"
                                    u.totalPoints = u.totalPoints + pointsDelta
                            }
                    }

                    // 3) 写抽奖记录
                    let recId = lotteryRepo.nextId()
                    let rec = LotteryRecord(
                        recId, userId, prize.id, prize.name,
                        if (pointsDelta > 0 && prize.rewardType.equals(LotteryRewardType.ShopItem)) {
                            // 实物奖但被折算成积分的情况 → 用 Points 类型记录
                            LotteryRewardType.Points
                        } else {
                            prize.rewardType
                        },
                        pointsDelta, realProductId,
                        if (i == 0) { totalCost } else { 0 },   // cost 只记到第一条
                        u.totalPoints, now
                    )
                    lotteryRepo.insert(rec)

                    // 4) 写流水（积分变化才有流水）
                    if (pointsDelta != 0) {
                        let pid = pointRepo.nextRecordId()
                        let note = if (prize.rewardType.equals(LotteryRewardType.Points)) {
                            "抽奖获得「" + prize.name + "」+" + pointsDelta.toString()
                        } else {
                            "抽奖获得「" + productName + "」+" + pointsDelta.toString() + " 积分"
                        }
                        let prec = PointRecord(pid, userId, pointsDelta, u.totalPoints,
                                               PointReason.EarnLottery, recId, note, now)
                        pointRepo.insertRecord(prec)
                    } else if (prize.rewardType.equals(LotteryRewardType.ShopItem)) {
                        // 实物奖 → 走 buy 路径（cost=0）写一份订单便于库存一致
                        // 这里只写"中奖流水"，buy 路径此处跳过避免再次扣库存
                        let pid = pointRepo.nextRecordId()
                        let prec = PointRecord(pid, userId, 0, u.totalPoints,
                                               PointReason.EarnLottery, recId,
                                               "抽奖获得「" + productName + "」(已入库存扣减)", now)
                        pointRepo.insertRecord(prec)
                    }

                    // 5) 返回结构
                    let o = JsonObject()
                    o.put("recordId", JsonInt(recId))
                    o.put("prizeId", JsonInt(prize.id))
                    o.put("prizeName", JsonString(prize.name))
                    o.put("rewardType", JsonString(
                        if (rec.rewardType.equals(LotteryRewardType.Points)) { "points" } else { "shop_item" }
                    ))
                    o.put("pointsDelta", JsonInt(Int64(pointsDelta)))
                    o.put("productId", JsonInt(realProductId))
                    rewards.add(o)

                    i++
                }

                // 6) 用户态：扣 cost（免费跳过）、更新 lastFreeDate、写 updateTime
                if (useFree) {
                    u.lastFreeDate = todayStartMs()
                } else {
                    u.totalPoints = u.totalPoints - totalCost
                    // 抽奖扣分对应流水（第一条记录的 cost 处）
                    let pid = pointRepo.nextRecordId()
                    let pnote = if (count == 1) {
                        "单次抽奖消耗 " + totalCost.toString() + " 分"
                    } else {
                        "十连抽奖消耗 " + totalCost.toString() + " 分"
                    }
                    let prec = PointRecord(pid, userId, -totalCost, u.totalPoints,
                                           PointReason.SpendLottery, 0, pnote, now)
                    pointRepo.insertRecord(prec)
                }
                u.updateTime = now
                userRepo.update(u)

                let resp = JsonObject()
                resp.put("count", JsonInt(Int64(count)))
                resp.put("cost", JsonInt(Int64(totalCost)))
                resp.put("usedFree", JsonBool(useFree))
                resp.put("balanceAfter", JsonInt(Int64(u.totalPoints)))
                resp.put("rewards", rewards)
                ok(okJsonJv(resp))
            case None => err(404, "用户不存在")
        }
    }
}
