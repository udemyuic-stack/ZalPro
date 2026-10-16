import base64
import json
import os
import time
from collections.abc import Callable, Iterator
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import httpx

from scripts.migrate_firestore.firestore_values import document_id

PROJECT = "kotta-qani-09111753"
PAGE_SIZE = 300
TOP_LEVEL = (
    "users",
    "trainers",
    "ratings",
    "gyms",
    "foods",
    "plans",
    "shop",
    "orders",
    "reminders",
    "exercises",
    "memberships",
)
USER_SUBCOLLECTIONS = ("weights", "days", "subscriptions", "attendance", "photos")
CHAT_COLLECTION = "chatMessages"
RETRY_STATUSES = frozenset({429, 500, 502, 503, 504})
MAX_ATTEMPTS = 6
TOKEN_MARGIN_SECONDS = 120

SIGN_IN_URL = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
REFRESH_URL = "https://securetoken.googleapis.com/v1/token"
FIRESTORE_URL = "https://firestore.googleapis.com/v1"


class ExtractError(Exception):
    pass


@dataclass
class Session:
    api_key: str
    id_token: str
    refresh_token: str
    expires_at: float


@dataclass
class Manifest:
    project: str
    exported_at: str
    counts: dict[str, int] = field(default_factory=dict)
    photo_bytes: int = 0
    pages: int = 0

    def to_json(self) -> dict[str, Any]:
        return {
            "project": self.project,
            "exported_at": self.exported_at,
            "counts": self.counts,
            "photo_bytes": self.photo_bytes,
            "pages": self.pages,
        }


