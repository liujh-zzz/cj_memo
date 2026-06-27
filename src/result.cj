package cj_memo

// result.cj
// 服务层统一结果：成功携带 JSON 字符串；失败携带状态码和消息。
// JSON 字符串由 service 层用 stdx.encoding.json 直接生成。

public enum SvcResult {
    | Ok(String)
    | Err(Int32, String)
}

public func ok(body: String): SvcResult { SvcResult.Ok(body) }
public func err(code: Int32, msg: String): SvcResult { SvcResult.Err(code, msg) }