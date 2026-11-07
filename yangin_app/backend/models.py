from sqlalchemy import Column, Integer, String, Float, DateTime
from database import Base
import datetime

class FireEvent(Base):
    __tablename__ = "fire_events"

    id = Column(Integer, primary_key=True, index=True)
    external_id = Column(String, unique=True, index=True)
    satellite = Column(String)
    sensor = Column(String)
    detected_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)
    latitude = Column(Float)
    longitude = Column(Float)
    fire_metric = Column(Float)
    brightness_temperature = Column(Float)
    confidence = Column(Integer)
    status = Column(String, default="ACTIVE")
    province = Column(String, nullable=True)
    district = Column(String, nullable=True)
    village = Column(String, nullable=True)
    locality = Column(String, nullable=True)

class AdministrativeBoundary(Base):
    __tablename__ = "administrative_boundaries"

    id = Column(Integer, primary_key=True, index=True)
    admin_level = Column(Integer)
    name = Column(String)
    code = Column(String)
    source = Column(String)
