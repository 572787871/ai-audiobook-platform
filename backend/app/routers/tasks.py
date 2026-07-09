"""任务路由：创建、列表、详情、取消。"""
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.book import Book
from app.models.task import Task
from app.schemas.task import TaskCreate, TaskOut, TaskListOut

router = APIRouter(prefix="/api/tasks", tags=["tasks"])


def _task_to_out(task: Task) -> TaskOut:
    return TaskOut(
        id=task.id,
        user_id=task.user_id,
        book_id=task.book_id,
        task_type=task.task_type,
        status=task.status,
        progress=task.progress,
        error_message=task.error_message,
        celery_task_id=task.celery_task_id,
        created_at=task.created_at.isoformat() if task.created_at else "",
        updated_at=task.updated_at.isoformat() if task.updated_at else "",
        completed_at=task.completed_at.isoformat() if task.completed_at else None,
    )


@router.post("", response_model=TaskOut, status_code=status.HTTP_201_CREATED)
def create_task(payload: TaskCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """创建 TTS 任务，提交 Celery worker 处理。"""
    book = db.query(Book).filter(Book.id == payload.book_id, Book.user_id == user.id).first()
    if not book:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "有声书不存在")
    task = Task(
        user_id=user.id,
        book_id=payload.book_id,
        task_type=payload.task_type,
        params=payload.params or {},
        status="pending",
    )
    db.add(task)
    db.commit()
    db.refresh(task)

    # 提交 Celery 异步任务
    try:
        result = generate_audio.delay(task.id)
        task.celery_task_id = result.id
        db.commit()
        db.refresh(task)
    except Exception as e:
        # Celery 不可用时仍返回 task，前端可轮询状态
        task.status = "pending"
        task.error_message = f"Celery 提交失败: {e}"
        db.commit()
        db.refresh(task)

    return _task_to_out(task)


@router.get("", response_model=TaskListOut)
def list_tasks(
    status_filter: str | None = None,
    page: int = 1,
    page_size: int = 20,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = db.query(Task).filter(Task.user_id == user.id).order_by(Task.created_at.desc())
    if status_filter:
        q = q.filter(Task.status == status_filter)
    total = q.count()
    items = q.offset((page - 1) * page_size).limit(page_size).all()
    return TaskListOut(total=total, items=[_task_to_out(t) for t in items])


@router.get("/{task_id}", response_model=TaskOut)
def get_task(task_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    task = db.query(Task).filter(Task.id == task_id, Task.user_id == user.id).first()
    if not task:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "任务不存在")
    return _task_to_out(task)


@router.post("/{task_id}/cancel", response_model=TaskOut)
def cancel_task(task_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    task = db.query(Task).filter(Task.id == task_id, Task.user_id == user.id).first()
    if not task:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "任务不存在")
    if task.status in ("completed", "failed"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "任务已结束，无法取消")
    task.status = "failed"
    task.error_message = "用户取消"
    task.completed_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(task)
    return _task_to_out(task)
