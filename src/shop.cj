package cj_memo

// shop.cj
// 商品 + 兑换 + 积分流水。
// - Product         商品
// - Order           兑换订单
// - PointRecord     积分流水（earn/spend/adjust）
// - JsonProductRepo 商品持久化（首次启动自动 seed）
// - JsonPointRepo   积分流水持久化
// - ShopService     列表 / 兑换 / 订单查询（兑换全程锁内，余额与流水同步落盘）

import stdx.encoding.json.*
import std.collection.ArrayList
import std.sync.Mutex

// ---------------- 商品 ----------------

public class Product {
    public var id: Int64
    public var name: String
    public var description: String
    public var cost: Int32
    public var stock: Int32        // -1 = 无限
    public var enabled: Bool
    public var createdAt: Int64

    public init(id: Int64, name: String, description: String,
                cost: Int32, stock: Int32, enabled: Bool, createdAt: Int64) {
        this.id = id
        this.name = name
        this.description = description
        this.cost = cost
        this.stock = stock
        this.enabled = enabled
        this.createdAt = createdAt
    }
}

// ---------------- 订单 ----------------

public class Order {
    public var id: Int64
    public var userId: Int64
    public var productId: Int64
    public var productName: String
    public var cost: Int32
    public var qty: Int32
    public var totalCost: Int32
    public var balanceAfter: Int32
    public var status: String   // "completed"
    public var createdAt: Int64

    public init(id: Int64, userId: Int64, productId: Int64, productName: String,
                cost: Int32, qty: Int32, totalCost: Int32, balanceAfter: Int32,
                status: String, createdAt: Int64) {
        this.id = id
        this.userId = userId
        this.productId = productId
        this.productName = productName
        this.cost = cost
        this.qty = qty
        this.totalCost = totalCost
        this.balanceAfter = balanceAfter
        this.status = status
        this.createdAt = createdAt
    }
}

// ---------------- 流水 ----------------

public class PointRecord {
    public var id: Int64
    public var userId: Int64
    public var delta: Int32       // 正=入账，负=消耗
    public var balanceAfter: Int32
    public var reason: PointReason
    public var refId: Int64       // 关联 event/order/id；0=无
    public var note: String
    public var createdAt: Int64

    public init(id: Int64, userId: Int64, delta: Int32, balanceAfter: Int32,
                reason: PointReason, refId: Int64, note: String, createdAt: Int64) {
        this.id = id
        this.userId = userId
        this.delta = delta
        this.balanceAfter = balanceAfter
        this.reason = reason
        this.refId = refId
        this.note = note
        this.createdAt = createdAt
    }
}

// ---------------- 商品仓库 ----------------

public class JsonProductRepo {
    private var products: ArrayList<Product>
    private let path: String
    private let lock: Mutex

    public init(path: String) {
        this.products = ArrayList<Product>()
        this.path = path
        this.lock = Mutex()
        load()
        if (products.size == 0) { seed() }
    }

    private func load(): Unit {
        let body = readFile(path)
        if (body.size == 0) { return }
        try {
            let jv = JsonValue.fromStr(body)
            if (!isObject(jv)) { return }
            let obj = jv.asObject()
            match (obj.get("products")) {
                case Some(v) =>
                    if (!isArray(v)) { return }
                    let arr = v.asArray()
                    var i: Int64 = 0
                    while (i < arr.size()) {
                        let item = arr[i]
                        if (isObject(item)) { products.add(parseProduct(item.asObject())) }
                        i++
                    }
                case None => ()
            }
        } catch (_: Exception) { }
    }

    public func save(): Unit {
        let arr = JsonArray()
        for (p in products) { arr.add(productToJson(p)) }
        let root = JsonObject()
        root.put("products", arr)
        writeFile(path, root.toString())
    }

    public func list(): ArrayList<Product> {
        lock.lock()
        try {
            let copy = ArrayList<Product>()
            for (p in products) { copy.add(p) }
            copy
        } finally { lock.unlock() }
    }

    public func findById(id: Int64): Option<Product> {
        lock.lock()
        try {
            for (p in products) { if (p.id == id) { return Some(p) } }
            None
        } finally { lock.unlock() }
    }

    public func nextId(): Int64 {
        lock.lock()
        try {
            var max: Int64 = 0
            for (p in products) { if (p.id > max) { max = p.id } }
            max + 1
        } finally { lock.unlock() }
    }

    // 在锁内被 ShopService 调用，用于扣减库存后回写。
    public func updateLocked(p: Product): Unit {
        var i: Int64 = 0
        while (i < products.size) {
            if (products[i].id == p.id) {
                products[i] = p
                save()
                return
            }
            i++
        }
    }

