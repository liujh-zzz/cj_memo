package cj_memo

// level_test.cj
// 单元测试：等级规则 LevelRule 的边界值与等级名称。

import std.unittest.*
import std.unittest.testmacro.*

@Test
class LevelRuleTest {
    // 等级的分值边界：[0,50)→1, [50,150)→2, [150,300)→3, [300,500)→4, [500,800)→5, [800,∞)→6
    @TestCase
    func levelForPointsBoundaries() {
        @Expect(LevelRule.levelForPoints(0), Int8(1))
        @Expect(LevelRule.levelForPoints(49), Int8(1))
        @Expect(LevelRule.levelForPoints(50), Int8(2))
        @Expect(LevelRule.levelForPoints(149), Int8(2))
        @Expect(LevelRule.levelForPoints(150), Int8(3))
        @Expect(LevelRule.levelForPoints(299), Int8(3))
        @Expect(LevelRule.levelForPoints(300), Int8(4))
        @Expect(LevelRule.levelForPoints(499), Int8(4))
        @Expect(LevelRule.levelForPoints(500), Int8(5))
        @Expect(LevelRule.levelForPoints(799), Int8(5))
        @Expect(LevelRule.levelForPoints(800), Int8(6))
        @Expect(LevelRule.levelForPoints(99999), Int8(6))
    }

    @TestCase
    func nextLevelPointsNormal() {
        @Expect(LevelRule.nextLevelPoints(0), Int32(50))
        @Expect(LevelRule.nextLevelPoints(49), Int32(50))
        @Expect(LevelRule.nextLevelPoints(50), Int32(150))
        @Expect(LevelRule.nextLevelPoints(149), Int32(150))
        @Expect(LevelRule.nextLevelPoints(150), Int32(300))
        @Expect(LevelRule.nextLevelPoints(299), Int32(300))
        @Expect(LevelRule.nextLevelPoints(300), Int32(500))
        @Expect(LevelRule.nextLevelPoints(499), Int32(500))
        @Expect(LevelRule.nextLevelPoints(500), Int32(800))
        @Expect(LevelRule.nextLevelPoints(799), Int32(800))
    }

    @TestCase
    func nextLevelPointsMaxLevel() {
        // 满级返回 -1
        @Expect(LevelRule.nextLevelPoints(800), Int32(-1))
        @Expect(LevelRule.nextLevelPoints(9999), Int32(-1))
    }

    @TestCase
    func levelNameAllLevels() {
        @Expect(LevelRule.levelName(Int8(1)), "初始级")
        @Expect(LevelRule.levelName(Int8(2)), "入门级")
        @Expect(LevelRule.levelName(Int8(3)), "进阶级")
        @Expect(LevelRule.levelName(Int8(4)), "熟练级")
        @Expect(LevelRule.levelName(Int8(5)), "精通级")
        @Expect(LevelRule.levelName(Int8(6)), "满级")
        @Expect(LevelRule.levelName(Int8(99)), "未知")
        @Expect(LevelRule.levelName(Int8(0)), "未知")
    }
}