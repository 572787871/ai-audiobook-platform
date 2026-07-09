"""Celery 任务定义：TTS 合成、音频生成、字幕/章节提取。"""
import os
import json
import subprocess
from pathlib import Path
from datetime import datetime, timezone

from sqlalchemy import create_engine, text as sa_text

from backend.app.celery_app import celery_app

DB_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://{user}:{pwd}@{host}:{port}/{db}".format(
        user=os.getenv("POSTGRES_USER", "audiobook"),
        pwd=os.getenv("POSTGRES_PASSWORD", "audiobook_secret"),
        host=os.getenv("POSTGRES_HOST", "db"),
        port=os.getenv("POSTGRES_PORT", "5432"),
        db=os.getenv("POSTGRES_DB", "audiobook"),
    ),
)
STORAGE_ROOT = Path(os.getenv("LOCAL_STORAGE_ROOT", "./storage"))

engine = create_engine(DB_URL, pool_pre_ping=True)


def _set_task_status(task_id, status, progress=None, error_message=None, result=None):
    """更新任务状态。"""
    with engine.connect() as conn:
        fields = ["status = :status", "updated_at = :updated_at"]
        params = {"status": status, "updated_at": datetime.now(timezone.utc), "task_id": task_id}
        if progress is not None:
            fields.append("progress = :progress")
            params["progress"] = progress
        if error_message is not None:
            fields.append("error_message = :error_message")
            params["error_message"] = error_message
        if result is not None:
            fields.append("result = :result")
            params["result"] = json.dumps(result)
        if status in ("completed", "failed"):
            fields.append("completed_at = :completed_at")
            params["completed_at"] = datetime.now(timezone.utc)
        sql = sa_text("UPDATE tasks SET " + ", ".join(fields) + " WHERE id = :task_id")
        conn.execute(sql, params)
        conn.commit()


def _set_book_status(book_id, status, audio_path=None, audio_url=None, audio_duration=None,
                     transcript_path=None, chapters_path=None):
    """更新有声书状态。"""
    with engine.connect() as conn:
        fields = ["status = :status", "updated_at = :updated_at"]
        params = {"status": status, "updated_at": datetime.now(timezone.utc), "book_id": book_id}
        if audio_path is not None:
            fields.append("audio_file_path = :audio_file_path")
            params["audio_file_path"] = audio_path
        if audio_url is not None:
            fields.append("audio_url = :audio_url")
            params["audio_url"] = audio_url
        if audio_duration is not None:
            fields.append("audio_duration = :audio_duration")
            params["audio_duration"] = audio_duration
        if transcript_path is not None:
            fields.append("transcript_path = :transcript_path")
            params["transcript_path"] = transcript_path
        if chapters_path is not None:
            fields.append("chapters_path = :chapters_path")
            params["chapters_path"] = chapters_path
        sql = sa_text("UPDATE books SET " + ", ".join(fields) + " WHERE id = :book_id")
        conn.execute(sql, params)
        conn.commit()


def _read_source_text(file_path: str) -> str:
    """读取上传的源文件文本。"""
    p = Path(file_path)
    if not p.exists():
        return ""
    try:
        return p.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def _split_paragraphs(text: str, max_len: int = 500) -> list[str]:
    """将文本按段落切分，每段不超过 max_len 字符。"""
    raw = [p.strip() for p in text.split("\n\n") if p.strip()]
    result = []
    for para in raw:
        while len(para) > max_len:
            result.append(para[:max_len])
            para = para[max_len:]
        if para:
            result.append(para)
    return result if result else ["（空内容）"]


def _generate_silent_audio(output_path: str, duration_sec: float):
    """生成静音占位音频（后续接入 abogen 替换为真实 TTS）。"""
    cmd = [
        "ffmpeg", "-y", "-f", "lavfi",
        "-i", "anullsrc=r=24000:cl=mono",
        "-t", str(max(duration_sec, 0.1)),
        "-q:a", "9",
        output_path,
    ]
    subprocess.run(cmd, capture_output=True, timeout=60)


