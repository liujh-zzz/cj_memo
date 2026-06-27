package cj_memo

// json_codec.cj
// 基于 stdx.encoding.json 的封装。

import stdx.encoding.json.*
import std.collection.ArrayList

// ---------- 类型判断辅助 ----------

public func isObject(jv: JsonValue): Bool {
    match (jv.kind()) {
        case JsObject => true
        case _ => false
    }
}

public func isArray(jv: JsonValue): Bool {
    match (jv.kind()) {
        case JsArray => true
        case _ => false
    }
}

public func isString(jv: JsonValue): Bool {
    match (jv.kind()) {
        case JsString => true
        case _ => false
    }
}

public func isBool(jv: JsonValue): Bool {
    match (jv.kind()) {
        case JsBool => true
        case _ => false
    }
}

public func isNull(jv: JsonValue): Bool {
    match (jv.kind()) {
        case JsNull => true
        case _ => false
    }
}

// ---------- 字段提取 ----------

public func getString(obj: JsonObject, key: String): String {
    match (obj.get(key)) {
        case Some(v) => v.asString().getValue()
        case None => ""
    }
}

public func getInt(obj: JsonObject, key: String): Int64 {
    match (obj.get(key)) {
        case Some(v) =>
            match (v.kind()) {
                case JsInt => v.asInt().getValue()
                case JsFloat => Int64(v.asFloat().getValue())
                case _ => 0
            }
        case None => 0
    }
}

public func getInt32(obj: JsonObject, key: String): Int32 {
    Int32(getInt(obj, key))
}

public func getBool(obj: JsonObject, key: String): Bool {
    match (obj.get(key)) {
        case Some(v) =>
            if (isBool(v)) { v.asBool().getValue() }
            else { false }
        case None => false
    }
}

// ---------- 数组解析 ----------

// 从 body 中读 "tags" 字段（JSON 数组），转成 ArrayList<String>。
public func parseTags(body: String, key: String): ArrayList<String> {
    let out = ArrayList<String>()
    try {
        let jv = JsonValue.fromStr(body)
        if (!isObject(jv)) { return out }
        let obj = jv.asObject()
        match (obj.get(key)) {
            case Some(v) =>
                if (isArray(v)) {
                    let arr = v.asArray()
                    var i: Int64 = 0
                    while (i < arr.size()) {
                        let item = arr[i]
                        if (isString(item)) { out.add(item.asString().getValue()) }
                        i++
                    }
                }
            case None => ()
        }
    } catch (_: Exception) { }
    out
}

// ---------- 响应包装 ----------

public func okJsonJv(data: JsonValue): String {
    let obj = JsonObject()
    obj.put("ok", JsonBool(true))
    obj.put("data", data)
    obj.toString()
}

public func errJsonJv(code: Int32, msg: String): String {
    let obj = JsonObject()
    obj.put("ok", JsonBool(false))
    obj.put("code", JsonInt(Int64(code)))
    obj.put("message", JsonString(msg))
    obj.toString()
}

public func errJson(code: Int32, msg: String): String { errJsonJv(code, msg) }

// debug: 把字符串每个字节转 hex
public func bytesHex(s: String): String {
    let arr = s.toArray()
    let sb = StringBuilder()
    var i: Int64 = 0
    while (i < arr.size) {
        let b = arr[i]
        let hi = Int64(b) >> 4
        let lo = Int64(b) & 0xF
        let h1 = if (hi < 10) { UInt8(48 + UInt8(hi)) } else { UInt8(97 + UInt8(hi) - 10) }
        let h2 = if (lo < 10) { UInt8(48 + UInt8(lo)) } else { UInt8(97 + UInt8(lo) - 10) }
        sb.append(Rune(UInt32(h1)))
        sb.append(Rune(UInt32(h2)))
        sb.append(Rune(UInt32(32)))
        i++
    }
    sb.toString()
}

// ---------- 通用工具 ----------

public func findIdx(hay: String, needle: String): Int64 {
    if (needle.size == 0) { return 0 }
    if (hay.size < needle.size) { return -1 }
    var i: Int64 = 0
    let lastStart = hay.size - needle.size
    while (i <= lastStart) {
        var matched = true
        var j: Int64 = 0
        while (j < needle.size) {
            if (hay[i + j] != needle[j]) { matched = false; break }
            j++
        }
        if (matched) { return i }
        i++
    }
    -1
}

public func indexOf(s: String, c: UInt8): Int64 {
    var i: Int64 = 0
    while (i < s.size) {
        if (s[i] == c) { return i }
        i++
    }
    -1
}

public func findByte(s: String, c: UInt8): Int64 {
    indexOf(s, c)
}

public func splitQuery(q: String): ArrayList<String> {
    let out = ArrayList<String>()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < q.size) {
        if (q[i] == UInt8(38)) { // '&'
            out.add(q[start..i])
            start = i + 1
        }
        i++
    }
    out.add(q[start..q.size])
    out
}

public func parseIntOr(s: String, fallback: Int64): Int64 {
    if (s.size == 0) { return fallback }
    var sign: Int64 = 1
    var i: Int64 = 0
    if (s[0] == UInt8(45)) { sign = -1; i = 1 }
    var n: Int64 = 0
    var any = false
    while (i < s.size) {
        let b = s[i]
        if (b < UInt8(48) || b > UInt8(57)) { break }
        n = n * 10 + Int64(b - UInt8(48))
        any = true
        i++
    }
    if (!any) { return fallback }
    sign * n
}

func hexVal(b: UInt8): Int64 {
    if (b >= UInt8(48) && b <= UInt8(57)) { Int64(b - UInt8(48)) }
    else if (b >= UInt8(65) && b <= UInt8(70)) { Int64(b - UInt8(65)) + 10 }
    else if (b >= UInt8(97) && b <= UInt8(102)) { Int64(b - UInt8(97)) + 10 }
    else { -1 }
}

// 把 application/x-www-form-urlencoded 风格的串解码回原始字节。
public func urlDecode(s: String): String {
    let bytes = ArrayList<UInt8>()
    var i: Int64 = 0
    while (i < s.size) {
        let b = s[i]
        if (b == UInt8(43)) {                    // '+' → ' '
            bytes.add(UInt8(32))
            i++
        } else if (b == UInt8(37) && i + 2 < s.size) { // '%xx'
            let hi = hexVal(s[i + 1])
            let lo = hexVal(s[i + 2])
            if (hi >= 0 && lo >= 0) {
                bytes.add(UInt8(hi * 16 + lo))
                i = i + 3
            } else {
                bytes.add(b)
                i++
            }
        } else {
            bytes.add(b)
            i++
        }
    }
    String.fromUtf8(bytes.toArray())
}