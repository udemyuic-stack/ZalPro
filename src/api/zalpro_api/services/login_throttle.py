import time
from collections import defaultdict, deque
from collections.abc import Callable
from math import ceil

from zalpro_api.core.errors import ApiError


class LoginThrottle:
    def __init__(
        self,
        max_attempts: int,
        window_seconds: int,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._max_attempts = max_attempts
        self._window_seconds = window_seconds
        self._clock = clock
        self._failures: dict[str, deque[float]] = defaultdict(deque)

    def _prune(self, key: str) -> deque[float]:
        failures = self._failures[key]
        cutoff = self._clock() - self._window_seconds
        while failures and failures[0] <= cutoff:
            failures.popleft()
        if not failures:
            self._failures.pop(key, None)
        return failures

    def ensure_allowed(self, key: str) -> None:
        failures = self._prune(key)
        if len(failures) < self._max_attempts:
            return
        retry_after = max(1, ceil(failures[0] + self._window_seconds - self._clock()))
        raise ApiError(
            429,
            "too_many_attempts",
            "Juda ko'p urinish. Keyinroq qayta urinib ko'ring",
            headers={"Retry-After": str(retry_after)},
        )

    def record_failure(self, key: str) -> None:
        self._prune(key)
        self._failures[key].append(self._clock())

    def clear(self, key: str) -> None:
        self._failures.pop(key, None)

    def reset(self) -> None:
        self._failures.clear()


def throttle_key(phone: str, client_host: str | None) -> str:
    return f"{phone}|{client_host or 'unknown'}"
