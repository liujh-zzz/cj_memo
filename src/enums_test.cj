package cj_memo

// enums_test.cj
// 单元测试：枚举与 Int/String 之间的相互转换。
// 注意：自定义枚举未实现 Equatable，所以用布尔比较。

import std.unittest.*
import std.unittest.testmacro.*

@Test
class EventStatusTest {
    @TestCase
    func toIntFromInt() {
        @Expect(EventStatus.Pending.toInt(), Int8(0))
        @Expect(EventStatus.Completed.toInt(), Int8(1))
        @Expect(EventStatus.Expired.toInt(), Int8(2))
    }

    @TestCase
    func fromIntRoundtrip() {
        @Assert(EventStatus.fromInt(Int8(0)).equals(EventStatus.Pending))
        @Assert(EventStatus.fromInt(Int8(1)).equals(EventStatus.Completed))
        @Assert(EventStatus.fromInt(Int8(2)).equals(EventStatus.Expired))
    }

    @TestCase
    func fromIntUnknownDefaultsToPending() {
        // 文档契约：未知值默认返回 Pending
        @Assert(EventStatus.fromInt(Int8(99)).equals(EventStatus.Pending))
        @Assert(EventStatus.fromInt(Int8(-1)).equals(EventStatus.Pending))
    }

    @TestCase
    func toStringRoundtrip() {
        @Expect(EventStatus.Pending.toString(), "pending")
        @Expect(EventStatus.Completed.toString(), "completed")
        @Expect(EventStatus.Expired.toString(), "expired")
    }
}

@Test
class EventPriorityTest {
    @TestCase
    func toIntFromInt() {
        @Expect(EventPriority.Low.toInt(), Int8(0))
        @Expect(EventPriority.Medium.toInt(), Int8(1))
        @Expect(EventPriority.High.toInt(), Int8(2))
    }

    @TestCase
    func fromIntUnknownDefaultsToMedium() {
        @Assert(EventPriority.fromInt(Int8(99)).equals(EventPriority.Medium))
    }
}

@Test
class PointReasonTest {
    @TestCase
    func toStringAll() {
        @Expect(PointReason.EarnComplete.toString(), "earn_complete")
        @Expect(PointReason.SpendBuy.toString(), "spend_buy")
        @Expect(PointReason.AdminAdjust.toString(), "admin_adjust")
        @Expect(PointReason.EarnLottery.toString(), "earn_lottery")
        @Expect(PointReason.SpendLottery.toString(), "spend_lottery")
    }

    @TestCase
    func equalsByString() {
        @Expect(PointReason.EarnComplete.equals(PointReason.EarnComplete), true)
        @Expect(PointReason.EarnComplete.equals(PointReason.SpendBuy), false)
    }
}