    private func seed(): Unit {
        let now = TimeUtil.nowMs()
        products.add(Product(1, "拿铁咖啡一杯", "奖励自己一杯香浓拿铁，短暂休息充电", 80, 99, true, now))
        products.add(Product(2, "珍珠奶茶一杯", "喝杯奶茶心情好，效率翻倍", 60, 99, true, now))
        products.add(Product(3, "电影票一张", "完成 10 件大事犒劳自己，看场电影", 200, 50, true, now))
        products.add(Product(4, "一本想读的书", "知识就是财富，读一本心仪已久的书", 150, 30, true, now))
        products.add(Product(5, "半天小长假", "积分兑换半天自由时间，做任何想做的事", 500, 10, true, now))
        products.add(Product(6, "自定义心愿", "联系管理员兑换任意等值商品，备注心愿即可", 100, -1, true, now))
        save()
    }
}

func parseProduct(obj: JsonObject): Product {
    Product(
        getInt(obj, "id"),
        getString(obj, "name"),
        getString(obj, "description"),
        getInt32(obj, "cost"),
        getInt32(obj, "stock"),
        getBool(obj, "enabled"),
        getInt(obj, "createdAt")
    )
}

func productToJson(p: Product): JsonValue {
    let obj = JsonObject()
    obj.put("id", JsonInt(p.id))
    obj.put("name", JsonString(p.name))
    obj.put("description", JsonString(p.description))
    obj.put("cost", JsonInt(Int64(p.cost)))
    obj.put("stock", JsonInt(Int64(p.stock)))
    obj.put("enabled", JsonBool(p.enabled))
    obj.put("createdAt", JsonInt(p.createdAt))
    obj
}

func productListJson(p: Product): JsonValue {
    let obj = JsonObject()
    obj.put("id", JsonInt(p.id))
    obj.put("name", JsonString(p.name))
    obj.put("description", JsonString(p.description))
    obj.put("cost", JsonInt(Int64(p.cost)))
    obj.put("stock", JsonInt(Int64(p.stock)))
    if (p.stock < 0) {
        obj.put("stockName", JsonString("无限"))
    } else {
        obj.put("stockName", JsonString(p.stock.toString()))
    }
    obj.put("enabled", JsonBool(p.enabled))
    obj
}

// ---------------- 流水仓库 ----------------

public class JsonPointRepo {
    private var records: ArrayList<PointRecord>
    private var orders: ArrayList<Order>
    private let path: String
    private let lock: Mutex

    public init(path: String) {
        this.records = ArrayList<PointRecord>()
        this.orders = ArrayList<Order>()
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
                    if (isArray(v)) {
                        let arr = v.asArray()
                        var i: Int64 = 0
                        while (i < arr.size()) {
                            let it = arr[i]
                            if (isObject(it)) { records.add(parseRecord(it.asObject())) }
                            i++
                        }
                    }
                case None => ()
            }
            match (obj.get("orders")) {
                case Some(v) =>
                    if (isArray(v)) {
                        let arr = v.asArray()
                        var i: Int64 = 0
                        while (i < arr.size()) {
                            let it = arr[i]
                            if (isObject(it)) { orders.add(parseOrder(it.asObject())) }
                            i++
                        }
                    }
                case None => ()
            }
        } catch (_: Exception) { }
    }

    public func save(): Unit {
        let recArr = JsonArray()
        for (r in records) { recArr.add(recordToJson(r)) }
        let ordArr = JsonArray()
        for (o in orders) { ordArr.add(orderToJson(o)) }
        let root = JsonObject()
        root.put("records", recArr)
        root.put("orders", ordArr)
        writeFile(path, root.toString())
    }

    // -------- record --------

    public func insertRecord(r: PointRecord): Unit {
        lock.lock()
        try {
            records.add(r)
            save()
        } finally { lock.unlock() }
    }

    public func nextRecordId(): Int64 {
        lock.lock()
        try {
            var max: Int64 = 0
            for (r in records) { if (r.id > max) { max = r.id } }
            max + 1
        } finally { lock.unlock() }
    }

    public func listRecordsByUser(userId: Int64, limit: Int32): ArrayList<PointRecord> {
        lock.lock()
        try {
            let r = ArrayList<PointRecord>()
            // 从尾部倒序拿 limit 条
            var i: Int64 = records.size - 1
            var n: Int32 = 0
            while (i >= 0 && n < limit) {
                let rec = records[i]
                if (rec.userId == userId) {
                    r.add(rec)
                    n++
                }
                i--
            }
            r
        } finally { lock.unlock() }
    }

    // -------- order --------

    public func insertOrder(o: Order): Unit {
        lock.lock()
        try {
            orders.add(o)
            save()
        } finally { lock.unlock() }
    }

    public func nextOrderId(): Int64 {
        lock.lock()
        try {
            var max: Int64 = 0
            for (o in orders) { if (o.id > max) { max = o.id } }
            max + 1
        } finally { lock.unlock() }
    }

    public func listOrdersByUser(userId: Int64): ArrayList<Order> {
        lock.lock()
        try {
            let r = ArrayList<Order>()
            var i: Int64 = orders.size - 1
            while (i >= 0) {
                if (orders[i].userId == userId) { r.add(orders[i]) }
                i--
            }
            r
        } finally { lock.unlock() }
    }
}

