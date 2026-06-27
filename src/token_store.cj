package cj_memo

// token_store.cj
// Token -> userId map. Persisted to data/tokens.json so restart doesn't kill sessions.
// Stored as JSON array of {token, userId} entries for reliable round-trip.

import stdx.encoding.json.*
import std.collection.HashMap
import std.random.Random

public class TokenStore {
    private static var map: HashMap<String, Int64> = HashMap<String, Int64>()
    private static var rng: Random = Random()
    private static var persistPath: String = ""

    public static func setPersistPath(path: String): Unit {
        persistPath = path
        load()
    }

    private static func load(): Unit {
        if (persistPath.size == 0) { return }
        let body = readFile(persistPath)
        if (body.size == 0) { return }
        try {
            let jv = JsonValue.fromStr(body)
            if (!isObject(jv)) { return }
            let obj = jv.asObject()
            match (obj.get("tokens")) {
                case Some(v) =>
                    if (!isArray(v)) { return }
                    let arr = v.asArray()
                    var i: Int64 = 0
                    while (i < arr.size()) {
                        let item = arr[i]
                        if (isObject(item)) {
                            let o = item.asObject()
                            let tok = getString(o, "token")
                            let uid = getInt(o, "userId")
                            if (tok.size > 10) { map.add(tok, uid) }
                        }
                        i++
                    }
                case None => ()
            }
        } catch (_: Exception) { }
    }

    private static func save(): Unit {
        if (persistPath.size == 0) { return }
        let arr = JsonArray()
        for ((k, v) in map) {
            let o = JsonObject()
            o.put("token", JsonString(k))
            o.put("userId", JsonInt(v))
            arr.add(o)
        }
        let root = JsonObject()
        root.put("tokens", arr)
        writeFile(persistPath, root.toString())
    }

    public static func issue(userId: Int64): String {
        let sb = StringBuilder()
        var i: Int64 = 0
        while (i < 32) {
            var n = rng.nextInt64() & 0xF
            if (n < 0) { n = -n }
            if (n < 10) {
                sb.append((UInt8(48 + n)).toString())
            } else {
                sb.append((UInt8(97 + n - 10)).toString())
            }
            i++
        }
        let tok = sb.toString()
        map.add(tok, userId)
        save()
        tok
    }

    public static func resolve(token: String): Option<Int64> {
        map.get(token)
    }

    public static func revoke(token: String): Unit {
        map.remove(token)
        save()
    }
}
