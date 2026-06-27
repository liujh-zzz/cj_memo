package cj_memo

// user_repo.cj
// User repository interface + JSON file implementation.
// 用 stdx.encoding.json 做序列化/反序列化。

import stdx.encoding.json.*
import std.collection.ArrayList
import std.sync.Mutex

public interface UserRepo {
    func findById(id: Int64): Option<User>
    func findByUsername(name: String): Option<User>
    func list(): ArrayList<User>
    func insert(user: User): Unit
    func update(user: User): Unit
}

public class JsonUserRepo <: UserRepo {
    private var users: ArrayList<User>
    private let path: String
    private let lock: Mutex

    public init(path: String) {
        this.users = ArrayList<User>()
        this.path = path
        this.lock = Mutex()
        load()
    }

    private func load(): Unit {
        let body = readFile(path)
        if (body.size == 0) { return }
        try {
            let jv = JsonValue.fromStr(body)
            if (!isObject(jv)) { return }
            let obj = jv.asObject()
            match (obj.get("users")) {
                case Some(v) =>
                    if (!isArray(v)) { return }
                    let arr = v.asArray()
                    var i: Int64 = 0
                    while (i < arr.size()) {
                        let item = arr[i]
                        if (isObject(item)) {
                            users.add(parseUser(item.asObject()))
                        }
                        i++
                    }
                case None => ()
            }
        } catch (_: Exception) {
            // 解析失败忽略
        }
    }

    public func save(): Unit {
        let arr = JsonArray()
        for (u in users) {
            arr.add(userToJson(u))
        }
        let root = JsonObject()
        root.put("users", arr)
        writeFile(path, root.toString())
    }

    public func findById(id: Int64): Option<User> {
        lock.lock()
        try {
            for (u in users) {
                if (u.id == id) { return Some(u) }
            }
            None
        } finally { lock.unlock() }
    }

    public func findByUsername(name: String): Option<User> {
        lock.lock()
        try {
            for (u in users) {
                if (u.username == name) { return Some(u) }
            }
            None
        } finally { lock.unlock() }
    }

    public func list(): ArrayList<User> {
        lock.lock()
        try {
            let copy = ArrayList<User>()
            for (u in users) { copy.add(u) }
            copy
        } finally { lock.unlock() }
    }

    public func insert(user: User): Unit {
        lock.lock()
        try {
            users.add(user)
            save()
        } finally { lock.unlock() }
    }

    public func update(user: User): Unit {
        lock.lock()
        try {
            var i: Int64 = 0
            while (i < users.size) {
                if (users[i].id == user.id) {
                    users[i] = user
                    save()
                    return
                }
                i++
            }
        } finally { lock.unlock() }
    }

    public func nextId(): Int64 {
        lock.lock()
        try {
            var max: Int64 = 0
            for (u in users) {
                if (u.id > max) { max = u.id }
            }
            max + 1
        } finally { lock.unlock() }
    }
}

func parseUser(obj: JsonObject): User {
    User(
        getInt(obj, "id"),
        getString(obj, "username"),
        getString(obj, "passwordHash"),
        getInt32(obj, "totalPoints"),
        Int8(getInt(obj, "level")),
        getInt32(obj, "completedCount"),
        getInt(obj, "lastFreeDate"),
        getInt(obj, "createTime"),
        getInt(obj, "updateTime")
    )
}

func userToJson(u: User): JsonValue {
    let obj = JsonObject()
    obj.put("id", JsonInt(u.id))
    obj.put("username", JsonString(u.username))
    obj.put("passwordHash", JsonString(u.passwordHash))
    obj.put("totalPoints", JsonInt(Int64(u.totalPoints)))
    obj.put("level", JsonInt(Int64(u.level)))
    obj.put("completedCount", JsonInt(Int64(u.completedCount)))
    obj.put("lastFreeDate", JsonInt(u.lastFreeDate))
    obj.put("createTime", JsonInt(u.createTime))
    obj.put("updateTime", JsonInt(u.updateTime))
    obj
}