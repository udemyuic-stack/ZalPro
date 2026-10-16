import pytest

from zalpro_api.services.storage import build_key


@pytest.mark.parametrize(("kind", "folder"), [("image", "images"), ("video", "videos")])
def test_build_key_uses_separate_folder_per_media_kind(kind: str, folder: str) -> None:
    key = build_key(kind, "user1")

    prefix, owner, name = key.split("/")
    assert prefix == folder
    assert owner == "user1"
    assert len(name) == 32


def test_build_key_is_unique() -> None:
    assert build_key("image", "user1") != build_key("image", "user1")