class FirestoreReader:
    def __init__(
        self,
        client: httpx.Client,
        session: Session,
        project: str = PROJECT,
        clock: Callable[[], float] = time.time,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self._client = client
        self._session = session
        self._project = project
        self._clock = clock
        self._sleep = sleep
        self.pages = 0

    @classmethod
    def sign_in(
        cls,
        client: httpx.Client,
        api_key: str,
        email: str,
        password: str,
        project: str = PROJECT,
        clock: Callable[[], float] = time.time,
        sleep: Callable[[float], None] = time.sleep,
    ) -> "FirestoreReader":
        response = client.post(
            SIGN_IN_URL,
            params={"key": api_key},
            json={"email": email, "password": password, "returnSecureToken": True},
        )
        if response.status_code != 200:
            raise ExtractError(f"sign-in failed: HTTP {response.status_code}")
        body = response.json()
        session = Session(
            api_key=api_key,
            id_token=body["idToken"],
            refresh_token=body["refreshToken"],
            expires_at=clock() + int(body.get("expiresIn", "3600")),
        )
        return cls(client, session, project, clock, sleep)

    def _refresh(self) -> None:
        response = self._client.post(
            REFRESH_URL,
            params={"key": self._session.api_key},
            data={"grant_type": "refresh_token", "refresh_token": self._session.refresh_token},
        )
        if response.status_code != 200:
            raise ExtractError(f"token refresh failed: HTTP {response.status_code}")
        body = response.json()
        self._session.id_token = body["id_token"]
        self._session.refresh_token = body.get("refresh_token", self._session.refresh_token)
        self._session.expires_at = self._clock() + int(body.get("expires_in", "3600"))

    def _get(self, path: str, params: dict[str, Any]) -> dict[str, Any]:
        url = f"{FIRESTORE_URL}/projects/{self._project}/databases/(default)/documents/{path}"
        refreshed = False
        for attempt in range(MAX_ATTEMPTS):
            if self._clock() >= self._session.expires_at - TOKEN_MARGIN_SECONDS:
                self._refresh()
            try:
                response = self._client.get(
                    url,
                    params=params,
                    headers={"Authorization": f"Bearer {self._session.id_token}"},
                )
            except httpx.TransportError:
                self._sleep(min(2**attempt, 30))
                continue
            if response.status_code == 200:
                self.pages += 1
                return response.json()
            if response.status_code == 401 and not refreshed:
                refreshed = True
                self._refresh()
                continue
            if response.status_code in RETRY_STATUSES:
                self._sleep(min(2**attempt, 30))
                continue
            raise ExtractError(f"GET {path} failed: HTTP {response.status_code}")
        raise ExtractError(f"GET {path} failed after {MAX_ATTEMPTS} attempts")

    def documents(self, path: str) -> Iterator[dict[str, Any]]:
        token: str | None = None
        while True:
            params: dict[str, Any] = {"pageSize": PAGE_SIZE}
            if token is not None:
                params["pageToken"] = token
            body = self._get(path, params)
            yield from body.get("documents", [])
            token = body.get("nextPageToken") or None
            if token is None:
                return


class JsonlWriter:
    def __init__(self, directory: Path, name: str) -> None:
        self._final = directory / f"{name}.jsonl"
        self._part = directory / f"{name}.jsonl.part"
        fd = os.open(self._part, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        self._handle = os.fdopen(fd, "w", encoding="utf-8")
        self.count = 0

    def write(self, parent: str | None, document: dict[str, Any]) -> None:
        self._handle.write(json.dumps({"parent": parent, "doc": document}, ensure_ascii=False))
        self._handle.write("\n")
        self.count += 1

    def commit(self) -> None:
        self._handle.close()
        os.replace(self._part, self._final)

    def abandon(self) -> None:
        self._handle.close()


def prepare_directory(directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    directory.chmod(0o700)
    (directory / "photos").mkdir(exist_ok=True)
    (directory / "photos").chmod(0o700)


def split_photo(directory: Path, uid: str, document: dict[str, Any]) -> tuple[dict[str, Any], int]:
    fields = dict(document.get("fields", {}))
    data = fields.pop("data", None)
    size = 0
    raw = None
    if data is not None and "bytesValue" in data:
        try:
            raw = base64.b64decode(data["bytesValue"], validate=True)
        except (ValueError, TypeError):
            raw = None
    if raw:
        size = len(raw)
        user_dir = directory / "photos" / uid
        user_dir.mkdir(exist_ok=True)
        user_dir.chmod(0o700)
        target = user_dir / f"{document_id(document['name'])}.bin"
        fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "wb") as handle:
            handle.write(raw)
    stripped = {**document, "fields": fields}
    stripped["photoBytes"] = size
    return stripped, size


def extract_all(reader: FirestoreReader, directory: Path, exported_at: str) -> Manifest:
    prepare_directory(directory)
    manifest = Manifest(project=PROJECT, exported_at=exported_at)
    user_ids: list[str] = []

    for name in TOP_LEVEL:
        writer = JsonlWriter(directory, name)
        try:
            for document in reader.documents(name):
                writer.write(None, document)
                if name == "users":
                    user_ids.append(document_id(document["name"]))
        except BaseException:
            writer.abandon()
            raise
        writer.commit()
        manifest.counts[name] = writer.count

    writers = {
        kind: JsonlWriter(directory, kind) for kind in (*USER_SUBCOLLECTIONS, CHAT_COLLECTION)
    }
    try:
        for uid in user_ids:
            for kind in USER_SUBCOLLECTIONS:
                for document in reader.documents(f"users/{uid}/{kind}"):
                    if kind == "photos":
                        document, size = split_photo(directory, uid, document)
                        manifest.photo_bytes += size
                    writers[kind].write(uid, document)
            for document in reader.documents(f"chats/{uid}/messages"):
                writers[CHAT_COLLECTION].write(uid, document)
    except BaseException:
        for writer in writers.values():
            writer.abandon()
        raise
    for kind, writer in writers.items():
        writer.commit()
        manifest.counts[kind] = writer.count

    manifest.pages = reader.pages
    manifest_path = directory / "manifest.json"
    manifest_part = directory / "manifest.json.part"
    fd = os.open(manifest_part, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(manifest.to_json(), handle, indent=1)
    manifest_part.replace(manifest_path)
    return manifest


def read_jsonl(directory: Path, name: str) -> Iterator[tuple[str | None, dict[str, Any]]]:
    with open(directory / f"{name}.jsonl", encoding="utf-8") as handle:
        for line in handle:
            record = json.loads(line)
            yield record["parent"], record["doc"]
