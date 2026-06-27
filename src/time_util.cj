package cj_memo

// time_util.cj
// Simple unix-ms time helpers using std.time.DateTime.

import std.time.DateTime

public class TimeUtil {
    // 当前 unix 毫秒
    public static func nowMs(): Int64 {
        let d = DateTime.now()
        d.toUnixTimeStamp().toMilliseconds()
    }
}
