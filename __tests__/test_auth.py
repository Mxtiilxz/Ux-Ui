"""
Tests for POST /api/auth/login  and  POST /api/auth/register
"""

import uuid
import pytest
import requests

from conftest import backend_required, BASE_URL


# ── /api/auth/login ────────────────────────────────────────────────────────────

@backend_required
class TestLogin:

    def test_login_valid_credentials_returns_200_with_token(self, session, base_url):
        resp = session.post(
            f"{base_url}/api/auth/login",
            json={"email": "kairos_user1@kairos.cl", "password": "Kairos2026!"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert "token" in body and body["token"]
        assert "fullName" in body
        assert "role" in body

    def test_login_wrong_password_returns_401(self, session, base_url):
        resp = session.post(
            f"{base_url}/api/auth/login",
            json={"email": "kairos_user1@kairos.cl", "password": "wrong_password"},
        )
        assert resp.status_code == 401

    def test_login_unknown_email_returns_401(self, session, base_url):
        resp = session.post(
            f"{base_url}/api/auth/login",
            json={"email": "nobody@kairos.cl", "password": "Kairos2026!"},
        )
        assert resp.status_code == 401

    def test_login_missing_email_returns_400(self, session, base_url):
        resp = session.post(
            f"{base_url}/api/auth/login",
            json={"password": "Kairos2026!"},
        )
        assert resp.status_code == 400

    def test_login_missing_password_returns_400(self, session, base_url):
        resp = session.post(
            f"{base_url}/api/auth/login",
            json={"email": "kairos_user1@kairos.cl"},
        )
        assert resp.status_code == 400

    def test_login_empty_body_returns_400(self, session, base_url):
        resp = session.post(f"{base_url}/api/auth/login", json={})
        assert resp.status_code == 400

    def test_login_returns_correct_role_for_student(self, session, base_url):
        resp = session.post(
            f"{base_url}/api/auth/login",
            json={"email": "kairos_user1@kairos.cl", "password": "Kairos2026!"},
        )
        assert resp.status_code == 200
        assert resp.json().get("role") == "student"

    def test_login_returns_correct_role_for_staff(self, session, base_url):
        resp = session.post(
            f"{base_url}/api/auth/login",
            json={"email": "staff1@kairos.cl", "password": "Kairos2026!"},
        )
        assert resp.status_code == 200
        assert resp.json().get("role") == "staff"

    def test_login_token_is_jwt_format(self, session, base_url):
        """JWT has exactly 3 dot-separated base64 segments."""
        resp = session.post(
            f"{base_url}/api/auth/login",
            json={"email": "kairos_user1@kairos.cl", "password": "Kairos2026!"},
        )
        token = resp.json()["token"]
        parts = token.split(".")
        assert len(parts) == 3, f"Expected 3 JWT segments, got {len(parts)}"


# ── /api/auth/register ─────────────────────────────────────────────────────────

@backend_required
class TestRegister:

    def _unique_email(self) -> str:
        return f"test_{uuid.uuid4().hex[:8]}@kairos.cl"

    def test_register_new_user_returns_201(self, session, base_url):
        payload = {
            "username": f"tuser_{uuid.uuid4().hex[:6]}",
            "email":    self._unique_email(),
            "password": "TestPass123!",
            "fullName": "Test User",
            "institution": None,
            "role": "student",
        }
        resp = session.post(f"{base_url}/api/auth/register", json=payload)
        assert resp.status_code == 201
        body = resp.json()
        assert "userId" in body
        assert body["email"] == payload["email"]

    def test_register_duplicate_email_returns_409(self, session, base_url):
        email = self._unique_email()
        payload = {
            "username": f"tuser_{uuid.uuid4().hex[:6]}",
            "email": email,
            "password": "TestPass123!",
            "fullName": "Test User",
            "institution": None,
            "role": "student",
        }
        first  = session.post(f"{base_url}/api/auth/register", json=payload)
        assert first.status_code == 201

        payload["username"] = f"tuser_{uuid.uuid4().hex[:6]}"  # different username
        second = session.post(f"{base_url}/api/auth/register", json=payload)
        assert second.status_code == 409

    def test_register_missing_required_fields_returns_400(self, session, base_url):
        resp = session.post(
            f"{base_url}/api/auth/register",
            json={"email": self._unique_email()},  # missing username, password, fullName
        )
        assert resp.status_code == 400

    def test_register_invalid_email_format_returns_400(self, session, base_url):
        resp = session.post(
            f"{base_url}/api/auth/register",
            json={
                "username": "testuser",
                "email": "not-an-email",
                "password": "TestPass123!",
                "fullName": "Test",
                "institution": None,
                "role": "student",
            },
        )
        assert resp.status_code == 400

    def test_registered_user_can_immediately_login(self, session, base_url):
        email    = self._unique_email()
        password = "TestPass123!"
        payload = {
            "username": f"tuser_{uuid.uuid4().hex[:6]}",
            "email":    email,
            "password": password,
            "fullName": "Fresh User",
            "institution": None,
            "role": "student",
        }
        reg = session.post(f"{base_url}/api/auth/register", json=payload)
        assert reg.status_code == 201

        login = session.post(
            f"{base_url}/api/auth/login",
            json={"email": email, "password": password},
        )
        assert login.status_code == 200
        assert login.json()["token"]
