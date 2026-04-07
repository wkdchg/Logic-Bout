from dataclasses import dataclass, field
from typing import Optional
from prompts import DEBATE_SYSTEM, ANALYSIS_SYSTEM


@dataclass
class Turn:
    user_argument: str
    ai_response: str
    round_number: int


@dataclass
class DebateSession:
    session_id: str
    topic: str
    user_position: str
    total_rounds: int = 5
    turns: list[Turn] = field(default_factory=list)

    @property
    def current_round(self) -> int:
        return len(self.turns) + 1

    @property
    def is_finished(self) -> bool:
        return len(self.turns) >= self.total_rounds

    def system_prompt(self) -> str:
        return DEBATE_SYSTEM.format(
            topic=self.topic,
            user_position=self.user_position,
            round_number=self.current_round,
            total_rounds=self.total_rounds,
        )

    def messages_with(self, user_text: str) -> list[dict]:
        """Build full message history for Claude, including current argument."""
        messages = []
        for turn in self.turns:
            messages.append({"role": "user", "content": turn.user_argument})
            messages.append({"role": "assistant", "content": turn.ai_response})
        messages.append({"role": "user", "content": user_text})
        return messages

    def add_turn(self, user_argument: str, ai_response: str) -> None:
        self.turns.append(
            Turn(
                user_argument=user_argument,
                ai_response=ai_response,
                round_number=self.current_round - 1,
            )
        )

    def transcript(self) -> str:
        """Format full debate as readable text for analysis prompt."""
        lines = [f"Topic: {self.topic}", f"User's position: {self.user_position}", ""]
        for turn in self.turns:
            lines.append(f"[Round {turn.round_number}]")
            lines.append(f"User: {turn.user_argument}")
            lines.append(f"AI opponent: {turn.ai_response}")
            lines.append("")
        return "\n".join(lines)

    def analysis_messages(self) -> list[dict]:
        return [{"role": "user", "content": self.transcript()}]
