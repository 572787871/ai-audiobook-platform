"""FastAPI 应用入口。"""
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from backend.app.core.config import settings
from backend.app.core.database import Base, engine
from backend.app.routers import auth, users, books, tasks
from backend.app.services.storage import ensure_storage_dirs


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 启动：创建表 + 存储目录
    Base.metadata.create_all(bind=engine)
    ensure_storage_dirs()
    yield


app = FastAPI(
    title="AI 有声书平台 API",
    description="AI 有声书平台后端 —— 文本上传、TTS 合成、音频下载",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 静态文件：storage 目录（兼容旧路径 + 新 /media 路径）
storage_root = Path(settings.LOCAL_STORAGE_ROOT)
storage_root.mkdir(parents=True, exist_ok=True)
app.mount("/storage", StaticFiles(directory=str(storage_root)), name="storage")
app.mount("/media", StaticFiles(directory=str(storage_root)), name="media")

# 路由
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(books.router)
app.include_router(tasks.router)


@app.get("/")
def root():
    return {"name": "AI 有声书平台", "version": "0.1.0", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "ok"}
