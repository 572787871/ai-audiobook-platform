# 听书 AI

原生 iOS 17+ 小说阅读与听书应用，使用 SwiftUI、SwiftData、UIKit 和
AVFoundation 构建，不依赖 Flutter。

## 当前能力

- 启动直达“我的书架”，支持分类、搜索、删除与即时刷新
- TXT 本地导入、中文章节识别、阅读进度持久化
- UIKit 原生 `UIPageViewController.pageCurl` 仿真卷页
- 沉浸阅读、中间点击工具栏、目录、夜间模式与阅读设置
- `AVSpeechSynthesizer` 离线听书浮窗
- 供应商无关的 `AISpeechProvider`，兼容可配置 AI 语音接口
- API Key 仅保存到 iOS Keychain

EPUB 完整解析与 AI 配置界面将在下一阶段接入。

## 构建

```sh
brew install xcodegen
xcodegen generate
xcodebuild build \
  -project Audiobook.xcodeproj \
  -scheme Audiobook \
  -sdk iphoneos \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO
```

GitHub Actions 会运行原生 XCTest、构建无签名 iOS App 并上传 IPA Artifact。
