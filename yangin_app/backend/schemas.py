from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class FireEventBase(BaseModel):
    external_id: str
    satellite: str
    sensor: str
    latitude: float
    longitude: float
    fire_metric: float
    brightness_temperature: float
    confidence: int
    status: str
    province: Optional[str] = None
    district: Optional[str] = None
    village: Optional[str] = None
    locality: Optional[str] = None

class FireEventCreate(FireEventBase):
    pass

class FireEventResponse(FireEventBase):
    id: int
    detected_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
