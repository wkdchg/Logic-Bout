# Debate Arena

A mobile app where you argue any topic against an AI opponent that always takes the opposite side — then get a detailed analysis of your performance.

Built with **Flutter** (mobile) + **Python/FastAPI** (backend) + **Claude API** (AI).

---

## Architecture

```
Flutter App  ──WS stream──▶  FastAPI  ──HTTP──▶  Claude API
                 ◀──tokens──          ◀──stream──
                   REST ▲
                        │
                    SQLite DB
```

**Key technical highlights:**
- **Realtime WebSocket streaming** — each Claude token is forwarded to Flutter immediately, no buffering
- **Prompt engineering** — three separate system prompts: debate opponent, post-debate judge, topic generator
- **Async Python** — `aiosqlite` for non-blocking DB writes during live debate
- **Analysis caching** — finished debates store score + verdict in SQLite, no redundant API calls

---

## Stack

| Layer | Tech |
|-------|------|
| Mobile | Flutter 3.x, Dart 3.x |
| Backend | Python 3.12, FastAPI, uvicorn |
| AI | Anthropic Claude API (claude-sonnet-4) |
| Database | SQLite via aiosqlite |
| Transport | WebSockets + REST |

---

## Project structure

```
debate_arena/
├── backend/
│   ├── main.py            # FastAPI app — WebSocket handler + REST endpoints
│   ├── debate_manager.py  # DebateSession state, message history builder
│   ├── prompts.py         # All system prompts (debate, analysis, suggestions)
│   ├── database.py        # SQLite layer — init, insert, update, query
│   └── requirements.txt
└── flutter_app/
    ├── lib/
    │   ├── main.dart
    │   ├── services/
    │   │   ├── websocket_service.dart   # WS connect, send, stream
    │   │   └── api_service.dart         # REST calls
    │   ├── screens/
    │   │   ├── setup_screen.dart        # Topic picker with AI suggestions
    │   │   ├── debate_screen.dart       # Live chat with streaming bubbles
    │   │   ├── analysis_screen.dart     # Score + strong/weak points
    │   │   ├── history_screen.dart      # Past debates list
    │   │   └── transcript_screen.dart   # Full debate replay
    │   └── widgets/
    │       └── chat_bubble.dart         # Typing indicator + blink cursor
    └── pubspec.yaml
```

---

## Running locally

### Backend

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt

export ANTHROPIC_API_KEY=sk-ant-...
uvicorn main:app --reload
```

Server → `http://localhost:8000`  
Swagger UI → `http://localhost:8000/docs`

### Flutter

```bash
cd flutter_app
flutter pub get
flutter run
```

Make sure the backend is running first.

### Test without Flutter

```bash
pip install websockets httpx
python backend/test_debate.py
```

---

## WebSocket protocol

**Client → Server**
```json
{ "type": "argument", "text": "Your argument here" }
```

**Server → Client**
```json
{ "type": "turn_start", "round": 1 }
{ "type": "token",      "text": "..." }
{ "type": "turn_end",   "round": 1, "is_finished": false }
```

---

## REST endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/debate/start` | Create session |
| `GET` | `/debate/{id}/status` | Round counter |
| `GET` | `/debate/{id}/analysis` | Post-debate JSON analysis |
| `GET` | `/history` | All past debates |
| `GET` | `/history/{id}/transcript` | Full debate text |
| `GET` | `/topics/suggestions` | AI-generated topic list |

---

## Roadmap

- [ ] Multi-language support
- [ ] Leaderboard (persuasiveness scores across topics)
- [ ] Voice input via speech-to-text
- [ ] Share debate transcript as image
