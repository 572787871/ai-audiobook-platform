#!/usr/bin/env python3
"""在 CI runner 本地禁用 Xcode 签名(不提交、不修改业务代码)。

仅移除 project.pbxproj 中带 [sdk=iphoneos*] 条件的最高优先级签名身份行，
并把 CODE_SIGN_STYLE 改为 Manual，配合 xcodebuild 的 CODE_SIGNING_ALLOWED=NO 等参数
实现无 Apple 证书的未签名归档。仓库的 pbxproj 保持原样。
"""
import re
import sys

P = "ios/Runner.xcodeproj/project.pbxproj"


def main() -> int:
    s = open(P, encoding="utf-8").read()
    before = s.count("CODE_SIGN_IDENTITY[sdk=iphoneos*]")
    # 移除所有带 [sdk=iphoneos*] 条件的签名身份行(缩进任意)
    s = re.sub(
        r'\s*"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer";\n',
        "",
        s,
    )
    after = s.count("CODE_SIGN_IDENTITY[sdk=iphoneos*]")
    # Automatic -> Manual
    s = s.replace("CODE_SIGN_STYLE = Automatic;", "CODE_SIGN_STYLE = Manual;")
    open(P, "w", encoding="utf-8").write(s)
    print(f"removed conditional identity lines: {before - after} (before={before}, after={after})")
    return 0 if before - after == before else 1


if __name__ == "__main__":
    sys.exit(main())
