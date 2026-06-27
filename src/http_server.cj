package cj_memo

// http_server.cj
// Minimal HTTP/1.1 server built on std.net.TcpServerSocket.
// Designed for the cj-memo app: routes that match exact method+path, plus
// static file serving from a configurable root.

import std.net.{TcpServerSocket, TcpSocket, IPSocketAddress, SocketTimeoutException}
import std.collection.{HashMap, ArrayList}
import std.fs.{File, exists}
import std.convert.Parsable
import std.time.*

public class HttpRequest {
    public let method: String
    public let path: String
    public let query: String
    public let headers: HashMap<String, String>
    public let body: String

    public init(method: String, path: String, query: String,
                headers: HashMap<String, String>, body: String) {
        this.method = method
        this.path = path
        this.query = query
        this.headers = headers
        this.body = body
    }
}

public class HttpResponse {
    public var status: Int32
    public var headers: HashMap<String, String>
    public var body: String

    public init(status: Int32, headers: HashMap<String, String>, body: String) {
        this.status = status
        this.headers = headers
        this.body = body
    }

    public static func json(status: Int32, body: String): HttpResponse {
        let h = HashMap<String, String>()
        h.add("Content-Type", "application/json; charset=utf-8")
        h.add("Access-Control-Allow-Origin", "*")
        h.add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        h.add("Access-Control-Allow-Headers", "Content-Type, Authorization")
        HttpResponse(status, h, body)
    }

    public static func raw(status: Int32, ctype: String, body: String): HttpResponse {
        let h = HashMap<String, String>()
        h.add("Content-Type", ctype)
        h.add("Access-Control-Allow-Origin", "*")
        h.add("Cache-Control", "no-cache, no-store, must-revalidate")
        h.add("Pragma", "no-cache")
        HttpResponse(status, h, body)
    }
}

public interface RequestHandler {
    func handle(req: HttpRequest): HttpResponse {
        return HttpResponse.json(404, errJson(404, ""))
    }
    func handleWithUser(req: HttpRequest, userId: Int64): HttpResponse {
        return handle(req)
    }
}

public class RouteEntry {
    public let method: String
    public let pattern: String          // exact path or "/api/event/*"
    public let handler: RequestHandler
    public let authRequired: Bool

    public init(method: String, pattern: String, handler: RequestHandler, authRequired: Bool) {
        this.method = method
        this.pattern = pattern
        this.handler = handler
        this.authRequired = authRequired
    }
}

public class Router {
    public let routes: ArrayList<RouteEntry>
    public var staticRoot: String

    public init() {
        this.routes = ArrayList<RouteEntry>()
        this.staticRoot = "static"
    }

    public func add(method: String, pattern: String, handler: RequestHandler): Unit {
        routes.add(RouteEntry(method, pattern, handler, false))
    }

    public func addAuth(method: String, pattern: String, handler: RequestHandler): Unit {
        routes.add(RouteEntry(method, pattern, handler, true))
    }

    public func dispatch(req: HttpRequest): HttpResponse {
        for (entry in routes) {
            if (entry.method == req.method && matchPath(entry.pattern, req.path)) {
                if (entry.authRequired) {
                    let auth = req.headers.get("Authorization")
                    var token = ""
                    match (auth) {
                        case Some(v) => token = v
                        case None => ()
                    }
                    if (token.size >= 7) {
                        // strip "Bearer " prefix if present
                        if (token[0..7] == "Bearer ") {
                            token = token[7..]
                        }
                    }
                    match (TokenStore.resolve(token)) {
                        case Some(uid) => return entry.handler.handleWithUser(req, uid)
                        case None => return HttpResponse.json(401, errJson(401, "未登录或 token 无效"))
                    }
                }
                return entry.handler.handle(req)
            }
        }
        // Static files: serve from staticRoot, exact path, only GET.
        if (req.method == "GET") {
            return serveStatic(req.path)
        }
        HttpResponse.json(404, errJson(404, "Not Found"))
    }

