package cj_memo

// file_util.cj
// File IO helpers using std.fs.File static helpers.

import std.fs.{File, exists}
import std.collection.ArrayList

public func readFile(path: String): String {
    try {
        if (!exists(path)) { return "" }
        let bytes = File.readFrom(path)
        return String.fromUtf8(bytes)
    } catch (e: Exception) {
        ""
    }
}

public func writeFile(path: String, content: String): Unit {
    try {
        let raw = content.toArray()
        let buf = Array<UInt8>(raw.size, repeat: UInt8(0))
        var i: Int64 = 0
        while (i < raw.size) { buf[i] = raw[i]; i++ }
        File.writeTo(path, buf)
    } catch (e: Exception) {
        println("[file_util] write failed: " + e.message)
    }
}
