package cj_memo

// main.cj
// Assemble the cj-memo service and start the HTTP server on port 8080.

import stdx.encoding.json.*

main(): Int64 {
    eprintln("[cj-memo] starting up...")

    let dataDir = "data"
    TokenStore.setPersistPath(dataDir + "/tokens.json")
    let userRepo = JsonUserRepo(dataDir + "/users.json")
    eprintln("[cj-memo] user repo loaded")
    let eventRepo = JsonEventRepo(dataDir + "/events.json")
    eprintln("[cj-memo] event repo loaded")
    let productRepo = JsonProductRepo(dataDir + "/products.json")
    eprintln("[cj-memo] product repo loaded (size=" + productRepo.list().size.toString() + ")")
    let pointRepo = JsonPointRepo(dataDir + "/points.json")
    eprintln("[cj-memo] point repo loaded")
    let lotteryRepo = JsonLotteryRepo(dataDir + "/lottery.json")
    eprintln("[cj-memo] lottery repo loaded")
    let prizeRepo = PrizeRepository()
    eprintln("[cj-memo] prize catalog loaded (size=" + prizeRepo.listPublic().size.toString() + ")")

    let authService = AuthService(userRepo)
    let rewardService = RewardService(userRepo)
    rewardService.attachPointRepo(pointRepo)
    let eventService = EventService(eventRepo, userRepo, rewardService)
    let shopService = ShopService(productRepo, pointRepo, userRepo)
    let lotteryService = LotteryService(prizeRepo, lotteryRepo, userRepo, pointRepo, productRepo)

    let userHandler = UserHandler(authService)
    let userInfoHandler = UserInfoHandler(authService)
    let userPointsHandler = UserPointsHandler(shopService)
    let eventCreateHandler = EventCreateHandler(eventService)
    let eventListHandler = EventListHandler(eventService)
    let eventUpdateHandler = EventUpdateHandler(eventService)
    let eventDeleteHandler = EventDeleteHandler(eventService)
    let eventCompleteHandler = EventCompleteHandler(eventService)
    let eventUpcomingHandler = EventUpcomingHandler(eventService)
    let shopProductListHandler = ShopProductListHandler(shopService)
    let shopBuyHandler = ShopBuyHandler(shopService)
    let shopOrdersHandler = ShopOrdersHandler(shopService)
    let lotteryInfoHandler = LotteryInfoHandler(lotteryService)
    let lotteryDrawHandler = LotteryDrawHandler(lotteryService)
    let lotteryHistoryHandler = LotteryHistoryHandler(lotteryService)

    let router = Router()
    router.staticRoot = "static"
    router.add("POST", "/api/user/register", userHandler)
    router.add("POST", "/api/user/login", userHandler)
    router.addAuth("GET", "/api/user/info", userInfoHandler)
    router.addAuth("GET", "/api/user/points", userPointsHandler)
    router.addAuth("POST", "/api/event", eventCreateHandler)
    router.addAuth("GET", "/api/event/list", eventListHandler)
    router.addAuth("GET", "/api/event/upcoming", eventUpcomingHandler)
    router.addAuth("PUT", "/api/event/*", eventUpdateHandler)
    router.addAuth("DELETE", "/api/event/*", eventDeleteHandler)
    router.addAuth("POST", "/api/event/*", eventCompleteHandler)
    router.addAuth("GET", "/api/shop/products", shopProductListHandler)
    router.addAuth("POST", "/api/shop/buy", shopBuyHandler)
    router.addAuth("GET", "/api/shop/orders", shopOrdersHandler)
    router.addAuth("GET", "/api/lottery/info", lotteryInfoHandler)
    router.addAuth("POST", "/api/lottery/draw", lotteryDrawHandler)
    router.addAuth("GET", "/api/lottery/history", lotteryHistoryHandler)
    router.add("GET", "/api/health", HealthHandler())

    let port: Int32 = 8080
    let server = HttpServer(port, router)
    server.start()
    0
}

public class HealthHandler <: RequestHandler {
    public func handle(req: HttpRequest): HttpResponse {
        let obj = JsonObject()
        obj.put("ok", JsonBool(true))
        obj.put("service", JsonString("cj-memo"))
        obj.put("version", JsonString("0.1.0"))
        HttpResponse.json(200, obj.toString())
    }
}
