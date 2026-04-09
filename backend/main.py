import json
import uuid
import os
import anthropic
from dotenv import load_dotenv

# Завантажити змінні з .env файлу
load_dotenv()

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from debate_manager import DebateSession
from prompts import ANALYSIS_SYSTEM, TOPIC_SUGGESTIONS_SYSTEM

app = FastAPI(title="Debate Arena API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# API key повинен міститися в змінній оточення ANTHROPIC_API_KEY
api_key = os.getenv("ANTHROPIC_API_KEY")
if not api_key:
    raise ValueError("ANTHROPIC_API_KEY не встановлений у змінних оточення")
client = anthropic.AsyncAnthropic(api_key=api_key)

# In-memory session store (week 1 — no DB yet)
sessions: dict[str, DebateSession] = {}


# ── REST ──────────────────────────────────────────────────────────────────────

class StartDebateRequest(BaseModel):
    topic: str
    user_position: str
    total_rounds: int = 5


@app.post("/debate/start")
async def start_debate(req: StartDebateRequest):
    session_id = str(uuid.uuid4())
    sessions[session_id] = DebateSession(
        session_id=session_id,
        topic=req.topic,
        user_position=req.user_position,
        total_rounds=req.total_rounds,
    )
    return {"session_id": session_id, "topic": req.topic, "total_rounds": req.total_rounds}


@app.get("/debate/{session_id}/status")
async def session_status(session_id: str):
    session = sessions.get(session_id)
    if not session:
        raise HTTPException(404, "Session not found")
    return {
        "session_id": session_id,
        "topic": session.topic,
        "current_round": session.current_round,
        "total_rounds": session.total_rounds,
        "is_finished": session.is_finished,
    }


@app.get("/debate/{session_id}/analysis")
async def get_analysis(session_id: str):
    session = sessions.get(session_id)
    if not session:
        raise HTTPException(404, "Session not found")
    if not session.is_finished:
        raise HTTPException(400, "Debate not finished yet")

    response = await client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1000,
        system=ANALYSIS_SYSTEM,
        messages=session.analysis_messages(),
    )
    return json.loads(response.content[0].text.strip())


@app.get("/topics/suggestions")
async def suggest_topics():
    response = await client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=400,
        system=TOPIC_SUGGESTIONS_SYSTEM,
        messages=[{"role": "user", "content": "Generate topics"}],
    )
    return {"topics": json.loads(response.content[0].text.strip())}


# ── WebSocket ─────────────────────────────────────────────────────────────────

@app.websocket("/ws/debate/{session_id}")
async def debate_websocket(ws: WebSocket, session_id: str):
    await ws.accept()

    session = sessions.get(session_id)
    if not session:
        await ws.send_json({"type": "error", "message": "Session not found"})
        await ws.close()
        return

    try:
        while True:
            data = json.loads(await ws.receive_text())

            if data.get("type") != "argument":
                await ws.send_json({"type": "error", "message": "Unknown message type"})
                continue

            if session.is_finished:
                await ws.send_json({"type": "error", "message": "Debate already finished"})
                continue

            user_text: str = data.get("text", "").strip()
            if not user_text:
                await ws.send_json({"type": "error", "message": "Empty argument"})
                continue

            await ws.send_json({"type": "turn_start", "round": session.current_round})

            # Stream Claude token by token back to client
            full_response = ""
            async with client.messages.stream(
                model="claude-sonnet-4-20250514",
                max_tokens=600,
                system=session.system_prompt(),
                messages=session.messages_with(user_text),
            ) as stream:
                async for chunk in stream.text_stream:
                    full_response += chunk
                    await ws.send_json({"type": "token", "text": chunk})

            session.add_turn(user_text, full_response)

            await ws.send_json({
                "type": "turn_end",
                "round": session.current_round - 1,
                "is_finished": session.is_finished,
            })

    except WebSocketDisconnect:
        pass
    except Exception as e:
        await ws.send_json({"type": "error", "message": str(e)})
