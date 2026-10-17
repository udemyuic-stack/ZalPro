import pytest

from tests.conftest import FakeStorage
from zalpro_api.core.errors import ApiError
from zalpro_api.services import images
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


@pytest.mark.parametrize(
    ("owner", "folder"),
    [(images.food_owner("f1"), "foods"), (images.product_owner("p1"), "products")],
)
@pytest.mark.parametrize(
    ("content_type", "extension"),
    [("image/jpeg", "jpg"), ("image/png", "png"), ("image/webp", "webp")],
)
async def test_catalog_image_key_has_entity_folder_and_extension(
    owner: str, folder: str, content_type: str, extension: str
) -> None:
    upload = await images.create_upload(FakeStorage(), owner, 10, content_type, 60)

    prefix, kind, entity, name = upload.key.split("/")
    stem, suffix = name.split(".")
    assert (prefix, kind, entity) == ("images", folder, owner.split("/")[1])
    assert len(stem) == 32
    assert suffix == extension
    images.ensure_owned(owner, upload.key)


def test_catalog_image_keys_do_not_overlap_between_entities() -> None:
    key = build_key("image", images.food_owner("x")) + ".jpg"

    with pytest.raises(ApiError):
        images.ensure_owned(images.product_owner("x"), key)
    with pytest.raises(ApiError):
        images.ensure_owned("x", key)
