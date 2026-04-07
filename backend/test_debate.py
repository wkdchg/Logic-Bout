#!/usr/bin/env python3
"""
Quick terminal test for Debate Arena backend.
Run AFTER starting the server:  uvicorn main:app --reload

Usage:
  python test_debate.py
"""
import asyncio
import json
import httpx
import websockets

BASE = "http://localhost:8000"
WS_BASE = "ws://localhost:8000"


async def run():
    async with httpx.AsyncClient() as http:

        # 1. Get topic suggestions
        print("── Topic suggestions ─────────────────────")
        r = await http.get(f"{BASE}/topics/suggestions")
        topics = r.json()["topics"]
        for i, t in enumerate(topics, 1):
            print(f"  {i}. {t}")

        # 2. Start a debate session
        topic = topics[0]
        position = "yes, strongly in favour"
        print(f"\n── Starting debate ───────────────────────")
        print(f"  Topic:    {topic}")
        print(f"  Position: {position}")

        r = await http.post(f"{BASE}/debate/start", json={
            "topic": topic,
            "user_position": position,
            "total_rounds": 3,
        })
        session = r.json()
        sid = session["session_id"]
        print(f"  Session:  {sid}")

    # 3. Connect via WebSocket and play 3 rounds
    uri = f"{WS_BASE}/ws/debate/{sid}"
    arguments = [
        "This is clearly the right approach because it benefits the majority of people.",
        "History shows this has worked well in many countries already.",
        "The data supports this position — studies consistently show positive outcomes.",
    ]

    print(f"\n── WebSocket debate (3 rounds) ───────────")
    async with websockets.connect(uri) as ws:
        for i, arg in enumerate(arguments, 1):
            print(f"\n  [Round {i}] You: {arg}")
            await ws.send(json.dumps({"type": "argument", "text": arg}))

            ai_response = ""
            while True:
                msg = json.loads(await ws.recv())
                if msg["type"] == "token":
                    print(msg["text"], end="", flush=True)
                    ai_response += msg["text"]
                elif msg["type"] == "turn_end":
                    print()  # newline after stream
                    if msg["is_finished"]:
                        print("\n  Debate finished!")
                    break
                elif msg["type"] == "error":
                    print(f"\n  ERROR: {msg['message']}")
                    break

    # 4. Fetch analysis
    print("\n── Post-debate analysis ──────────────────")
    async with httpx.AsyncClient() as http:
        r = await http.get(f"{BASE}/debate/{sid}/analysis", timeout=30)
        analysis = r.json()

    print(f"  Score:   {analysis['persuasiveness_score']}/10")
    print(f"  Verdict: {analysis['verdict']}")
    print(f"\n  Strong points:")
    for p in analysis["strong_points"]:
        print(f"    + {p}")
    print(f"\n  Weak points:")
    for p in analysis["weak_points"]:
        print(f"    - {p}")
    print(f"\n  Reading: {analysis['suggested_reading']}")


if __name__ == "__main__":
    asyncio.run(run())
