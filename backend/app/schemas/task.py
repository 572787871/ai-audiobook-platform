"""任务相关 Pydantic 模型。"""
from pydantic import BaseModel

class TaskCreate(BaseModel):
    book_id: int
    task_type: str = "tts"
    params: dict | None = None

class TaskOut(BaseModel):
    id: int
    user_id: int
    book_id: int
    task_type: str
    status: str
    progress: int
    error_message: str | None = None
    celery_task_id: str | None = None
    created_at: str
    updated_at: str
    completed_at: str | None = None
    model_config = {"from_attributes": True}

class TaskListOut(BaseModel):
    total: int
    items: list[TaskOut]
