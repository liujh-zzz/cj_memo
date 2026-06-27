package cj_memo

// user.cj
// Domain entity: User (账号).

public class User {
    public var id: Int64
    public var username: String
    public var passwordHash: String
    public var totalPoints: Int32
    public var level: Int8
    public var completedCount: Int32
    public var lastFreeDate: Int64       // unix ms 当日 0 点；0 表示从未使用过
    public var createTime: Int64
    public var updateTime: Int64

    public init(
        id: Int64, username: String, passwordHash: String,
        totalPoints: Int32, level: Int8, completedCount: Int32,
        lastFreeDate: Int64,
        createTime: Int64, updateTime: Int64
    ) {
        this.id = id
        this.username = username
        this.passwordHash = passwordHash
        this.totalPoints = totalPoints
        this.level = level
        this.completedCount = completedCount
        this.lastFreeDate = lastFreeDate
        this.createTime = createTime
        this.updateTime = updateTime
    }
}
