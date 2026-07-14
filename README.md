# 听书 AI

原生 iOS 17+ 小说阅读与听书应用，使用 SwiftUI、SwiftData、CoreText、UIKit 和
AVFoundation 构建，不依赖 Flutter。书架主页保持原有三列格局，阅读器与听书内核
参考并迁移自 MIT 许可的 Yuedu Reader；具体归属见 `THIRD_PARTY_NOTICES.md`。

## 当前能力

- 启动直达“我的书架”，支持分类、搜索、删除与即时刷新
- TXT / EPUB 本地导入、中文章节识别与稳定阅读位置持久化
- CoreText 精确分页与绘制，改字号、行距、页边距或屏幕尺寸后仍回到原文位置
- UIKit 原生 `UIPageViewController.pageCurl` 仿真卷页
- 沉浸阅读、中间点击工具栏、章节跳转、目录、夜间模式与持久化排版设置
- `AVSpeechSynthesizer` 离线连续听书：跨页自动跟随、段落跳转、章节切换、语速、声音和定时停止
- 后台 spoken-audio 会话、锁屏播放/暂停/跳段控制与系统正在播放信息
- 供应商无关的 `AISpeechProvider`，兼容可配置 AI 语音接口
- API Key 仅保存到 iOS Keychain

AI 语音配置界面、在线书源与更完整的 EPUB CSS/图片排版将在后续阶段接入。

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
