package cj_memo

// auth_service.cj
// 注册 / 登录 / token 校验。

import stdx.encoding.json.*

public class AuthService {
    public let userRepo: JsonUserRepo

    public init(userRepo: JsonUserRepo) {
        this.userRepo = userRepo
    }

    public func register(username: String, password: String): SvcResult {
        if (username.size < 3 || username.size > 32) {
            return err(400, "用户名长度应为 3-32 字符")
        }
        if (password.size < 6) {
            return err(400, "密码至少 6 位")
        }
        match (userRepo.findByUsername(username)) {
            case Some(_) => return err(409, "用户名已存在")
            case None => ()
        }
        let now = TimeUtil.nowMs()
        let hash = Hasher.sha256("cj-memo:" + password)
        let id = userRepo.nextId()
        let u = User(id, username, hash, 0, 1, 0, 0, now, now)
        userRepo.insert(u)
        let token = TokenStore.issue(id)
        ok(buildAuthPayload(id, username, token, 0, 1))
    }

    public func login(username: String, password: String): SvcResult {
        let hash = Hasher.sha256("cj-memo:" + password)
        match (userRepo.findByUsername(username)) {
            case Some(u) =>
                if (u.passwordHash != hash) {
                    return err(401, "密码错误")
                }
                let token = TokenStore.issue(u.id)
                ok(buildAuthPayload(u.id, u.username, token, u.totalPoints, u.level))
            case None => err(404, "用户不存在")
        }
    }

    public func userInfo(userId: Int64): SvcResult {
        match (userRepo.findById(userId)) {
            case Some(u) =>
                let next = LevelRule.nextLevelPoints(u.totalPoints)
                let obj = JsonObject()
                obj.put("userId", JsonInt(u.id))
                obj.put("username", JsonString(u.username))
                obj.put("totalPoints", JsonInt(Int64(u.totalPoints)))
                obj.put("level", JsonInt(Int64(u.level)))
                obj.put("levelName", JsonString(LevelRule.levelName(u.level)))
                obj.put("nextLevelPoints", JsonInt(Int64(next)))
                obj.put("completedCount", JsonInt(Int64(u.completedCount)))
                ok(okJsonJv(obj))
            case None => err(404, "用户不存在")
        }
    }
}

func buildAuthPayload(id: Int64, username: String, token: String, points: Int32, level: Int8): String {
    let obj = JsonObject()
    obj.put("userId", JsonInt(id))
    obj.put("username", JsonString(username))
    obj.put("token", JsonString(token))
    obj.put("totalPoints", JsonInt(Int64(points)))
    obj.put("level", JsonInt(Int64(level)))
    okJsonJv(obj)
}