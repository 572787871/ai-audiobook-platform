"""本地文件存储服务。"""
import os
import shutil
from pathlib import Path
from uuid import uuid4
from backend.app.core.config import settings

def ensure_storage_dirs():
    root = Path(settings.LOCAL_STORAGE_ROOT)
    for sub in ["uploads", "audio", "transcripts", "chapters", "covers"]:
        (root / sub).mkdir(parents=True, exist_ok=True)

def save_upload_file(upload_file, subdir: str = "uploads") -> str:
    ensure_storage_dirs()
    root = Path(settings.LOCAL_STORAGE_ROOT)
    ext = Path(upload_file.filename).suffix if upload_file.filename else ""
    filename = f"{uuid4().hex}{ext}"
    dest = root / subdir / filename
    with dest.open("wb") as f:
        shutil.copyfileobj(upload_file.file, f)
    return str(dest)

def file_public_url(file_path: str) -> str:
    if not file_path:
        return ""
    root = str(Path(settings.LOCAL_STORAGE_ROOT).resolve())
    abs_path = str(Path(file_path).resolve())
    if abs_path.startswith(root):
        rel = abs_path[len(root):].lstrip("/")
        return f"{settings.LOCAL_STORAGE_BASE_URL}/{rel}"
    return ""

def get_file_path(rel_or_abs: str) -> Path:
    p = Path(rel_or_abs)
    if p.is_absolute():
        return p
    return Path(settings.LOCAL_STORAGE_ROOT) / rel_or_abs
