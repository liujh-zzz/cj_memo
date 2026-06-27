package cj_memo

// time_util_test.cj
// 单元测试：TimeUtil.nowMs 返回合法 unix 毫秒时间戳。

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TimeUtilTest {
    @TestCase
    func nowMsReasonable() {
        // 2024-01-01T00:00:00Z = 1704067200000 ms
        // 当前时间一定大于这个值
        let now = TimeUtil.nowMs()
        @Assert(now > Int64(1704067200000))
    }

    @TestCase
    func nowMsIncreasing() {
        // 两次调用，第二次一定不小于第一次
        let t1 = TimeUtil.nowMs()
        let t2 = TimeUtil.nowMs()
        @Assert(t2 >= t1)
    }

    @TestCase
    func nowMsSaneUpperBound() {
        // 2100-01-01 ≈ 4102444800000 ms
        // 当前时间一定小于这个值
        let now = TimeUtil.nowMs()
        @Assert(now < Int64(4102444800000))
    }
}