    private func serveStatic(p: String): HttpResponse {
        var rel = p
        if (rel == "/" || rel.size == 0) { rel = "/index.html" }
        // Strip leading '/'
        var path = rel
        if (path.size > 0 && path[0] == UInt8(47)) {
            path = path[1..]
        }
        if (path.size == 0) { path = "index.html" }
        // Prevent path traversal
        if (findIdx(path, "..") >= 0) {
            return HttpResponse.json(403, errJson(403, "forbidden"))
        }
        let fullPath = staticRoot + "\\" + path
        // forward slash variant for cross-platform
        let fullPath2 = staticRoot + "/" + path
        var chosen = fullPath
        if (!exists(fullPath)) {
            if (exists(fullPath2)) {
                chosen = fullPath2
            } else {
                return HttpResponse.json(404, errJson(404, "not found"))
            }
        }
        let body = readFile(chosen)
        if (body.size == 0) {
            return HttpResponse.raw(200, "application/octet-stream", "")
        }
        let ctype = guessContentType(path)
        HttpResponse.raw(200, ctype, body)
    }
}

// 一些 handler 是已认证的（Authed），直接实现两个方法。

public func matchPath(pattern: String, path: String): Bool {
    if (pattern == path) { return true }
    if (pattern.size >= 2) {
        let suffix = pattern[pattern.size - 2..pattern.size]
        if (suffix == "/*") {
            let prefix = pattern[0..(pattern.size - 2)]
            if (path.size >= prefix.size && path[0..prefix.size] == prefix) {
                return true
            }
        }
    }
    false
}

public func guessContentType(path: String): String {
    if (endsWith(path, ".html")) { return "text/html; charset=utf-8" }
    if (endsWith(path, ".css"))  { return "text/css; charset=utf-8" }
    if (endsWith(path, ".js"))   { return "application/javascript; charset=utf-8" }
    if (endsWith(path, ".json")) { return "application/json; charset=utf-8" }
    if (endsWith(path, ".svg"))  { return "image/svg+xml" }
    if (endsWith(path, ".png"))  { return "image/png" }
    if (endsWith(path, ".jpg") || endsWith(path, ".jpeg")) { return "image/jpeg" }
    if (endsWith(path, ".ico"))  { return "image/x-icon" }
    "application/octet-stream"
}

public func endsWith(s: String, suf: String): Bool {
    if (s.size < suf.size) { return false }
    s[s.size - suf.size..s.size] == suf
}

public func trim(s: String): String {
    var start: Int64 = 0
    var end: Int64 = s.size
    while (start < end && isWs(s[start])) { start++ }
    while (end > start && isWs(s[end - 1])) { end-- }
    if (end <= start) { return "" }
    s[start..end]
}

public func isWs(b: UInt8): Bool {
    b == UInt8(32) || b == UInt8(9) || b == UInt8(10) || b == UInt8(13)
}

public func parseRequest(raw: String): Option<HttpRequest> {
    let headerEnd = findIdx(raw, "\r\n\r\n")
    if (headerEnd < 0) { return None }
    let headerPart = raw[0..headerEnd]
    let bodyPart = if (headerEnd + 4 < raw.size) { raw[(headerEnd + 4)..] } else { "" }
    let lines = headerPart.split("\r\n")
    if (lines.size == 0) { return None }
    let requestLine = lines[0]
    let parts = requestLine.split(" ")
    if (parts.size < 3) { return None }
    let method = parts[0]
    let fullPath = parts[1]
    var path = fullPath
    var query = ""
    let qIdx = findIdx(fullPath, "?")
    if (qIdx >= 0) {
        path = fullPath[0..qIdx]
        query = urlDecode(fullPath[(qIdx + 1)..])
    }
    let headers = HashMap<String, String>()
    var i: Int64 = 1
    while (i < lines.size) {
        let line = lines[i]
        let colon = findIdx(line, ":")
        if (colon > 0) {
            let k = trim(line[0..colon])
            let v = trim(line[(colon + 1)..])
            headers.add(k, v)
        }
        i++
    }
    Some(HttpRequest(method, path, query, headers, bodyPart))
}

public func buildResponse(resp: HttpResponse): String {
    let statusText = match (resp.status) {
        case 200 => "OK"
        case 201 => "Created"
        case 204 => "No Content"
        case 400 => "Bad Request"
        case 401 => "Unauthorized"
        case 403 => "Forbidden"
        case 404 => "Not Found"
        case 409 => "Conflict"
        case 500 => "Internal Server Error"
        case _ => "Unknown"
    }
    let sb = StringBuilder()
    sb.append("HTTP/1.1 " + resp.status.toString() + " " + statusText + "\r\n")
    for ((k, v) in resp.headers) {
        sb.append(k + ": " + v + "\r\n")
    }
    sb.append("Content-Length: " + resp.body.size.toString() + "\r\n")
    sb.append("Connection: close\r\n")
    sb.append("\r\n")
    sb.append(resp.body)
    sb.toString()
}

