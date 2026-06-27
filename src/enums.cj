package cj_memo

// enums.cj
// Domain enums for events and levels.

public enum EventStatus {
    | Pending     // 0 待完成
    | Completed   // 1 已完成
    | Expired     // 2 已过期

    public func toInt(): Int8 {
        match (this) {
            case Pending => 0
            case Completed => 1
            case Expired => 2
        }
    }

    public static func fromInt(n: Int8): EventStatus {
        match (n) {
            case 0 => Pending
            case 1 => Completed
            case 2 => Expired
            case _ => Pending
        }
    }

    public func toString(): String {
        match (this) {
            case Pending => "pending"
            case Completed => "completed"
            case Expired => "expired"
        }
    }

    public func equals(other: EventStatus): Bool {
        this.toInt() == other.toInt()
    }
}

public enum EventPriority {
    | Low      // 0
    | Medium   // 1
    | High     // 2

    public func toInt(): Int8 {
        match (this) {
            case Low => 0
            case Medium => 1
            case High => 2
        }
    }

    public static func fromInt(n: Int8): EventPriority {
        match (n) {
            case 0 => Low
            case 1 => Medium
            case 2 => High
            case _ => Medium
        }
    }

    public func toString(): String {
        match (this) {
            case Low => "low"
            case Medium => "medium"
            case High => "high"
        }
    }

    public func equals(other: EventPriority): Bool {
        this.toInt() == other.toInt()
    }
}

public enum PointReason {
    | EarnComplete   // 完成事件奖励
    | SpendBuy       // 兑换商品
    | AdminAdjust    // 管理员调整
    | EarnLottery    // 抽奖获得（积分或实物折算）
    | SpendLottery   // 抽奖消耗

    public func toString(): String {
        match (this) {
            case EarnComplete => "earn_complete"
            case SpendBuy => "spend_buy"
            case AdminAdjust => "admin_adjust"
            case EarnLottery => "earn_lottery"
            case SpendLottery => "spend_lottery"
        }
    }

    public func equals(other: PointReason): Bool {
        this.toString() == other.toString()
    }
}
