package cj_memo

// hasher.cj
// SHA-256 密码摘要，使用 stdx.crypto.digest + stdx.encoding.hex。

import stdx.crypto.digest.SHA256
import stdx.encoding.hex.toHexString

public class Hasher {
    public static func sha256(s: String): String {
        let raw = s.toArray()
        let sha = SHA256()
        sha.write(raw)
        let out = sha.finish()
        toHexString(out)
    }
}