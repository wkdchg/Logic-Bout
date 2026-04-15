import json
import aiosqlite
from dataclasses import dataclass
from typing import Optional

DB_PATH = "debate_arena.db"


@dataclass
class DebateRecord:
    session_id: str
    topic: str
    user_position: str
    total_rounds: int
    completed_rounds: int
    persuasiveness_score: Optional[int]
    verdict: Optional[str]
    transcript: Optional[str]
    created_at: str


async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS debates (
                session_id       TEXT PRIMARY KEY,
                topic            TEXT NOT NULL,
                user_position    TEXT NOT NULL,
                total_rounds     INTEGER NOT NULL,
                completed_rounds INTEGER NOT NULL DEFAULT 0,
                score            INTEGER,
                verdict          TEXT,
                transcript       TEXT,
                created_at       TEXT NOT NULL DEFAULT (datetime('now'))
            )
        """)
        await db.commit()


async def insert_debate(session_id: str, topic: str, user_position: str, total_rounds: int):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            """INSERT INTO debates (session_id, topic, user_position, total_rounds)
               VALUES (?, ?, ?, ?)""",
            (session_id, topic, user_position, total_rounds),
        )
        await db.commit()


async def update_progress(session_id: str, completed_rounds: int):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "UPDATE debates SET completed_rounds = ? WHERE session_id = ?",
            (completed_rounds, session_id),
        )
        await db.commit()


async def save_analysis(session_id: str, score: int, verdict: str, transcript: str):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            """UPDATE debates
               SET score = ?, verdict = ?, transcript = ?
               WHERE session_id = ?""",
            (score, verdict, transcript, session_id),
        )
        await db.commit()


async def list_debates(limit: int = 50) -> list[DebateRecord]:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            """SELECT * FROM debates ORDER BY created_at DESC LIMIT ?""",
            (limit,),
        ) as cursor:
            rows = await cursor.fetchall()
    return [
        DebateRecord(
            session_id=r["session_id"],
            topic=r["topic"],
            user_position=r["user_position"],
            total_rounds=r["total_rounds"],
            completed_rounds=r["completed_rounds"],
            persuasiveness_score=r["score"],
            verdict=r["verdict"],
            transcript=r["transcript"],
            created_at=r["created_at"],
        )
        for r in rows
    ]


async def get_debate(session_id: str) -> Optional[DebateRecord]:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            "SELECT * FROM debates WHERE session_id = ?", (session_id,)
        ) as cursor:
            row = await cursor.fetchone()
    if not row:
        return None
    return DebateRecord(
        session_id=row["session_id"],
        topic=row["topic"],
        user_position=row["user_position"],
        total_rounds=row["total_rounds"],
        completed_rounds=row["completed_rounds"],
        persuasiveness_score=row["score"],
        verdict=row["verdict"],
        transcript=row["transcript"],
        created_at=row["created_at"],
    )
