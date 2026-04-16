import json
import uuid
import os
import logging
import asyncio
import anthropic
from dotenv import load_dotenv

# Завантажити змінні з .env файлу
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from debate_manager import DebateSession
from analyzer import analyze_debate_transcript
from prompts import TOPIC_SUGGESTIONS_SYSTEM
from database import (
    init_db, insert_debate, update_progress,
    save_analysis, list_debates, get_debate,
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield

app = FastAPI(title="Debate Arena API", lifespan=lifespan)

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
    await insert_debate(session_id, req.topic, req.user_position, req.total_rounds)
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
    logger.info(f"get_analysis called for session: {session_id}")
    
    # Check if analysis already cached in DB
    try:
        record = await get_debate(session_id)
        if (
            record
            and record.persuasiveness_score is not None
            and record.verdict is not None
            and record.strong_points is not None
            and record.weak_points is not None
            and record.suggested_reading is not None
        ):
            logger.info(f"Returning cached analysis for session {session_id}")
            return {
                "strong_points": record.strong_points,
                "weak_points": record.weak_points,
                "persuasiveness_score": record.persuasiveness_score,
                "verdict": record.verdict,
                "suggested_reading": record.suggested_reading,
                "cached": True,
            }
    except Exception as e:
        logger.warning(f"Error checking cache for session {session_id}: {e}")

    session = sessions.get(session_id)
    if not session:
        logger.error(f"Session not found: {session_id}")
        raise HTTPException(404, "Session not found")
    
    if not session.is_finished:
        logger.warning(f"Debate not finished for session {session_id}. Current round: {session.current_round}/{session.total_rounds}")
        raise HTTPException(400, "Debate not finished yet")

    logger.info(f"Starting analysis for session {session_id}")
    
    # Claude analysis request (moved into backend/analyzer.py).
    try:
        analysis = await analyze_debate_transcript(
            client=client,
            transcript=session.transcript(),
        )
        logger.info(f"Analysis completed successfully for session {session_id}")
    except Exception as e:
        logger.error(f"Analysis failed for session {session_id}: {type(e).__name__}: {str(e)}", exc_info=True)
        raise HTTPException(500, f"Analysis failed: {str(e)}")

    # Persist full analysis to DB (so cached calls return everything UI needs).
    try:
        await save_analysis(
            session_id=session_id,
            score=analysis["persuasiveness_score"],
            verdict=analysis["verdict"],
            strong_points=analysis["strong_points"],
            weak_points=analysis["weak_points"],
            suggested_reading=analysis["suggested_reading"],
            transcript=session.transcript(),
        )
        logger.info(f"Analysis saved to database for session {session_id}")
    except Exception as e:
        logger.error(f"Failed to save analysis for session {session_id}: {e}", exc_info=True)
    return analysis

@app.get("/history")
async def get_history(limit: int = 50):
    records = await list_debates(limit)
    return [
        {
            "session_id": r.session_id,
            "topic": r.topic,
            "user_position": r.user_position,
            "total_rounds": r.total_rounds,
            "completed_rounds": r.completed_rounds,
            "score": r.persuasiveness_score,
            "verdict": r.verdict,
            "created_at": r.created_at,
        }
        for r in records
    ]

@app.get("/history/{session_id}/transcript")
async def get_transcript(session_id: str):
    record = await get_debate(session_id)
    if not record:
        raise HTTPException(404, "Debate not found")
    if not record.transcript:
        raise HTTPException(404, "Transcript not available yet")
    return {"transcript": record.transcript}

@app.get("/topics/suggestions")
async def suggest_topics():
    logger.info("Topic suggestions requested")
    try:
        logger.info("Sending request to Claude API for topic suggestions...")
        response = await asyncio.wait_for(
            client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=400,
                system=TOPIC_SUGGESTIONS_SYSTEM,
                messages=[{"role": "user", "content": "Generate topics"}],
            ),
            timeout=30.0  # 30 second timeout for topics
        )
        topics = json.loads(response.content[0].text.strip())
        logger.info(f"Generated {len(topics)} topics")
        return {"topics": topics}
    except asyncio.TimeoutError:
        logger.error("Topic suggestion request timed out after 30 seconds")
        raise HTTPException(504, "Topic generation timed out. Please try again.")
    except Exception as e:
        logger.error(f"Failed to generate topics: {type(e).__name__}: {str(e)}", exc_info=True)
        raise HTTPException(500, f"Failed to generate topics: {str(e)}")


# ── WebSocket ─────────────────────────────────────────────────────────────────

@app.websocket("/ws/debate/{session_id}")
async def debate_websocket(ws: WebSocket, session_id: str):
    logger.info(f"WebSocket connection attempt for session: {session_id}")
    await ws.accept()

    session = sessions.get(session_id)
    if not session:
        logger.error(f"Session not found: {session_id}")
        await ws.send_json({"type": "error", "message": "Session not found"})
        await ws.close()
        return

    logger.info(f"WebSocket accepted for session {session_id}")
    
    try:
        while True:
            data = json.loads(await ws.receive_text())

            if data.get("type") != "argument":
                logger.warning(f"Unknown message type: {data.get('type')}")
                await ws.send_json({"type": "error", "message": "Unknown message type"})
                continue

            if session.is_finished:
                logger.warning(f"Debate already finished for session {session_id}")
                await ws.send_json({"type": "error", "message": "Debate already finished"})
                continue

            user_text: str = data.get("text", "").strip()
            if not user_text:
                logger.warning(f"Empty argument received for session {session_id}")
                await ws.send_json({"type": "error", "message": "Empty argument"})
                continue

            logger.info(f"Processing round {session.current_round} for session {session_id}")
            await ws.send_json({"type": "turn_start", "round": session.current_round})

            # Stream Claude token by token back to client
            full_response = ""
            try:
                logger.info("Starting Claude streaming for debate response...")
                
                async def stream_response():
                    response_text = ""
                    async with client.messages.stream(
                        model="claude-sonnet-4-20250514",
                        max_tokens=600,
                        system=session.system_prompt(),
                        messages=session.messages_with(user_text),
                    ) as stream:
                        async for chunk in stream.text_stream:
                            response_text += chunk
                            await ws.send_json({"type": "token", "text": chunk})
                    return response_text
                
                full_response = await asyncio.wait_for(stream_response(), timeout=120.0)
                logger.info(f"Claude response received, length: {len(full_response)}")
            except asyncio.TimeoutError:
                logger.error(f"Claude streaming timeout for session {session_id}")
                await ws.send_json({"type": "error", "message": "Response generation timed out"})
                continue
            except Exception as e:
                logger.error(f"Claude streaming failed for session {session_id}: {type(e).__name__}: {str(e)}", exc_info=True)
                await ws.send_json({"type": "error", "message": f"Claude API error: {str(e)}"})
                continue

            session.add_turn(user_text, full_response)
            await update_progress(session_id, len(session.turns))

            await ws.send_json({
                "type": "turn_end",
                "round": session.current_round - 1,
                "is_finished": session.is_finished,
            })

    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected for session {session_id}")
    except Exception as e:
        logger.error(f"WebSocket error for session {session_id}: {type(e).__name__}: {str(e)}", exc_info=True)
        await ws.send_json({"type": "error", "message": str(e)})
