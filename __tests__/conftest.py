"""
Shared fixtures for Kairos API integration tests.

The backend must be running on BASE_URL before executing the suite:
    cd backend && dotnet run --project src/Kairos.API

Seed credentials (created by DevDataSeeder on first startup, all with the same password):
    kairos_user1@kairos.cl  /  Kairos2026!   (student)
    staff1@kairos.cl        /  Kairos2026!   (staff)
    empresa@kairos.cl       /  Kairos2026!   (company)
"""

import pytest
import requests

BASE_URL = "http://localhost:5001"

SEED_EMAIL    = "kairos_user1@kairos.cl"
SEED_PASSWORD = "Kairos2026!"


def _is_backend_up() -> bool:
    """Return True if the backend answers on BASE_URL."""
    try:
        requests.get(f"{BASE_URL}/swagger/index.html", timeout=3)
        return True
    except requests.exceptions.ConnectionError:
        return False


# ── Skip marker ───────────────────────────────────────────────────────────────
backend_required = pytest.mark.skipif(
    not _is_backend_up(),
    reason="Backend not running on http://localhost:5001 — start it first.",
)


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture(scope="session")
def base_url() -> str:
    return BASE_URL


@pytest.fixture(scope="session")
def session() -> requests.Session:
    """A plain requests.Session (no auth)."""
    s = requests.Session()
    s.headers.update({"Content-Type": "application/json"})
    return s


@pytest.fixture(scope="session")
def auth_token(session, base_url) -> str:
    """
    Log in with the seeded student account and return the JWT.
    All authenticated tests depend on this fixture.
    """
    resp = session.post(
        f"{base_url}/api/auth/login",
        json={"email": SEED_EMAIL, "password": SEED_PASSWORD},
    )
    assert resp.status_code == 200, (
        f"Login failed ({resp.status_code}): {resp.text}\n"
        "Make sure the backend is running and the DB has been seeded."
    )
    token = resp.json()["token"]
    assert token, "JWT token must not be empty"
    return token


@pytest.fixture(scope="session")
def auth_session(session, auth_token) -> requests.Session:
    """A requests.Session pre-configured with the Bearer JWT."""
    s = requests.Session()
    s.headers.update({
        "Content-Type": "application/json",
        "Authorization": f"Bearer {auth_token}",
    })
    return s
