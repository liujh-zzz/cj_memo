package cj_memo

// handlers.cj
// HTTP handlers for user + event endpoints. 所有解析走 stdx.encoding.json。

import stdx.encoding.json.*
import std.collection.ArrayList
import std.convert.Parsable

// 统一的成功/失败响应
public func respond(r: SvcResult): HttpResponse {
    match (r) {
        case Ok(body) => HttpResponse.json(200, body)
        case Err(code, msg) => HttpResponse.json(code, errJsonJv(code, msg))
    }
}

// 把请求 body 解析为 JsonObject，失败返回 None。
func parseBodyObject(body: String): ?JsonObject {
    try {
        let jv = JsonValue.fromStr(body)
        if (isObject(jv)) { Some(jv.asObject()) } else { None }
    } catch (_: Exception) { None }
}

// 从 JsonObject 中读 tags 数组。
func readTags(obj: JsonObject): ArrayList<String> {
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
    tags
}

// ---------------- User handlers ----------------

public class UserHandler <: RequestHandler {
    public let authService: AuthService

    public init(authService: AuthService) {
        this.authService = authService
    }

    public func handle(req: HttpRequest): HttpResponse {
        let opt = parseBodyObject(req.body)
        var username = ""
        var password = ""
        match (opt) {
            case Some(obj) =>
                username = getString(obj, "username")
                password = getString(obj, "password")
            case None => ()
        }
        if (req.method == "POST" && req.path == "/api/user/register") {
            return respond(authService.register(username, password))
        }
        if (req.method == "POST" && req.path == "/api/user/login") {
            return respond(authService.login(username, password))
        }
        HttpResponse.json(404, errJsonJv(404, "user endpoint not found"))
    }
}

public class UserInfoHandler <: RequestHandler {
    public let authService: AuthService

    public init(authService: AuthService) {
        this.authService = authService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        respond(authService.userInfo(userId))
    }
}

// ---------------- Event handlers ----------------

public class EventCreateHandler <: RequestHandler {
    public let eventService: EventService

    public init(eventService: EventService) {
        this.eventService = eventService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        let opt = parseBodyObject(req.body)
        var title = ""
        var content = ""
        var deadline: Int64 = 0
        var rm: Int32 = 60
        var prio: EventPriority = EventPriority.Medium
        let tags = ArrayList<String>()
        match (opt) {
            case Some(obj) =>
                title = getString(obj, "title")
                content = getString(obj, "content")
                deadline = getInt(obj, "deadline")
                rm = getInt32(obj, "remindMinutes")
                let pInt = Int8(getInt(obj, "priority"))
                prio = EventPriority.fromInt(pInt)
                let t = readTags(obj)
                var k: Int64 = 0
                while (k < t.size) { tags.add(t[k]); k++ }
            case None => ()
        }
        respond(eventService.create(userId, title, content, tags, prio, deadline, rm))
    }
}

public class EventListHandler <: RequestHandler {
    public let eventService: EventService

    public init(eventService: EventService) {
        this.eventService = eventService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        var statusOpt: Option<EventStatus> = None
        var priorityOpt: Option<EventPriority> = None
        var queryOpt: Option<String> = None
        let q = req.query
        if (q.size > 0) {
            let parts = splitQuery(q)
            var i: Int64 = 0
            while (i < parts.size) {
                let p = parts[i]
                let eq = findByte(p, UInt8(61))
                if (eq >= 0) {
                    let k = p[0..eq]
                    let v = p[eq + 1..]
                    if (k == "status") {
                        if (v == "pending") { statusOpt = Some(EventStatus.Pending) }
                        else if (v == "completed") { statusOpt = Some(EventStatus.Completed) }
                        else if (v == "expired") { statusOpt = Some(EventStatus.Expired) }
                    } else if (k == "priority") {
                        let pi = Int8(parseIntOr(v, 1))
                        priorityOpt = Some(EventPriority.fromInt(pi))
                    } else if (k == "q") {
                        if (v.size > 0) { queryOpt = Some(v) }
                    }
                }
                i++
            }
        }
        respond(eventService.list(userId, statusOpt, priorityOpt, queryOpt))
    }
}

public class EventUpdateHandler <: RequestHandler {
    public let eventService: EventService