@celery_app.task(name="generate_audio", bind=True)
def generate_audio(self, task_id: int):
    """主 TTS 任务入口。

    流程:
    1. 读取 task + book 记录
    2. 读取上传的源文本文件
    3. 按段落切分，逐段合成（当前 stub：用 ffmpeg 生成静音占位 + 提取文字作为字幕）
    4. 合并为单一 mp3
    5. 生成 chapters.json 和 transcript.json
    6. 更新 book 和 task 状态
    """
    _set_task_status(task_id, "processing", progress=0)

    # 1) 读取 task + book
    with engine.connect() as conn:
        row = conn.execute(sa_text("SELECT id, book_id, params FROM tasks WHERE id = :id"),
                          {"id": task_id}).fetchone()
        if not row:
            _set_task_status(task_id, "failed", error_message="任务不存在")
            return {"error": "task not found"}
        book_id = row[1]
        book_row = conn.execute(
            sa_text("SELECT id, source_file_path, title FROM books WHERE id = :id"),
            {"id": book_id}).fetchone()
        if not book_row:
            _set_task_status(task_id, "failed", error_message="有声书不存在")
            return {"error": "book not found"}
        source_path = book_row[1]
        title = book_row[2]

    _set_book_status(book_id, "processing")
    _set_task_status(task_id, "processing", progress=10)

    # 2) 读取文本并分段
    source_content = _read_source_text(source_path)
    paragraphs = _split_paragraphs(source_content)
    total = len(paragraphs)

    # 3) 逐段合成（当前 stub：静音占位 + 字幕记录）
    audio_dir = STORAGE_ROOT / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    segment_files = []
    transcript = []
    chapters = []
    current_time = 0.0

    for i, para in enumerate(paragraphs):
        progress = 10 + int(80 * (i + 1) / total)
        _set_task_status(task_id, "processing", progress=progress)

        seg_path = str(audio_dir / f"task_{task_id}_seg_{i}.mp3")
        seg_duration = max(5.0, min(len(para) / 20.0, 300.0))
        _generate_silent_audio(seg_path, seg_duration)
        segment_files.append(seg_path)

        start = current_time
        end = current_time + seg_duration
        transcript.append({"start": start, "end": end, "text": para})
        chapters.append({
            "index": i,
            "title": para[:30] + ("..." if len(para) > 30 else ""),
            "start": start,
            "end": end,
        })
        current_time = end

    # 4) 合并为单一 mp3
    _set_task_status(task_id, "processing", progress=92)
    final_audio = str(audio_dir / f"book_{book_id}.mp3")
    concat_list = audio_dir / f"task_{task_id}_concat.txt"
    with open(concat_list, "w") as f:
        for seg in segment_files:
            f.write(f"file {seg}\n")
    cmd = ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(concat_list),
           "-c", "copy", final_audio]
    subprocess.run(cmd, capture_output=True, timeout=120)

    # 清理临时分段文件
    for seg in segment_files:
        try:
            Path(seg).unlink()
        except Exception:
            pass
    try:
        concat_list.unlink()
    except Exception:
        pass

    # 5) 写 transcript.json 和 chapters.json
    transcript_dir = STORAGE_ROOT / "transcripts"
    chapters_dir = STORAGE_ROOT / "chapters"
    transcript_dir.mkdir(parents=True, exist_ok=True)
    chapters_dir.mkdir(parents=True, exist_ok=True)
    transcript_path = str(transcript_dir / f"book_{book_id}.json")
    chapters_path = str(chapters_dir / f"book_{book_id}.json")
    with open(transcript_path, "w", encoding="utf-8") as f:
        json.dump(transcript, f, ensure_ascii=False)
    with open(chapters_path, "w", encoding="utf-8") as f:
        json.dump(chapters, f, ensure_ascii=False)

    # 6) 计算音频时长
    duration_cmd = ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
                    "-of", "default=noprint_wrappers=1:nokey=1", final_audio]
    try:
        dur_out = subprocess.run(duration_cmd, capture_output=True, text=True, timeout=15)
        duration = float(dur_out.stdout.strip())
    except Exception:
        duration = current_time

    audio_url = os.getenv("PUBLIC_BASE_URL", "http://localhost:8002") + "/media/audio/book_" + str(book_id) + ".mp3"

    _set_book_status(
        book_id, "completed",
        audio_path=final_audio, audio_url=audio_url, audio_duration=duration,
        transcript_path=transcript_path, chapters_path=chapters_path,
    )
    _set_task_status(task_id, "completed", progress=100,
                    result={"audio_url": audio_url, "duration": duration})
    return {"status": "completed", "audio_url": audio_url, "duration": duration}
