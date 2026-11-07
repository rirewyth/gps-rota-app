from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List
import json
import asyncio

import models
import schemas
from database import engine, get_db

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Orman Yangınlarını Anlık Takip Sistemi")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            await connection.send_text(message)

manager = ConnectionManager()

@app.websocket("/ws/fires")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)

@app.get("/api/fires", response_model=List[schemas.FireEventResponse])
def get_fires(db: Session = Depends(get_db)):
    fires = db.query(models.FireEvent).all()
    return fires

@app.get("/api/fires/active", response_model=List[schemas.FireEventResponse])
def get_active_fires(db: Session = Depends(get_db)):
    fires = db.query(models.FireEvent).filter(models.FireEvent.status == "ACTIVE").all()
    return fires

@app.post("/api/fires", response_model=schemas.FireEventResponse)
async def create_fire(fire: schemas.FireEventCreate, db: Session = Depends(get_db)):
    db_fire = db.query(models.FireEvent).filter(models.FireEvent.external_id == fire.external_id).first()
    if db_fire:
        raise HTTPException(status_code=400, detail="Fire event already registered")
    
    new_fire = models.FireEvent(**fire.model_dump())
    db.add(new_fire)
    db.commit()
    db.refresh(new_fire)
    
    # Broadcast new fire event
    event_data = {
        "event": "NEW_FIRE",
        "fire_id": new_fire.external_id,
        "latitude": new_fire.latitude,
        "longitude": new_fire.longitude,
        "province": new_fire.province,
        "district": new_fire.district,
        "fire_metric": new_fire.fire_metric,
        "confidence": new_fire.confidence
    }
    await manager.broadcast(json.dumps(event_data))
    
    return new_fire

@app.get("/api/system/status")
def system_status():
    return {
        "status": "SYSTEM ONLINE",
        "satellite": "CONNECTED",
        "processing": "READY"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
