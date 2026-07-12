# 听书 AI

面向 iPhone / iPad 的本地小说阅读与听书应用。采用 Flutter 构建界面，iOS
端通过 `AVSpeechSynthesizer` 提供无需联网的系统语音朗读。

## 已实现

- TXT 文件导入、编码识别、重复检测与本地书架
- 阅读进度即时保存、章节目录与跨章跳转
- 沉浸阅读、夜间/护眼模式、字号/间距/背景设置
- 滑动、覆盖、滚动、无动画与仿真卷页
- iOS 系统听书：播放、暂停、前后翻页、自动连续朗读
- GitHub Actions 构建无签名 IPA

## 构建

```sh
flutter pub get
flutter analyze
flutter test
flutter build ios --release --no-codesign
```

推送 `main` 或 `agent/**` 分支会触发 `Build iOS IPA (Unsigned)` 工作流，
构建产物名为 `ai-audiobook-unsigned-ipa`。无签名 IPA 需要自行签名后安装。
