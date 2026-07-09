"""认证路由：注册、登录、获取当前用户。"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.app.core.database import get_db
from backend.app.core.security import hash_password, verify_password, create_access_token
from backend.app.core.deps import get_current_user
from backend.app.models.user import User
from backend.app.schemas.auth import UserRegister, UserLogin, UserOut, TokenOut

router = APIRouter(prefix="/api/auth", tags=["auth"])


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


@router.post("/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
def register(payload: UserRegister, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == payload.email).first():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "该邮箱已被注册")
    if db.query(User).filter(User.username == payload.username).first():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "该用户名已被占用")
    user = User(
        email=payload.email,
        username=payload.username,
        hashed_password=hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    token = create_access_token(str(user.id))
    return TokenOut(access_token=token, user=_user_to_out(user))


@router.post("/login", response_model=TokenOut)
def login(payload: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == payload.email).first()
    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "邮箱或密码错误")
    if not user.is_active:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "账户已被禁用")
    token = create_access_token(str(user.id))
    return TokenOut(access_token=token, user=_user_to_out(user))


@router.get("/me", response_model=UserOut)
def get_me(user: User = Depends(get_current_user)):
    return _user_to_out(user)