func parseRecord(obj: JsonObject): PointRecord {
    let reasonStr = getString(obj, "reason")
    var reason: PointReason = PointReason.AdminAdjust
    if (reasonStr == "earn_complete") { reason = PointReason.EarnComplete }
    else if (reasonStr == "spend_buy") { reason = PointReason.SpendBuy }
    else if (reasonStr == "earn_lottery") { reason = PointReason.EarnLottery }
    else if (reasonStr == "spend_lottery") { reason = PointReason.SpendLottery }
    PointRecord(
        getInt(obj, "id"),
        getInt(obj, "userId"),
        getInt32(obj, "delta"),
        getInt32(obj, "balanceAfter"),
        reason,
        getInt(obj, "refId"),
        getString(obj, "note"),
        getInt(obj, "createdAt")
    )
}

func recordToJson(r: PointRecord): JsonValue {
    let obj = JsonObject()
    obj.put("id", JsonInt(r.id))
    obj.put("userId", JsonInt(r.userId))
    obj.put("delta", JsonInt(Int64(r.delta)))
    obj.put("balanceAfter", JsonInt(Int64(r.balanceAfter)))
    obj.put("reason", JsonString(r.reason.toString()))
    obj.put("refId", JsonInt(r.refId))
    obj.put("note", JsonString(r.note))
    obj.put("createdAt", JsonInt(r.createdAt))
    obj
}

func parseOrder(obj: JsonObject): Order {
    Order(
        getInt(obj, "id"),
        getInt(obj, "userId"),
        getInt(obj, "productId"),
        getString(obj, "productName"),
        getInt32(obj, "cost"),
        getInt32(obj, "qty"),
        getInt32(obj, "totalCost"),
        getInt32(obj, "balanceAfter"),
        getString(obj, "status"),
        getInt(obj, "createdAt")
    )
}

func orderToJson(o: Order): JsonValue {
    let obj = JsonObject()
    obj.put("id", JsonInt(o.id))
    obj.put("userId", JsonInt(o.userId))
    obj.put("productId", JsonInt(o.productId))
    obj.put("productName", JsonString(o.productName))
    obj.put("cost", JsonInt(Int64(o.cost)))
    obj.put("qty", JsonInt(Int64(o.qty)))
    obj.put("totalCost", JsonInt(Int64(o.totalCost)))
    obj.put("balanceAfter", JsonInt(Int64(o.balanceAfter)))
    obj.put("status", JsonString(o.status))
    obj.put("createdAt", JsonInt(o.createdAt))
    obj
}

func orderListJson(o: Order): JsonValue {
    let obj = JsonObject()
    obj.put("id", JsonInt(o.id))
    obj.put("productId", JsonInt(o.productId))
    obj.put("productName", JsonString(o.productName))
    obj.put("cost", JsonInt(Int64(o.cost)))
    obj.put("qty", JsonInt(Int64(o.qty)))
    obj.put("totalCost", JsonInt(Int64(o.totalCost)))
    obj.put("balanceAfter", JsonInt(Int64(o.balanceAfter)))
    obj.put("status", JsonString(o.status))
    obj.put("createdAt", JsonInt(o.createdAt))
    obj
}

func recordListJson(r: PointRecord): JsonValue {
    let obj = JsonObject()
    obj.put("id", JsonInt(r.id))
    obj.put("delta", JsonInt(Int64(r.delta)))
    obj.put("balanceAfter", JsonInt(Int64(r.balanceAfter)))
    obj.put("reason", JsonString(r.reason.toString()))
    obj.put("reasonName", JsonString(reasonLabel(r.reason)))
    obj.put("refId", JsonInt(r.refId))
    obj.put("note", JsonString(r.note))
    obj.put("createdAt", JsonInt(r.createdAt))
    obj
}

