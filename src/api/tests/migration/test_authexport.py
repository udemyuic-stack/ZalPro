import json
from datetime import UTC, datetime

import pytest

from scripts.migrate_firestore.authexport import AuthExportError, detect_algo, load_auth_export


def write(tmp_path, payload):
    path = tmp_path / "auth.json"
    path.write_text(json.dumps(payload))
    return path


def test_loads_scrypt_and_bcrypt_and_empty(tmp_path):
    path = write(
        tmp_path,
        {
            "users": [
                {
                    "localId": "u1",
                    "email": "998901112233@phone.kottaqani.uz",
                    "passwordHash": "aGFzaA==",
                    "salt": "c2FsdA==",
                    "createdAt": "1700000000000",
                    "disabled": False,
                },
                {
                    "localId": "u2",
                    "email": "998901112244@phone.kottaqani.uz",
                    "passwordHash": "$2b$10$abcdefghijklmnopqrstuv",
                },
                {"localId": "u3", "email": "x@phone.kottaqani.uz", "disabled": True},
            ]
        },
    )
    records = load_auth_export(path)
    assert records["u1"].algo == "scrypt"
    assert records["u1"].salt == "c2FsdA=="
    assert records["u1"].created_at == datetime(2023, 11, 14, 22, 13, 20, tzinfo=UTC)
    assert records["u2"].algo == "bcrypt"
    assert records["u2"].salt is None
    assert records["u3"].algo is None
    assert records["u3"].password_hash is None
    assert records["u3"].disabled is True


def test_detect_algo_edges():
    assert detect_algo(None, "s") is None
    assert detect_algo("", None) is None
    assert detect_algo("aGFzaA==", None) is None
    assert detect_algo("$2y$12$xxxxxxxx", None) == "bcrypt"


def test_bad_created_at_is_ignored(tmp_path):
    path = write(tmp_path, {"users": [{"localId": "u1", "createdAt": "not-a-number"}]})
    assert load_auth_export(path)["u1"].created_at is None


def test_missing_file_message_has_no_path_contents(tmp_path):
    with pytest.raises(AuthExportError):
        load_auth_export(tmp_path / "missing.json")


def test_invalid_structure(tmp_path):
    with pytest.raises(AuthExportError):
        load_auth_export(write(tmp_path, {"foo": []}))
    with pytest.raises(AuthExportError):
        load_auth_export(write(tmp_path, {"users": [{"email": "x"}]}))
