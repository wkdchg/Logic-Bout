import json
import aiosqlite
from dataclasses import dataclass
from typing import Optional

DB_PATH = "logic_bout.db"


@dataclass
class DebateRecord:
    session_id: str
    topic: str
    user_position: str
    total_rounds: int
    completed_rounds: int
    persuasiveness_score: Optional[int]
    verdict: Optional[str]
    strong_points: Optional[list[str]]
    weak_points: Optional[list[str]]
    suggested_reading: Optional[str]
    transcript: Optional[str]
    created_at: str


async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        await db.execute("""
            CREATE TABLE IF NOT EXISTS debates (
                session_id       TEXT PRIMARY KEY,
                topic            TEXT NOT NULL,
                user_position    TEXT NOT NULL,
                total_rounds     INTEGER NOT NULL,
                completed_rounds INTEGER NOT NULL DEFAULT 0,
                score            INTEGER,
                verdict          TEXT,
                strong_points   TEXT,
                weak_points     TEXT,
                suggested_reading TEXT,
                transcript       TEXT,
                created_at       TEXT NOT NULL DEFAULT (datetime('now'))
            )
        """)
        # Backward-compatible schema migration for existing DBs.
        async with db.execute("PRAGMA table_info(debates)") as cursor:
            rows = await cursor.fetchall()
        existing_cols = {r["name"] for r in rows}

        required_cols: dict[str, str] = {
            "strong_points": "TEXT",
            "weak_points": "TEXT",
            "suggested_reading": "TEXT",
        }
        for col_name, col_def in required_cols.items():
            if col_name not in existing_cols:
                await db.execute(
                    f"ALTER TABLE debates ADD COLUMN {col_name} {col_def}"
                )

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


async def save_analysis(
    session_id: str,
    *,
    score: int,
    verdict: str,
    strong_points: list[str],
    weak_points: list[str],
    suggested_reading: str,
    transcript: str,
):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            """UPDATE debates
               SET score = ?,
                   verdict = ?,
                   strong_points = ?,
                   weak_points = ?,
                   suggested_reading = ?,
                   transcript = ?
               WHERE session_id = ?""",
            (
                score,
                verdict,
                json.dumps(strong_points),
                json.dumps(weak_points),
                suggested_reading,
                transcript,
                session_id,
            ),
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
            strong_points=json.loads(r["strong_points"]) if r["strong_points"] else None,
            weak_points=json.loads(r["weak_points"]) if r["weak_points"] else None,
            suggested_reading=r["suggested_reading"],
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
        strong_points=json.loads(row["strong_points"]) if row["strong_points"] else None,
        weak_points=json.loads(row["weak_points"]) if row["weak_points"] else None,
        suggested_reading=row["suggested_reading"],
        transcript=row["transcript"],
        created_at=row["created_at"],
    )
