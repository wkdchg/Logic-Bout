# backend/main.py
@app.websocket("/ws/debate/{session_id}")
async def debate_ws(ws: WebSocket, session_id: str):
    await ws.accept()
    session = DebateSession(session_id)

    async for message in ws.iter_text():
        data = json.loads(message)

        if data["type"] == "argument":
            # стрімимо відповідь Claude назад
            async with anthropic.messages.stream(
                model="claude-sonnet-4-20250514",
                max_tokens=600,
                system=session.system_prompt(),
                messages=session.history_with(data["text"])
            ) as stream:
                async for chunk in stream.text_stream:
                    await ws.send_json({"type": "token", "text": chunk})

            await ws.send_json({"type": "turn_end"})
            session.add_turn(data["text"], stream.get_final_message())