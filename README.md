# AI 有声书平台

AI 有声书平台 —— 文本上传、TTS 合成、音频播放、后台管理。

## 技术栈

- **前端**：Flutter（iOS 优先）
- **后端**：FastAPI + SQLAlchemy + PostgreSQL
- **异步任务**：Celery + Redis
- **本地存储**：Local File System（后续可扩展 S3/OSS）
- **TTS**：Celery Worker 调用 abogen 生成真实音频，失败会写入任务错误原因

## 目录结构

```
ai-audiobook-platform/
├── backend/          # FastAPI 后端
├── worker/           # Celery Worker
├── flutter_app/      # Flutter App
├── admin/            # 管理后台（预留）
├── storage/          # 本地文件存储
├── scripts/          # 脚本
├── .github/workflows/ # GitHub Actions
├── docker-compose.yml
├── .env.example
└── README.md
```

## 快速开始

### 1. 复制环境配置

```bash
cp .env.example .env
```

### 2. 启动后端服务

```bash
docker compose up -d --build
```

> 部署前请在 worker 运行环境安装 abogen，或通过 `.env` 配置
> `ABOGEN_COMMAND_TEMPLATE` 覆盖实际命令参数，例如
> `abogen --input {input} --output {output}`。

服务地址：
- API: http://localhost:8000
- API 文档: http://localhost:8000/docs

### 3. 烟雾测试

```bash
./scripts/smoke_test.sh
```

### 4. Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

## API 概览

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/auth/register | 注册 |
| POST | /api/auth/login | 登录 |
| GET | /api/auth/me | 当前用户 |
| GET | /api/users/me | 个人资料 |
| PATCH | /api/users/me | 更新资料 |
| POST | /api/users/me/premium | 升级会员 |
| POST | /api/books/upload | 上传文本 |
| GET | /api/books | 有声书列表 |
| GET | /api/books/{id} | 有声书详情 |
| PATCH | /api/books/{id} | 更新有声书 |
| DELETE | /api/books/{id} | 删除有声书 |
| GET | /api/books/{id}/download | 下载音频 |
| GET | /api/books/{id}/tasks | 有声书任务列表 |
| POST | /api/tasks | 创建 TTS 任务 |
| GET | /api/tasks | 任务列表 |
| GET | /api/tasks/{id} | 任务详情 |
| POST | /api/tasks/{id}/cancel | 取消任务 |

## GitHub Actions

- `flutter-analyze.yml`：Flutter 代码分析
- `ios-build.yml`：iOS 无签名 IPA 构建

## License

MIT
