package cj_memo

// note.cj
// Domain entity: Note (事件) and User (账号).

import std.collection.ArrayList

public class Note {
    public var id: Int64
    public var userId: Int64
    public var title: String
    public var content: String
    public var tags: ArrayList<String>
    public var priority: EventPriority
    public var deadline: Int64       // unix ms
    public var remindMinutes: Int32
    public var status: EventStatus
    public var finishTime: Int64      // 0 if not finished
    public var reminded: Bool         // 一次性提醒标志
    public var createdAt: Int64
    public var updatedAt: Int64

    public init(
        id: Int64, userId: Int64, title: String, content: String,
        tags: ArrayList<String>, priority: EventPriority, deadline: Int64, remindMinutes: Int32,
        status: EventStatus, finishTime: Int64, reminded: Bool,
        createdAt: Int64, updatedAt: Int64
    ) {
        this.id = id
        this.userId = userId
        this.title = title
        this.content = content
        this.tags = tags
        this.priority = priority
        this.deadline = deadline
        this.remindMinutes = remindMinutes
        this.status = status
        this.finishTime = finishTime
        this.reminded = reminded
        this.createdAt = createdAt
        this.updatedAt = updatedAt
    }
}
