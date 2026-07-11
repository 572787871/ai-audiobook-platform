# legado-E 阅读架构调研报告（仅作 Flutter 重写参考，不并入仓库）

源码来源：https://github.com/Luoyacheng/legado-E （GPL-3.0）
调研方式：git clone 至 /tmp 只读研究，未复制源码进入本仓库。
许可证：GPL-3.0 —— 本商业项目仅学习架构/算法思想，所有 Dart 代码独立重写，不机械翻译 Kotlin。

## 一、真实文件路径

### 阅读页面 / 分页
- `app/src/main/java/io/legado/app/ui/book/read/page/provider/TextPageFactory.kt` (160行) —— 翻页状态机：hasPrev/hasNext/moveToNext/moveToPrev，维护 pageIndex，curPage/nextPage/prevPage 取章节内页。
- `app/src/main/java/io/legado/app/ui/book/read/page/provider/ChapterProvider.kt` (376行) —— 章节排版器：upStyle/upLayout，计算 visibleWidth/visibleHeight/padding，使用 Android StaticLayout 与 TextPaint。
- `app/src/main/java/io/legado/app/ui/book/read/page/provider/TextChapterLayout.kt` (1333行) —— 核心分页算法：逐行测量、getLineStart/getLineEnd、段落段距、分页截断、图片/HTML 行。
- `app/src/main/java/io/legado/app/ui/book/read/page/entities/TextChapter.kt` —— 章节分页结果：textPages 列表、pageSize、getPageIndexByCharIndex（按字符偏移定位页）。
- `app/src/main/java/io/legado/app/ui/book/read/page/api/PageFactory.kt` —— 分页接口。

### 章节解析
- `app/src/main/java/io/legado/app/model/localBook/TextFile.kt` (159行) —— TXT 自动分章：analyze() 用正则 TxtTocRule 匹配章节标题，按 matcher.start() 切分，记录 chapter.start/end 字符偏移与 wordCount。
- `app/src/main/java/io/legado/app/data/entities/TxtTocRule.kt` —— 分章规则实体（rule/replacement/example）。

### 阅读缓存
- `app/src/main/java/io/legado/app/model/CacheBook.kt` (object) —— 内存 ConcurrentHashMap<String, CacheBookModel> 缓存书；getOrCreate/remove/start（后台 Service 预加载）。
- `app/src/main/java/io/legado/app/model/ReadBook.kt` —— 当前书模型：prevChapterLoadingLock/curChapterLoadingLock/nextChapterLoadingLock 三段锁并发加载；durChapterIndex/durChapterPos 进度。

### 阅读进度
- `app/src/main/java/io/legado/app/data/entities/BookProgress.kt` —— durChapterIndex / durChapterPos / durChapterTime / durChapterTitle。
- `app/src/main/java/io/legado/app/data/entities/ReadRecord.kt` —— readTime（累计阅读时长）/ lastRead（最后阅读时间）。
- `app/src/main/java/io/legado/app/data/dao/ReadRecordDao.kt` / `BookChapterDao.kt` —— 持久化。

### 翻页动画
- `app/src/main/java/io/legado/app/constant/PageAnim.kt` —— cover=0, slide=1, simulation=2, scroll=3, noAnim=4。
- `app/src/main/java/io/legado/app/ui/book/read/page/PageView.kt` —— 自定义绘制翻页（仿真为专属动画层）。

## 二、可在 Flutter 中重写的（算法思想）
1. 逐行字符测量分页 → Flutter `TextPainter` 等价（已实现 text_paginator.dart）。
2. 章节正则分章 + start/end 字符偏移 → Dart 重写 chapter_parser.dart。
3. 按章节分页、三段缓存（prev/cur/next）+ 后台预加载 + 远处释放 → Dart 重写 chapter_cache/page_cache。
4. 进度按 chapterIndex + characterOffset 恢复 → reader_position.dart 扩展。
5. 四种翻页（cover/slide/scroll/noAnim）→ widgets 下重写，仿真暂时关闭。
6. 大文件不全书分页：打开→读章节索引→加载当前章→分页当前章→缓存三章→预加载。
7. 阅读时长 readTime / lastReadAt → Book 扩展字段。

## 三、Android 专属、不能使用
- `android.text.StaticLayout` / `TextPaint` / `StaticLayout.Builder` —— 必须用 Flutter TextPainter 替代。
- `androidx.room.*` (Dao/Entity) —— 本仓库用文件 JSON 仓储，不引入 Room。
- `ContentProvider` / `BookSource` / 网络书源 / 网页抓取 / RSS / 视频 / 登录 —— 不在研究范围。
- `Service` / `Activity` / `Fragment` / `Context` / `appCtx` —— 用 Flutter Widget/Isolate 替代。
- `Typeface.createFromFile` 自定义字体文件加载 —— 暂用系统字体族。
- `dpToPx` 等 Android 尺寸 —— 用 MediaQuery/逻辑像素。
- `EventBus` 跨组件通信 —— 用 Stream/ChangeNotifier。

## 四、对当前架构的映射
- 现有 engine/ 已具备分页器、位置模型、控制器基础；本次新增 chapter_parser（分章）、chapter_cache（三章缓存）、page_cache（页缓存）、directory_page/settings_page/toolbar，并按章节按需分页改写 ReaderController。
- 不改动：BookRepository / LibraryPage / BookShelfPage / ImportService / ReadingSettings 接口 / GitHub Actions / Kokoro 规划。
- 仿真翻页（simulation=2）按用户要求暂关闭，等稳定后再单独实现动画层。
