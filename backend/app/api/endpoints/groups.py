from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel

from app.core.database import get_db
from app.models import Group

router = APIRouter(prefix="/groups", tags=["groups"])


# ==================== Schemas ====================

class GroupBase(BaseModel):
    code: str
    name: str
    description: Optional[str] = None
    group_type: Optional[str] = None
    parent_id: Optional[int] = None


class GroupCreate(GroupBase):
    pass


class GroupUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    group_type: Optional[str] = None
    is_active: Optional[bool] = None


class GroupResponse(GroupBase):
    id: int
    level: int
    full_path: Optional[str]
    is_active: bool
    
    class Config:
        from_attributes = True


class GroupTreeNode(GroupResponse):
    children: List['GroupTreeNode'] = []


# Для рекурсії
GroupTreeNode.model_rebuild()


# ==================== Endpoints ====================

@router.get("/", response_model=List[GroupResponse])
def get_groups(
    skip: int = 0,
    limit: int = 100,
    group_type: Optional[str] = None,
    is_active: Optional[bool] = None,
    db: Session = Depends(get_db)
):
    """
    Отримати список всіх груп
    """
    query = db.query(Group)
    
    if group_type:
        query = query.filter(Group.group_type == group_type)
    
    if is_active is not None:
        query = query.filter(Group.is_active == is_active)
    
    groups = query.order_by(Group.full_path).offset(skip).limit(limit).all()
    return groups


@router.get("/tree", response_model=List[GroupTreeNode])
def get_groups_tree(
    group_type: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Отримати дерево груп
    """
    query = db.query(Group).filter(Group.is_active == True)
    
    if group_type:
        query = query.filter(Group.group_type == group_type)
    
    all_groups = query.order_by(Group.level, Group.id).all()
    
    # Побудувати дерево
    groups_dict = {g.id: GroupTreeNode.from_orm(g) for g in all_groups}
    
    root_groups = []
    for group in all_groups:
        node = groups_dict[group.id]
        if group.parent_id is None:
            root_groups.append(node)
        else:
            parent = groups_dict.get(group.parent_id)
            if parent:
                parent.children.append(node)
    
    return root_groups


@router.get("/{group_id}", response_model=GroupResponse)
def get_group(group_id: int, db: Session = Depends(get_db)):
    """
    Отримати групу по ID
    """
    group = db.query(Group).filter(Group.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    return group


@router.get("/code/{code}", response_model=GroupResponse)
def get_group_by_code(code: str, db: Session = Depends(get_db)):
    """
    Отримати групу по коду
    """
    group = db.query(Group).filter(Group.code == code).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    return group


@router.post("/", response_model=GroupResponse, status_code=201)
def create_group(group: GroupCreate, db: Session = Depends(get_db)):
    """
    Створити нову групу
    """
    # Перевірити чи код унікальний
    existing = db.query(Group).filter(Group.code == group.code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Group with this code already exists")
    
    # Визначити level
    level = 1
    full_path = group.name
    
    if group.parent_id:
        parent = db.query(Group).filter(Group.id == group.parent_id).first()
        if not parent:
            raise HTTPException(status_code=404, detail="Parent group not found")
        level = parent.level + 1
        full_path = f"{parent.full_path} → {group.name}"
    
    # Створити
    db_group = Group(
        **group.model_dump(),
        level=level,
        full_path=full_path
    )
    
    db.add(db_group)
    db.commit()
    db.refresh(db_group)
    
    return db_group


@router.patch("/{group_id}", response_model=GroupResponse)
def update_group(group_id: int, group: GroupUpdate, db: Session = Depends(get_db)):
    """
    Оновити групу
    """
    db_group = db.query(Group).filter(Group.id == group_id).first()
    if not db_group:
        raise HTTPException(status_code=404, detail="Group not found")
    
    # Оновити поля
    update_data = group.model_dump(exclude_unset=True)
    
    for field, value in update_data.items():
        setattr(db_group, field, value)
    
    # Якщо змінилась назва - оновити full_path
    if 'name' in update_data:
        if db_group.parent_id:
            parent = db.query(Group).filter(Group.id == db_group.parent_id).first()
            db_group.full_path = f"{parent.full_path} → {db_group.name}"
        else:
            db_group.full_path = db_group.name
    
    db.commit()
    db.refresh(db_group)
    
    return db_group


@router.delete("/{group_id}", status_code=204)
def delete_group(group_id: int, db: Session = Depends(get_db)):
    """
    Видалити групу (soft delete)
    """
    db_group = db.query(Group).filter(Group.id == group_id).first()
    if not db_group:
        raise HTTPException(status_code=404, detail="Group not found")
    
    # Перевірити чи немає дочірніх груп
    children = db.query(Group).filter(Group.parent_id == group_id, Group.is_active == True).count()
    if children > 0:
        raise HTTPException(status_code=400, detail="Cannot delete group with active children")
    
    # Soft delete
    db_group.is_active = False
    db.commit()
    
    return None