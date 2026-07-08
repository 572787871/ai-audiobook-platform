"""任务模型。"""
from datetime import datetime, timezone
from sqlalchemy import Integer, String, Text, DateTime, ForeignKey, Column, JSON
from sqlalchemy.orm import relationship
from app.core.database import Base

class Task(Base):
    __tablename__ = "tasks"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    book_id = Column(Integer, ForeignKey("books.id", ondelete="CASCADE"), nullable=False, index=True)
    task_type = Column(String(50), default="tts", nullable=False)
    status = Column(String(50), default="pending", nullable=False, index=True)
    celery_task_id = Column(String(255), nullable=True)
    progress = Column(Integer, default=0, nullable=False)
    error_message = Column(Text, nullable=True)
    params = Column(JSON, nullable=True)
    result = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    completed_at = Column(DateTime, nullable=True)
    user = relationship("User", back_populates="tasks")
    book = relationship("Book", back_populates="tasks")
