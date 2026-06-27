package cj_memo

// level.cj
// Level rules and encouragement phrases.

import std.collection.ArrayList
import std.random.Random

public class LevelRule {
    public static func levelForPoints(points: Int32): Int8 {
        if (points >= 800) { return 6 }
        if (points >= 500) { return 5 }
        if (points >= 300) { return 4 }
        if (points >= 150) { return 3 }
        if (points >= 50) { return 2 }
        1
    }

    // 下一级所需积分（满级返回 -1）
    public static func nextLevelPoints(points: Int32): Int32 {
        if (points < 50) { return 50 }
        if (points < 150) { return 150 }
        if (points < 300) { return 300 }
        if (points < 500) { return 500 }
        if (points < 800) { return 800 }
        -1
    }

    public static func levelName(lv: Int8): String {
        match (lv) {
            case 1 => "初始级"
            case 2 => "入门级"
            case 3 => "进阶级"
            case 4 => "熟练级"
            case 5 => "精通级"
            case 6 => "满级"
            case _ => "未知"
        }
    }
}

// 完成一次任务的基础积分
public const POINTS_PER_TASK: Int32 = 10

// 20 句鼓励语
public class Encouragement {
    public static let phrases: Array<String> = [
        "太棒了！又攻克一件事，你的执行力真的超赞~",
        "按时完成任务，积分到手，继续保持这个节奏！",
        "每完成一件小事，都是在向更好的自己靠近。",
        "说到做到的感觉是不是超棒？继续加油呀！",
        "今日份任务打卡成功，你又比昨天更厉害一点。",
        "高效完成任务的你，简直闪闪发光！",
        "积少成多，每一分积分都是你的努力勋章。",
        "完美收尾！下一个目标继续冲冲冲。",
        "行动力满分，没有什么能难倒认真的你。",
        "又完成一项，待办清单清空的感觉太爽啦。",
        "你的坚持和自律，时间都看得见。",
        "任务顺利收官，给自己点一个大大的赞。",
        "一步一个脚印，你正在稳稳地进步。",
        "按时交付的感觉超棒，继续保持这份靠谱。",
        "又拿下一件事，你的效率真的没得说！",
        "每一次完成，都是成长的小里程碑。",
        "认真对待每一件小事的你，真的很了不起。",
        "任务达成！奖励自己片刻放松吧。",
        "持续输出行动力，等级升级指日可待。",
        "干得漂亮！带着这份劲头继续前行吧。"
    ]

    public static func pickRandom(): String {
        let r = Random()
        var idx = r.nextInt64() % Int64(phrases.size)
        if (idx < 0) { idx = -idx }
        phrases[idx]
    }
}
