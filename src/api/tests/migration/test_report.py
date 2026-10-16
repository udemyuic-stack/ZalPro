import json
import stat

from scripts.migrate_firestore.report import Findings, write_json


def test_counts_group_by_reason_prefix():
    findings = Findings()
    findings.reject("users", "a", "duplicate_phone:kept=b")
    findings.reject("users", "c", "duplicate_phone:kept=d")
    findings.reject("orders", "o", "qty_out_of_range:99")
    findings.note("users", "a", "gym_nulled")
    assert findings.reject_counts() == {
        "orders": {"qty_out_of_range": 1},
        "users": {"duplicate_phone": 2},
    }
    assert findings.note_counts() == {"users": {"gym_nulled": 1}}


def test_json_lists_every_entry():
    findings = Findings()
    findings.reject("users", "a", "phone_invalid")
    payload = findings.to_json()
    assert payload["rejects"] == [{"table": "users", "id": "a", "reason": "phone_invalid"}]
    assert payload["notes"] == []


def test_write_json_is_private(tmp_path):
    path = tmp_path / "report.json"
    write_json(path, {"ok": True})
    assert json.loads(path.read_text()) == {"ok": True}
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
