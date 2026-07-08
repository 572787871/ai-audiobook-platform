"""有声书相关 Pydantic 模型。"""
from pydantic import BaseModel

class BookOut(BaseModel):
    id: int
    user_id: int
    title: str
    author: str | None = None
    description: str | None = None
    cover_url: str | None = None
    audio_url: str | None = None
    audio_duration: float | None = None
    status: str
    created_at: str
    updated_at: str
    model_config = {"from_attributes": True}

class BookUpdate(BaseModel):
    title: str | None = None
    author: str | None = None
    description: str | None = None
    cover_url: str | None = None

class BookListOut(BaseModel):
    total: int
    items: list[BookOut]

class ChapterOut(BaseModel):
    index: int
    title: str
    start: float
    end: float

class TranscriptLine(BaseModel):
    start: float
    end: float
    text: str

class BookDetailOut(BaseModel):
    id: int
    user_id: int
    title: str
    author: str | None = None
    description: str | None = None
    cover_url: str | None = None
    audio_url: str | None = None
    audio_duration: float | None = None
    status: str
    chapters: list[ChapterOut] = []
    transcript: list[TranscriptLine] = []
    created_at: str
    updated_at: str