func reasonLabel(r: PointReason): String {
    match (r) {
        case EarnComplete => "完成任务奖励"
        case SpendBuy => "兑换商品"
        case AdminAdjust => "管理员调整"
        case EarnLottery => "抽奖获得"
        case SpendLottery => "抽奖消耗"
    }
}

// ---------------- ShopService ----------------

public class ShopService {
    public let productRepo: JsonProductRepo
    public let pointRepo: JsonPointRepo
    public let userRepo: JsonUserRepo

    public init(productRepo: JsonProductRepo, pointRepo: JsonPointRepo, userRepo: JsonUserRepo) {
        this.productRepo = productRepo
        this.pointRepo = pointRepo
        this.userRepo = userRepo
    }

    public func listProducts(): SvcResult {
        let all = productRepo.list()
        let arr = JsonArray()
        for (p in all) {
            if (p.enabled) { arr.add(productListJson(p)) }
        }
        ok(okJsonJv(arr))
    }

    public func balance(userId: Int64): SvcResult {
        let obj = JsonObject()
        var total: Int32 = 0
        var level: Int8 = 1
        var completed: Int32 = 0
        match (userRepo.findById(userId)) {
            case Some(u) =>
                total = u.totalPoints
                level = u.level
                completed = u.completedCount
            case None => ()
        }
        obj.put("totalPoints", JsonInt(Int64(total)))
        obj.put("level", JsonInt(Int64(level)))
        obj.put("completedCount", JsonInt(Int64(completed)))
        let recent = pointRepo.listRecordsByUser(userId, 20)
        let arr = JsonArray()
        for (r in recent) { arr.add(recordListJson(r)) }
        obj.put("recent", arr)
        ok(okJsonJv(obj))
    }

    public func buy(userId: Int64, productId: Int64, qty: Int32): SvcResult {
        if (qty <= 0) { return err(400, "数量必须大于 0") }
        if (qty > 99) { return err(400, "单次最多兑换 99 件") }
        match (productRepo.findById(productId)) {
            case Some(p) =>
                if (!p.enabled) { return err(400, "该商品已下架") }
                if (p.stock >= 0 && p.stock < qty) {
                    return err(400, "库存不足，剩余 " + p.stock.toString())
                }
                let totalCost = p.cost * qty
                match (userRepo.findById(userId)) {
                    case Some(u) =>
                        if (u.totalPoints < totalCost) {
                            return err(400, "积分不足，需要 " + totalCost.toString() + " 分")
                        }
                        let now = TimeUtil.nowMs()
                        // 扣分 + 扣库存 + 写订单 + 写流水，全部同步落盘
                        u.totalPoints = u.totalPoints - totalCost
                        u.updateTime = now
                        userRepo.update(u)
                        if (p.stock >= 0) {
                            p.stock = p.stock - qty
                            productRepo.updateLocked(p)
                        }
                        let orderId = pointRepo.nextOrderId()
                        let order = Order(orderId, userId, p.id, p.name, p.cost, qty,
                                          totalCost, u.totalPoints, "completed", now)
                        pointRepo.insertOrder(order)
                        let recId = pointRepo.nextRecordId()
                        let rec = PointRecord(recId, userId, -totalCost, u.totalPoints,
                                              PointReason.SpendBuy, orderId,
                                              "兑换「" + p.name + "」x " + qty.toString(), now)
                        pointRepo.insertRecord(rec)
                        let resp = JsonObject()
                        resp.put("orderId", JsonInt(orderId))
                        resp.put("productId", JsonInt(p.id))
                        resp.put("productName", JsonString(p.name))
                        resp.put("qty", JsonInt(Int64(qty)))
                        resp.put("cost", JsonInt(Int64(p.cost)))
                        resp.put("totalCost", JsonInt(Int64(totalCost)))
                        resp.put("balanceAfter", JsonInt(Int64(u.totalPoints)))
                        ok(okJsonJv(resp))
                    case None => err(404, "用户不存在")
                }
            case None => err(404, "商品不存在")
        }
    }

    public func myOrders(userId: Int64): SvcResult {
        let list = pointRepo.listOrdersByUser(userId)
        let arr = JsonArray()
        for (o in list) { arr.add(orderListJson(o)) }
        ok(okJsonJv(arr))
    }

    public func myRecords(userId: Int64, limit: Int32): SvcResult {
        let list = pointRepo.listRecordsByUser(userId, if (limit <= 0) { 50 } else { limit })
        let arr = JsonArray()
        for (r in list) { arr.add(recordListJson(r)) }
        ok(okJsonJv(arr))
    }
}
