"""有声书模型。"""
from datetime import datetime, timezone
from sqlalchemy import Integer, String, Text, DateTime, Float, ForeignKey, Column
from sqlalchemy.orm import relationship
from backend.app.core.database import Base

class Book(Base):
    __tablename__ = "books"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title = Column(String(255), nullable=False)
    author = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    cover_url = Column(String(512), nullable=True)
    source_file_path = Column(String(512), nullable=False)
    source_file_size = Column(Integer, nullable=True)
    audio_file_path = Column(String(512), nullable=True)
    audio_duration = Column(Float, nullable=True)
    audio_url = Column(String(512), nullable=True)
    transcript_path = Column(String(512), nullable=True)
    chapters_path = Column(String(512), nullable=True)
    status = Column(String(50), default="pending", nullable=False, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    user = relationship("User", back_populates="books")
    tasks = relationship("Task", back_populates="book", cascade="all, delete-orphan")