public class HttpServer {
    public let port: Int32
    public let router: Router
    public var running: Bool

    public init(port: Int32, router: Router) {
        this.port = port
        this.router = router
        this.running = false
    }

    public func start(): Unit {
        let portU16 = UInt16(Int64(port))
        let addr = IPSocketAddress("0.0.0.0", portU16)
        try {
            let server = TcpServerSocket(bindAt: addr)
            server.bind()
            running = true
            println("[cj-memo] listening on 0.0.0.0:" + port.toString())
            while (running) {
                try {
                    let client = server.accept()
                    handleClient(client)
                    client.close()
                } catch (e: Exception) {
                    if (running) {
                        println("[cj-memo] accept error: " + e.message)
                    }
                }
            }
        } catch (e: Exception) {
            println("[cj-memo] bind/start failed: " + e.message)
        }
    }

    public func stop(): Unit {
        running = false
    }

    private func handleClient(client: TcpSocket): Unit {
        try {
            client.readTimeout = Duration.second
            let buf = Array<UInt8>(2048, { _ => UInt8(0) })
            let rawList = ArrayList<UInt8>()
            var contentLength: Int64 = 0
            var headersParsed = false
                var iterations: Int64 = 0
            while (iterations < 20) {
                let n: Int64 = try {
                    client.read(buf)
                } catch (e: SocketTimeoutException) {
                    0
                } catch (e: Exception) {
                    0
                }
                iterations++
                if (n <= 0) {
                    if (headersParsed) {
                        let rawSoFar = String.fromUtf8(rawList.toArray())
                        let hEnd = findIdx(rawSoFar, "\r\n\r\n")
                        if (hEnd >= 0) {
                            let receivedBody = rawSoFar.size - (hEnd + 4)
                            if (receivedBody >= contentLength) { break }
                        }
                    }
                    if (rawList.size == 0) { break }
                    continue
                }
                var j: Int64 = 0
                while (j < n) {
                    rawList.add(buf[j])
                    j++
                }
                if (!headersParsed) {
                    let rawSoFar = String.fromUtf8(rawList.toArray())
                    let hEnd = findIdx(rawSoFar, "\r\n\r\n")
                    if (hEnd >= 0) {
                        let clIdx = findIdx(rawSoFar, "Content-Length:")
                        if (clIdx >= 0) {
                            var p = clIdx + 15
                            while (p < rawSoFar.size && isWs(rawSoFar[p])) { p++ }
                            let sb = StringBuilder()
                            while (p < rawSoFar.size && rawSoFar[p] >= UInt8(48) && rawSoFar[p] <= UInt8(57)) {
                                sb.append(Rune(UInt32(rawSoFar[p])))
                                p++
                            }
                            let numStr = sb.toString()
                            if (numStr.size > 0) {
                                contentLength = Int64.parse(numStr)
                            }
                        }
                        headersParsed = true
                    }
                }
                if (headersParsed) {
                    let rawSoFar = String.fromUtf8(rawList.toArray())
                    let hEnd = findIdx(rawSoFar, "\r\n\r\n")
                    if (hEnd >= 0) {
                        let receivedBody = rawSoFar.size - (hEnd + 4)
                        if (receivedBody >= contentLength) { break }
                    }
                }
            }
            let rawStr = String.fromUtf8(rawList.toArray())
            let reqOpt = parseRequest(rawStr)
            var resp = HttpResponse.json(500, errJsonJv(500, "bad request"))
            match (reqOpt) {
                case Some(req) =>
                    if (req.method == "OPTIONS") {
                        resp = HttpResponse.json(204, "")
                    } else {
                        resp = router.dispatch(req)
                    }
                case None => ()
            }
            let out = buildResponse(resp)
            let outRaw = out.toArray()
            let outBuf = Array<UInt8>(outRaw.size, { _ => UInt8(0) })
            var k: Int64 = 0
            while (k < outRaw.size) { outBuf[k] = outRaw[k]; k++ }
            client.write(outBuf)
        } catch (e: Exception) {
            eprintln("[cj-memo] handle client error: " + e.message)
        }
    }
}
