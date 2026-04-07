# Debate Arena — Backend (Week 1)

FastAPI backend with WebSocket streaming + Claude API.

## Quickstart

```bash
cd backend
python -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt

export ANTHROPIC_API_KEY=sk-ant-...               # Windows: set ANTHROPIC_API_KEY=...
uvicorn main:app --reload
```

Server runs at **http://localhost:8000**  
Swagger docs at **http://localhost:8000/docs**

## Test without Flutter

```bash
pip install websockets httpx   # extra deps for test script
python test_debate.py
```

## API

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/debate/start` | Create a new session |
| GET | `/debate/{id}/status` | Round counter + finished flag |
| GET | `/debate/{id}/analysis` | Post-debate JSON analysis (only when finished) |
| GET | `/topics/suggestions` | AI-generated topic list |
| WS | `/ws/debate/{id}` | Realtime debate stream |

## WebSocket message protocol

**Client → Server**
```json
{ "type": "argument", "text": "Your argument here" }
```

**Server → Client**
```json
{ "type": "turn_start", "round": 1 }
{ "type": "token",      "text": "chunk" }      ← repeats until done
{ "type": "turn_end",   "round": 1, "is_finished": false }
{ "type": "error",      "message": "..." }
```

## File structure

```
backend/
├── main.py           # FastAPI app, WebSocket handler, REST endpoints
├── debate_manager.py # DebateSession dataclass, message history builder
├── prompts.py        # All system prompts (debate, analysis, topic suggestions)
├── requirements.txt
└── test_debate.py    # Terminal test — no Flutter needed
```
