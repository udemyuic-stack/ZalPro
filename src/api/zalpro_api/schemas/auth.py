from zalpro_api.schemas.base import Name, Password, PhoneNumber, StrictModel


class RegisterRequest(StrictModel):
    name: Name
    phone: PhoneNumber
    password: Password


class LoginRequest(StrictModel):
    phone: PhoneNumber
    password: str


class RefreshRequest(StrictModel):
    refresh_token: str


class ChangePasswordRequest(StrictModel):
    current_password: str
    new_password: Password


class TokenPair(StrictModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
