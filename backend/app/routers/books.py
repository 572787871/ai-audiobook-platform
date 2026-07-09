"""有声书路由：上传、列表、详情、更新、删除、下载。"""
import json
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from backend.app.core.database import get_db
from backend.app.core.deps import get_current_user
from backend.app.models.user import User
from backend.app.models.book import Book
from backend.app.models.task import Task
from backend.app.schemas.book import BookOut, BookUpdate, BookListOut, BookDetailOut, ChapterOut, TranscriptLine
from backend.app.schemas.task import TaskOut, TaskListOut
from backend.app.services.storage import save_upload_file, file_public_url, get_file_path, ensure_storage_dirs

router = APIRouter(prefix="/api/books", tags=["books"])


def _book_to_out(book: Book) -> BookOut:
    return BookOut(
        id=book.id,
        user_id=book.user_id,
        title=book.title,
        author=book.author,
        description=book.description,
        cover_url=book.cover_url,
        audio_url=book.audio_url,
        audio_duration=book.audio_duration,
        status=book.status,
        created_at=book.created_at.isoformat() if book.created_at else "",
        updated_at=book.updated_at.isoformat() if book.updated_at else "",
    )


def _load_chapters(book: Book) -> list[ChapterOut]:
    if not book.chapters_path:
        return []
    p = get_file_path(book.chapters_path)
    if not p.exists():
        return []
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
        return [ChapterOut(**c) for c in data]
    except Exception:
        return []


def _load_transcript(book: Book) -> list[TranscriptLine]:
    if not book.transcript_path:
        return []
    p = get_file_path(book.transcript_path)
    if not p.exists():
        return []
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
        return [TranscriptLine(**t) for t in data]
    except Exception:
        return []


def _book_to_detail(book: Book) -> BookDetailOut:
    return BookDetailOut(
        id=book.id,
        user_id=book.user_id,
        title=book.title,
        author=book.author,
        description=book.description,
        cover_url=book.cover_url,
        audio_url=book.audio_url,
        audio_duration=book.audio_duration,
        status=book.status,
        chapters=_load_chapters(book),
        transcript=_load_transcript(book),
        created_at=book.created_at.isoformat() if book.created_at else "",
        updated_at=book.updated_at.isoformat() if book.updated_at else "",
    )


@router.post("/upload", response_model=BookOut, status_code=status.HTTP_201_CREATED)
def upload_book(
    file: UploadFile = File(...),
    title: str = Form(...),
    author: str = Form(None),
    description: str = Form(None),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """上传原始文本/电子书文件，创建有声书记录。"""
    saved_path = save_upload_file(file)
    file_size = Path(saved_path).stat().st_size if Path(saved_path).exists() else None
    book = Book(
        user_id=user.id,
        title=title,
        author=author,
        description=description,
        source_file_path=saved_path,
        source_file_size=file_size,
        status="pending",
    )
    db.add(book)
    db.commit()
    db.refresh(book)
    return _book_to_out(book)


@router.get("", response_model=BookListOut)
def list_books(
    page: int = 1,
    page_size: int = 20,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = db.query(Book).filter(Book.user_id == user.id).order_by(Book.created_at.desc())
    total = q.count()
    items = q.offset((page - 1) * page_size).limit(page_size).all()
    return BookListOut(total=total, items=[_book_to_out(b) for b in items])


@router.get("/{book_id}", response_model=BookDetailOut)
def get_book(book_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    book = db.query(Book).filter(Book.id == book_id, Book.user_id == user.id).first()
    if not book:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "有声书不存在")
    return _book_to_detail(book)


@router.patch("/{book_id}", response_model=BookOut)
def update_book(book_id: int, payload: BookUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    book = db.query(Book).filter(Book.id == book_id, Book.user_id == user.id).first()
    if not book:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "有声书不存在")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(book, k, v)
    db.commit()
    db.refresh(book)
    return _book_to_out(book)


@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_book(book_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    book = db.query(Book).filter(Book.id == book_id, Book.user_id == user.id).first()
    if not book:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "有声书不存在")
    db.delete(book)
    db.commit()


@router.get("/{book_id}/download")
def download_book(book_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """下载合成后的音频文件。"""
    book = db.query(Book).filter(Book.id == book_id, Book.user_id == user.id).first()
    if not book:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "有声书不存在")
    if not book.audio_file_path:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "音频尚未生成")
    p = get_file_path(book.audio_file_path)
    if not p.exists():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "音频文件不存在")
    return FileResponse(str(p), media_type="audio/mpeg", filename=f"{book.title}.mp3")


@router.get("/{book_id}/tasks", response_model=TaskListOut)
def list_book_tasks(book_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    book = db.query(Book).filter(Book.id == book_id, Book.user_id == user.id).first()
    if not book:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "有声书不存在")
    q = db.query(Task).filter(Task.book_id == book_id).order_by(Task.created_at.desc())
    total = q.count()
    items = q.all()
    return TaskListOut(total=total, items=[_task_to_out(t) for t in items])
