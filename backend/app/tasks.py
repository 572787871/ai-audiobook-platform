"""Celery 任务定义：TTS 合成、音频生成、字幕/章节提取。

使用 edge-tts (Microsoft Edge 在线 TTS) 生成真实中文语音。
"""
import os
import json
import asyncio
import tempfile
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

# 默认中文 TTS 声音（可在 .env 中覆盖）
DEFAULT_VOICE = os.getenv("TTS_VOICE", "zh-CN-YunxiNeural")

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
            params["result"] = json.dumps(result, ensure_ascii=False)
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
    """读取上传的源文件文本，兼容中文小说常见编码。

    优先尝试 UTF-8（含 BOM），然后 GB18030/GBK/Big5，
    最后用 chardet 库自动检测（如果安装了）。
    """
    p = Path(file_path)
    if not p.exists():
        return ""
    raw = p.read_bytes()
    if not raw:
        return ""

    # 先试 UTF-8 BOM
    for enc in ("utf-8-sig", "utf-8"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue

    # 尝试 chardet 自动检测
    try:
        import chardet
        det = chardet.detect(raw)
        if det["encoding"] and det["confidence"] > 0.7:
            enc = det["encoding"]
            # chardet 有时返回 GB2312，但它被 GB18030 包含
            if enc.upper() in ("GB2312", "GB2312-80"):
                enc = "gb18030"
            try:
                return raw.decode(enc)
            except (UnicodeDecodeError, LookupError):
                pass
    except ImportError:
        pass

    # 尝试 GB 系列编码
    for enc in ("gb18030", "gbk", "big5"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue

    return raw.decode("utf-8", errors="replace")


def _split_paragraphs(text: str, max_len: int = 500) -> list[str]:
    """将文本按段落切分，每段不超过 max_len 字符。"""
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    raw = [p.strip() for p in normalized.split("\n\n") if p.strip()]
    if not raw:
        raw = [p.strip() for p in normalized.split("\n") if p.strip()]
    result = []
    for para in raw:
        while len(para) > max_len:
            result.append(para[:max_len])
            para = para[max_len:]
        if para:
            result.append(para)
    return result if result else ["（空内容）"]


async def _tts_segment(text: str, voice: str, output_path: Path) -> float:
    """用 edge-tts 合成一段文本，返回音频时长（秒）。"""
    import edge_tts
    communicate = edge_tts.Communicate(text, voice)
    await communicate.save(str(output_path))

    # 用 ffprobe 获取时长
    duration = _probe_audio_duration(output_path)
    return duration


def _probe_audio_duration(audio_path: Path) -> float:
    """用 ffprobe 获取音频时长。"""
    duration_cmd = [
        "ffprobe", "-v", "quiet", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", str(audio_path),
    ]
    try:
        dur_out = subprocess.run(duration_cmd, capture_output=True, text=True, timeout=15)
        duration = float(dur_out.stdout.strip())
    except Exception as exc:
        raise RuntimeError(f"无法读取音频时长: {exc}") from exc
    if duration <= 0:
        raise RuntimeError("音频文件时长为 0")
    return duration


def _merge_mp3(files: list[Path], output: Path) -> float:
    """用 ffmpeg concat 合并多个 MP3 文件为一个大文件，返回总时长。"""
    if len(files) == 1:
        # 单段直接复制
        import shutil
        shutil.copy2(str(files[0]), str(output))
    else:
        # 用 ffmpeg concat demuxer 合并
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".txt", delete=False, dir=str(output.parent), prefix="concat_"
        ) as f:
            for seg in files:
                f.write(f"file '{seg}'\n")
            concat_list = f.name

        cmd = [
            "ffmpeg", "-y", "-f", "concat", "-safe", "0",
            "-i", concat_list, "-c", "copy", str(output),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        os.unlink(concat_list)
        if result.returncode != 0:
            # concat copy 失败时重新编码
            cmd2 = [
                "ffmpeg", "-y", "-f", "concat", "-safe", "0",
                "-i", concat_list, "-c:a", "libmp3lame", "-b:a", "128k", str(output),
            ]
            result2 = subprocess.run(cmd2, capture_output=True, text=True, timeout=300)
            if result2.returncode != 0:
                raise RuntimeError(f"音频合并失败: {result2.stderr[:500]}")

    return _probe_audio_duration(output)


@celery_app.task(name="generate_audio", bind=True)
def generate_audio(self, task_id: int):
    """主 TTS 任务入口。

    流程:
    1. 读取 task + book 记录
    2. 读取上传的源文本文件（自动检测编码）
    3. 用 edge-tts 逐段合成语音
    4. 用 ffmpeg 合并为单个 MP3
    5. 生成 chapters.json 和 transcript.json（含时间轴）
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
        book_row = conn.execute(sa_text("SELECT id, source_file_path, title FROM books WHERE id = :id"),
                               {"id": book_id}).fetchone()
        if not book_row:
            _set_task_status(task_id, "failed", error_message="有声书不存在")
            return {"error": "book not found"}
        source_path = book_row[1]
        title = book_row[2]

    _set_book_status(book_id, "processing")
    _set_task_status(task_id, "processing", progress=5)

    # 2) 读取文本并分段（自动编码检测）
    source_content = _read_source_text(source_path)
    paragraphs = _split_paragraphs(source_content)
    total = len(paragraphs)

    # 3) 逐段合成语音
    audio_dir = STORAGE_ROOT / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)

    # 段落临时目录
    tmp_dir = STORAGE_ROOT / "tmp" / f"task_{task_id}"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    voice = DEFAULT_VOICE
    params = row[2] if isinstance(row[2], dict) else {}
    if isinstance(params, dict) and params.get("voice"):
        voice = params["voice"]

    segment_files = []
    segment_durations = []
    transcript = []

    try:
        for i, para in enumerate(paragraphs):
            pct = int(10 + (i / max(total, 1)) * 75)
            _set_task_status(task_id, "processing", progress=pct)

            seg_path = tmp_dir / f"seg_{i:06d}.mp3"
            duration = asyncio.run(_tts_segment(para, voice, seg_path))
            segment_files.append(seg_path)
            segment_durations.append(duration)

            # 累加时间轴
            start = sum(segment_durations[:-1]) if segment_durations else 0.0
            end = start + duration
            transcript.append({"start": start, "end": end, "text": para})

        _set_task_status(task_id, "processing", progress=85)

        # 4) 合并为最终 MP3
        final_audio_path = audio_dir / f"book_{book_id}.mp3"
        total_duration = _merge_mp3(segment_files, final_audio_path)

    except Exception as exc:
        # 清理临时文件
        import shutil
        shutil.rmtree(tmp_dir, ignore_errors=True)
        message = str(exc)
        _set_book_status(book_id, "failed")
        _set_task_status(task_id, "failed", progress=100, error_message=message)
        return {"status": "failed", "error": message}

    # 清理临时文件
    import shutil
    shutil.rmtree(tmp_dir, ignore_errors=True)

    # 5) 生成 chapters.json
    chapters = []
    for i, para in enumerate(paragraphs):
        start = transcript[i]["start"]
        end = transcript[i]["end"]
        title = para[:30] + ("..." if len(para) > 30 else "")
        chapters.append({"index": i, "title": title, "start": start, "end": end})

    transcript_dir = STORAGE_ROOT / "transcripts"
    chapters_dir = STORAGE_ROOT / "chapters"
    transcript_dir.mkdir(parents=True, exist_ok=True)
    chapters_dir.mkdir(parents=True, exist_ok=True)

    transcript_path = str(transcript_dir / f"book_{book_id}.json")
    chapters_path = str(chapters_dir / f"book_{book_id}.json")

    with open(transcript_path, "w", encoding="utf-8") as f:
        json.dump(transcript, f, ensure_ascii=False, indent=2)
    with open(chapters_path, "w", encoding="utf-8") as f:
        json.dump(chapters, f, ensure_ascii=False, indent=2)

    # 6) 更新 book 和 task
    public_base = os.getenv("PUBLIC_BASE_URL", "http://localhost:8002")
    audio_url = f"{public_base}/media/audio/book_{book_id}.mp3"

    _set_book_status(
        book_id, "completed",
        audio_path=str(final_audio_path), audio_url=audio_url, audio_duration=total_duration,
        transcript_path=transcript_path, chapters_path=chapters_path,
    )
    _set_task_status(task_id, "completed", progress=100,
                    result={"audio_url": audio_url, "duration": total_duration})
    return {"status": "completed", "audio_url": audio_url, "duration": total_duration}
