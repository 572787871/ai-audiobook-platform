"""认证相关 Pydantic 模型。"""
from pydantic import BaseModel, EmailStr, Field

class UserRegister(BaseModel):
    email: EmailStr
    username: str = Field(min_length=2, max_length=100)
    password: str = Field(min_length=6, max_length=128)

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserOut(BaseModel):
    id: int
    email: str
    username: str
    avatar_url: str | None = None
    is_premium: bool
    is_active: bool
    created_at: str
    model_config = {"from_attributes": True}

class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
