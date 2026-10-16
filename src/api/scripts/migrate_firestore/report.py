import json
import os
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class Reject:
    table: str
    id: str
    reason: str


@dataclass(frozen=True)
class Note:
    table: str
    id: str
    note: str


@dataclass
class Findings:
    rejects: list[Reject] = field(default_factory=list)
    notes: list[Note] = field(default_factory=list)

    def reject(self, table: str, row_id: str, reason: str) -> None:
        self.rejects.append(Reject(table, row_id, reason))

    def note(self, table: str, row_id: str, note: str) -> None:
        self.notes.append(Note(table, row_id, note))

    def reject_counts(self) -> dict[str, dict[str, int]]:
        grouped: dict[str, Counter[str]] = {}
        for item in self.rejects:
            grouped.setdefault(item.table, Counter())[item.reason.split(":", 1)[0]] += 1
        return {table: dict(counter) for table, counter in sorted(grouped.items())}

    def note_counts(self) -> dict[str, dict[str, int]]:
        grouped: dict[str, Counter[str]] = {}
        for item in self.notes:
            grouped.setdefault(item.table, Counter())[item.note.split(":", 1)[0]] += 1
        return {table: dict(counter) for table, counter in sorted(grouped.items())}

    def to_json(self) -> dict[str, Any]:
        return {
            "reject_counts": self.reject_counts(),
            "note_counts": self.note_counts(),
            "rejects": [vars(item) for item in self.rejects],
            "notes": [vars(item) for item in self.notes],
        }


def write_json(path: Path, payload: dict[str, Any]) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=1, ensure_ascii=False, default=str)
