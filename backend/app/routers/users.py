"""用户路由：获取/更新个人资料。"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.schemas.auth import UserOut

router = APIRouter(prefix="/api/users", tags=["users"])


def _user_to_out(user: User) -> UserOut:
    return UserOut(
        id=user.id,
        email=user.email,
        username=user.username,
        avatar_url=user.avatar_url,
        is_premium=user.is_premium,
        is_active=user.is_active,
        created_at=user.created_at.isoformat() if user.created_at else "",
    )


class UserUpdate(BaseModel):
    username: str | None = None
    avatar_url: str | None = None


@router.get("/me", response_model=UserOut)
def get_profile(user: User = Depends(get_current_user)):
    return _user_to_out(user)


@router.patch("/me", response_model=UserOut)
def update_profile(payload: UserUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if payload.username:
        existing = db.query(User).filter(User.username == payload.username, User.id != user.id).first()
        if existing:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "该用户名已被占用")
        user.username = payload.username
    if payload.avatar_url is not None:
        user.avatar_url = payload.avatar_url
    db.commit()
    db.refresh(user)
    return _user_to_out(user)


@router.post("/me/premium", response_model=UserOut)
def upgrade_premium(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """升级为会员（演示用，真实环境对接支付）。"""
    user.is_premium = True
    db.commit()
    db.refresh(user)
    return _user_to_out(user)