    public init(eventService: EventService) {
        this.eventService = eventService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        let prefix = "/api/event/"
        if (req.path.size <= prefix.size) {
            return HttpResponse.json(400, errJsonJv(400, "缺少事件 ID"))
        }
        let idStr = req.path[prefix.size..]
        let id = Int64.parse(idStr)
        let opt = parseBodyObject(req.body)
        var title = ""
        var content = ""
        var deadline: Int64 = 0
        var rm: Int32 = 60
        var prio: EventPriority = EventPriority.Medium
        let tags = ArrayList<String>()
        match (opt) {
            case Some(obj) =>
                title = getString(obj, "title")
                content = getString(obj, "content")
                deadline = getInt(obj, "deadline")
                rm = getInt32(obj, "remindMinutes")
                let pInt = Int8(getInt(obj, "priority"))
                prio = EventPriority.fromInt(pInt)
                let t = readTags(obj)
                var k: Int64 = 0
                while (k < t.size) { tags.add(t[k]); k++ }
            case None => ()
        }
        respond(eventService.update(userId, id, title, content, tags, prio, deadline, rm))
    }
}

public class EventDeleteHandler <: RequestHandler {
    public let eventService: EventService

    public init(eventService: EventService) {
        this.eventService = eventService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        let prefix = "/api/event/"
        if (req.path.size <= prefix.size) {
            return HttpResponse.json(400, errJsonJv(400, "缺少事件 ID"))
        }
        let idStr = req.path[prefix.size..]
        let id = Int64.parse(idStr)
        respond(eventService.delete(userId, id))
    }
}

public class EventCompleteHandler <: RequestHandler {
    public let eventService: EventService

    public init(eventService: EventService) {
        this.eventService = eventService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        let prefix = "/api/event/"
        let suffix = "/complete"
        if (req.path.size <= prefix.size + suffix.size) {
            return HttpResponse.json(400, errJsonJv(400, "缺少事件 ID"))
        }
        if (req.path[req.path.size - suffix.size..] != suffix) {
            return HttpResponse.json(404, errJsonJv(404, ""))
        }
        let idStr = req.path[prefix.size..req.path.size - suffix.size]
        let id = Int64.parse(idStr)
        respond(eventService.complete(userId, id))
    }
}

public class EventUpcomingHandler <: RequestHandler {
    public let eventService: EventService

    public init(eventService: EventService) {
        this.eventService = eventService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        respond(eventService.scanReminders(userId))
    }
}

// ---------------- Shop handlers ----------------

public class ShopProductListHandler <: RequestHandler {
    public let shopService: ShopService

    public init(shopService: ShopService) {
        this.shopService = shopService
    }

    public func handle(req: HttpRequest): HttpResponse {
        respond(shopService.listProducts())
    }
}

public class ShopBuyHandler <: RequestHandler {
    public let shopService: ShopService

    public init(shopService: ShopService) {
        this.shopService = shopService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        let opt = parseBodyObject(req.body)
        var productId: Int64 = 0
        var qty: Int32 = 1
        match (opt) {
            case Some(obj) =>
                productId = getInt(obj, "productId")
                qty = getInt32(obj, "qty")
            case None => ()
        }
        respond(shopService.buy(userId, productId, qty))
    }
}

public class ShopOrdersHandler <: RequestHandler {
    public let shopService: ShopService

    public init(shopService: ShopService) {
        this.shopService = shopService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        respond(shopService.myOrders(userId))
    }
}

public class UserPointsHandler <: RequestHandler {
    public let shopService: ShopService

    public init(shopService: ShopService) {
        this.shopService = shopService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        respond(shopService.balance(userId))
    }
}

// ---------------- Lottery handlers ----------------

public class LotteryInfoHandler <: RequestHandler {
    public let lotteryService: LotteryService

    public init(lotteryService: LotteryService) {
        this.lotteryService = lotteryService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        respond(lotteryService.info(userId))
    }
}

public class LotteryDrawHandler <: RequestHandler {
    public let lotteryService: LotteryService

    public init(lotteryService: LotteryService) {
        this.lotteryService = lotteryService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        let opt = parseBodyObject(req.body)
        var count: Int32 = 1
        var useFree: Bool = false
        match (opt) {
            case Some(obj) =>
                count = getInt32(obj, "count")
                useFree = getBool(obj, "useFree")
            case None => ()
        }
        respond(lotteryService.draw(userId, count, useFree))
    }
}

public class LotteryHistoryHandler <: RequestHandler {
    public let lotteryService: LotteryService

    public init(lotteryService: LotteryService) {
        this.lotteryService = lotteryService
    }

    public func handle(req: HttpRequest): HttpResponse {
        HttpResponse.json(404, errJsonJv(404, ""))
    }

    public func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        respond(lotteryService.history(userId, 50))
    }
}