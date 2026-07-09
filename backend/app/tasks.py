"""Celery 任务定义：TTS 合成、音频生成、字幕/章节提取。"""
import os
import json
import shlex
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
    """读取上传的源文件文本，兼容中文小说常见编码。"""
    p = Path(file_path)
    if not p.exists():
        return ""
    raw = p.read_bytes()
    for encoding in ("utf-8-sig", "utf-8", "gb18030", "gbk", "big5"):
        try:
            return raw.decode(encoding)
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


def _run_abogen(input_path: Path, output_path: Path, params: dict | None = None):
    """调用 abogen 生成真实音频。

    支持两种配置方式：
    - ABOGEN_COMMAND_TEMPLATE='abogen --input {input} --output {output}'
    - ABOGEN_COMMAND=abogen，自动尝试常见参数形态。
    """
    params = params or {}
    template = os.getenv("ABOGEN_COMMAND_TEMPLATE", "").strip()
    command = os.getenv("ABOGEN_COMMAND", "abogen").strip() or "abogen"
    voice = str(params.get("voice") or os.getenv("ABOGEN_VOICE", "")).strip()
    extra_args = shlex.split(str(params.get("extra_args") or os.getenv("ABOGEN_EXTRA_ARGS", "")))

    candidates: list[list[str]] = []
    if template:
        candidates.append(shlex.split(template.format(input=str(input_path), output=str(output_path), voice=voice)))
    else:
        base = [command]
        if voice:
            base.extend(["--voice", voice])
        base.extend(extra_args)
        candidates.extend([
            [*base, "--input", str(input_path), "--output", str(output_path)],
            [*base, "-i", str(input_path), "-o", str(output_path)],
            [*base, str(input_path), str(output_path)],
        ])

    errors = []
    for cmd in candidates:
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=int(os.getenv("ABOGEN_TIMEOUT", "3600")))
        except FileNotFoundError as exc:
            raise RuntimeError("未找到 abogen 命令。请在 worker 镜像中安装 abogen，或设置 ABOGEN_COMMAND/ABOGEN_COMMAND_TEMPLATE。") from exc
        except subprocess.TimeoutExpired as exc:
            errors.append(f"{' '.join(cmd)} 超时")
            continue
        if result.returncode == 0 and output_path.exists() and output_path.stat().st_size > 0:
            return
        errors.append(
            f"{' '.join(cmd)} -> code={result.returncode}, stderr={(result.stderr or result.stdout or '').strip()[:800]}"
        )
    raise RuntimeError("abogen 生成失败：" + " | ".join(errors))


def _probe_audio_duration(audio_path: Path) -> float:
    duration_cmd = [
        "ffprobe", "-v", "quiet", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", str(audio_path),
    ]
    try:
        dur_out = subprocess.run(duration_cmd, capture_output=True, text=True, timeout=15)
        duration = float(dur_out.stdout.strip())
    except Exception as exc:
        raise RuntimeError(f"音频文件已生成，但无法读取时长或格式不被支持: {exc}") from exc
    if duration <= 0:
        raise RuntimeError("音频文件时长为 0，请检查 abogen 输出格式")
    return duration


def _build_timeline(paragraphs: list[str], duration: float):
    total_chars = max(sum(max(len(p), 1) for p in paragraphs), 1)
    transcript = []
    chapters = []
    current_time = 0.0
    for i, para in enumerate(paragraphs):
        weight = max(len(para), 1) / total_chars
        seg_duration = duration * weight
        if i == len(paragraphs) - 1:
            end = duration
        else:
            end = min(duration, current_time + seg_duration)
        transcript.append({"start": current_time, "end": end, "text": para})
        chapters.append({
            "index": i,
            "title": para[:30] + ("..." if len(para) > 30 else ""),
            "start": current_time,
            "end": end,
        })
        current_time = end
    return transcript, chapters


@celery_app.task(name="generate_audio", bind=True)
def generate_audio(self, task_id: int):
    """主 TTS 任务入口。

    流程:
    1. 读取 task + book 记录
    2. 读取上传的源文本文件
    3. 调用 abogen 合成真实音频
    4. 校验 mp3 时长和可播放性
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

    # 3) 调用 abogen 合成真实音频
    audio_dir = STORAGE_ROOT / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    final_audio_path = audio_dir / f"book_{book_id}.mp3"
    normalized_source = audio_dir / f"book_{book_id}_source_utf8.txt"
    normalized_source.write_text("\n\n".join(paragraphs), encoding="utf-8")
    try:
        _set_task_status(task_id, "processing", progress=35)
        params = row[2] if isinstance(row[2], dict) else {}
        _run_abogen(normalized_source, final_audio_path, params=params)
        _set_task_status(task_id, "processing", progress=85)
        duration = _probe_audio_duration(final_audio_path)
    except Exception as exc:
        message = str(exc)
        _set_book_status(book_id, "failed")
        _set_task_status(task_id, "failed", progress=100, error_message=message)
        return {"status": "failed", "error": message}

    transcript, chapters = _build_timeline(paragraphs, duration)

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

    audio_url = os.getenv("PUBLIC_BASE_URL", "http://localhost:8002") + "/media/audio/book_" + str(book_id) + ".mp3"

    _set_book_status(
        book_id, "completed",
        audio_path=str(final_audio_path), audio_url=audio_url, audio_duration=duration,
        transcript_path=transcript_path, chapters_path=chapters_path,
    )
    _set_task_status(task_id, "completed", progress=100,
                    result={"audio_url": audio_url, "duration": duration})
    return {"status": "completed", "audio_url": audio_url, "duration": duration}
