"""Test fixtures."""

from __future__ import annotations

import keyring
import keyring.errors
import pytest
from keyring.backend import KeyringBackend


class _InMemoryKeyring(KeyringBackend):
    """Headless-safe backend for CI and dev containers."""

    priority = 1

    def __init__(self) -> None:
        self._data: dict[tuple[str, str], str] = {}

    def get_password(self, service: str, username: str) -> str | None:
        return self._data.get((service, username))

    def set_password(self, service: str, username: str, password: str) -> None:
        self._data[(service, username)] = password

    def delete_password(self, service: str, username: str) -> None:
        try:
            del self._data[(service, username)]
        except KeyError as e:
            raise keyring.errors.PasswordDeleteError("not found") from e


@pytest.fixture(autouse=True)
def _use_in_memory_keyring() -> None:
    keyring.set_keyring(_InMemoryKeyring())
