from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import time

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

users_db = {"test@test.com": {"password": "123456", "username": "TestUser"}}
tokens = {}  # token -> email
waves = {}   # email -> {track_title, artist, track_url, position_sec, started_at, is_playing}

class LoginReq(BaseModel):
    email: str
    password: str

class WaveStart(BaseModel):
    track_title: str
    artist: str
    track_url: str
    position_sec: int = 0

class SyncReq(BaseModel):
    position_sec: int


def current_user(authorization: Optional[str]):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "No token")
    token = authorization.split(" ")[1]
    if token not in tokens:
        raise HTTPException(401, "Invalid token")
    return tokens[token]


@app.post("/login")
def login(req: LoginReq):
    user = users_db.get(req.email)
    if not user or user["password"] != req.password:
        raise HTTPException(401, "Invalid credentials")
    token = f"tok_{int(time.time())}_{req.email}"
    tokens[token] = req.email
    return {"token": token, "username": user["username"]}


@app.get("/feed")
def feed(authorization: Optional[str] = Header(None)):
    me = current_user(authorization)
    now = time.time()
    result = []
    for email, w in waves.items():
        if email == me:
            continue
        elapsed = now - w["started_at"] if w["is_playing"] else 0
        pos = w["position_sec"] + int(elapsed)
        result.append({
            "id": email,
            "username": users_db[email]["username"],
            "track_title": w["track_title"],
            "artist": w["artist"],
            "track_url": w["track_url"],
            "position_sec": pos,
        })
    return result


@app.post("/wave/start")
def wave_start(req: WaveStart, authorization: Optional[str] = Header(None)):
    me = current_user(authorization)
    waves[me] = {
        **req.dict(),
        "started_at": time.time(),
        "is_playing": True,
    }
    return {"ok": True}


@app.post("/wave/stop")
def wave_stop(authorization: Optional[str] = Header(None)):
    me = current_user(authorization)
    waves.pop(me, None)
    return {"ok": True}


@app.post("/wave/join/{user_id}")
def wave_join(user_id: str, authorization: Optional[str] = Header(None)):
    current_user(authorization)
    w = waves.get(user_id)
    if not w:
        raise HTTPException(404, "User is not sharing")
    elapsed = time.time() - w["started_at"] if w["is_playing"] else 0
    return {"position_sec": w["position_sec"] + int(elapsed)}


@app.patch("/wave/sync")
def wave_sync(req: SyncReq, authorization: Optional[str] = Header(None)):
    me = current_user(authorization)
    if me in waves:
        waves[me]["position_sec"] = req.position_sec
        waves[me]["started_at"] = time.time()
    return {"ok": True}


@app.post("/wave/leave")
def wave_leave(authorization: Optional[str] = Header(None)):
    return {"ok": True}