package cj_memo

// reward_service.cj
// 积分 / 等级 / 鼓励语发放。

import std.collection.ArrayList

public class RewardService {
    public let userRepo: JsonUserRepo
    public var pointRepo: ?JsonPointRepo

    public init(userRepo: JsonUserRepo) {
        this.userRepo = userRepo
        this.pointRepo = None
    }

    public func attachPointRepo(pr: JsonPointRepo): Unit {
        pointRepo = Some(pr)
    }

    // 完成时调用：如果没过期，加 10 分，重算等级，返回 (获得的积分, 升级文案)。
    public func grantForCompletion(userId: Int64, onTime: Bool): (Int32, String) {
        match (userRepo.findById(userId)) {
            case Some(u) =>
                let oldLevel = u.level
                let now = TimeUtil.nowMs()
                if (!onTime) {
                    u.completedCount = u.completedCount + 1
                    u.updateTime = now
                    userRepo.update(u)
                    return (0, "已过期，不获得积分。")
                }
                let gained = POINTS_PER_TASK
                u.totalPoints = u.totalPoints + gained
                u.completedCount = u.completedCount + 1
                let newLevel = LevelRule.levelForPoints(u.totalPoints)
                u.level = newLevel
                u.updateTime = now
                userRepo.update(u)
                match (pointRepo) {
                    case Some(pr) =>
                        let rid = pr.nextRecordId()
                        let rec = PointRecord(rid, userId, gained, u.totalPoints,
                                              PointReason.EarnComplete, 0,
                                              "完成事件奖励 +" + gained.toString(), now)
                        pr.insertRecord(rec)
                    case None => ()
                }
                var promote = ""
                if (newLevel > oldLevel) {
                    promote = "恭喜升级到 " + LevelRule.levelName(newLevel) + "！"
                }
                (gained, promote)
            case None => (0, "")
        }
    }
}
