package cj_memo

// lottery_test.cj
// 单元测试：PrizeRepository 加权抽奖的分布与基本不变量。
// 期望值 ≈ 30.9，单抽 30 分（轻微正期望 → 体感"赚到"）

import std.unittest.*
import std.unittest.testmacro.*

@Test
class PrizeRepositoryTest {
    @TestCase
    func totalWeightMatchesSum() {
        let repo = PrizeRepository()
        // 配置权重：30+25+18+8+8+5+3+2+1 = 100
        @Expect(repo.totalWeight(), Int64(100))
    }

    @TestCase
    func listPublicHasNinePrizes() {
        let repo = PrizeRepository()
        @Expect(repo.listPublic().size, Int64(9))
    }

    @TestCase
    func drawOneReturnsValidPrize() {
        let repo = PrizeRepository()
        // 抽 1000 次，每一次都必须在奖品池里
        var i: Int32 = 0
        while (i < 1000) {
            let p = repo.drawOne()
            @Assert(p.id >= Int64(1) && p.id <= Int64(9))
            @Assert(p.weight > Int32(0))
            i++
        }
    }

    @TestCase
    func drawOneWeightConformsToExpectedValue() {
        // 用 10000 次蒙特卡洛模拟验证期望值落在合理区间
        // 设计期望 = (5*30 + 10*25 + 20*18 + 50*8) / 100 = (150+250+360+400)/100 = 11.6
        // 注意：实物奖品按 0 计分（保底逻辑只在库存为 0 时折算），这里只看积分期望
        let repo = PrizeRepository()
        var sumPoints: Int64 = 0
        var n: Int64 = 10000
        var i: Int64 = 0
        while (i < n) {
            let p = repo.drawOne()
            if (p.rewardType.equals(LotteryRewardType.Points)) {
                sumPoints = sumPoints + Int64(p.pointsValue)
            }
            i++
        }
        let avg = sumPoints / n  // 期望 ≈ 11.6
        // 允许 ±3 误差
        @Assert(avg >= Int64(8))
        @Assert(avg <= Int64(15))
    }
}