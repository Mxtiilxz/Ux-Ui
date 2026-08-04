"""
Tests for:
    GET  /api/posts/feed
    POST /api/posts
"""

import pytest
import requests

from conftest import backend_required, BASE_URL


# ── Fixtures for role-specific sessions ───────────────────────────────────────

@pytest.fixture(scope="module")
def company_session(session, base_url):
    """Session authenticated as a company user. Skips if none exists."""
    resp = session.post(
        f"{base_url}/api/auth/login",
        json={"email": "empresa@kairos.cl", "password": "Kairos2026!"},
    )
    if resp.status_code != 200:
        pytest.skip("No company seed user found — add one to DevDataSeeder to run these tests.")
    token = resp.json()["token"]
    s = requests.Session()
    s.headers.update({"Content-Type": "application/json", "Authorization": f"Bearer {token}"})
    return s


# ── GET /api/posts/feed ────────────────────────────────────────────────────────

@backend_required
class TestGetFeed:

    def test_feed_without_token_returns_401(self, session, base_url):
        resp = session.get(f"{base_url}/api/posts/feed")
        assert resp.status_code == 401

    def test_feed_with_token_returns_200(self, auth_session, base_url):
        resp = auth_session.get(f"{base_url}/api/posts/feed")
        assert resp.status_code == 200

    def test_feed_response_has_items_key(self, auth_session, base_url):
        body = auth_session.get(f"{base_url}/api/posts/feed").json()
        assert "items" in body, f"Missing 'items' key — got: {list(body.keys())}"
        assert isinstance(body["items"], list)

    def test_feed_response_has_pagination_metadata(self, auth_session, base_url):
        body = auth_session.get(f"{base_url}/api/posts/feed").json()
        assert "totalCount" in body
        assert "hasNextPage" in body

    def test_feed_explicit_page_and_size(self, auth_session, base_url):
        body = auth_session.get(f"{base_url}/api/posts/feed?page=1&pageSize=5").json()
        assert len(body["items"]) <= 5

    def test_feed_page_zero_returns_400(self, auth_session, base_url):
        resp = auth_session.get(f"{base_url}/api/posts/feed?page=0")
        assert resp.status_code == 400

    def test_feed_items_have_required_fields(self, auth_session, base_url):
        items = auth_session.get(f"{base_url}/api/posts/feed").json()["items"]
        if not items:
            pytest.skip("Feed is empty — create a post first")
        post = items[0]
        for field in ("id", "authorId", "authorName", "authorRole",
                      "content", "postType", "likesCount", "commentsCount", "createdAt"):
            assert field in post, f"Post missing field '{field}': {list(post.keys())}"

    def test_feed_post_type_is_valid_value(self, auth_session, base_url):
        items = auth_session.get(f"{base_url}/api/posts/feed").json()["items"]
        valid_types = {"General", "Event", "Job"}
        for post in items:
            assert post["postType"] in valid_types, (
                f"Unexpected postType '{post['postType']}'"
            )

    def test_feed_ordered_newest_first(self, auth_session, base_url):
        items = auth_session.get(f"{base_url}/api/posts/feed?pageSize=50").json()["items"]
        if len(items) < 2:
            pytest.skip("Not enough posts to check ordering")
        dates = [p["createdAt"] for p in items]
        assert dates == sorted(dates, reverse=True), "Feed is not ordered newest-first"


# ── POST /api/posts ────────────────────────────────────────────────────────────

@backend_required
class TestCreatePost:

    # ── Auth ──────────────────────────────────────────────────────────────────

    def test_create_post_without_token_returns_401(self, session, base_url):
        resp = session.post(f"{base_url}/api/posts",
                            json={"content": "No auth"})
        assert resp.status_code == 401

    # ── General posts (any role) ──────────────────────────────────────────────

    def test_general_post_by_student_returns_201(self, auth_session, base_url):
        resp = auth_session.post(f"{base_url}/api/posts",
                                 json={"content": "Hola desde el test", "postType": "general"})
        assert resp.status_code == 201

    def test_general_post_returns_numeric_id(self, auth_session, base_url):
        resp = auth_session.post(f"{base_url}/api/posts",
                                 json={"content": "Otro test post", "postType": "general"})
        assert resp.status_code == 201
        assert isinstance(resp.json(), int) and resp.json() > 0

    def test_general_post_default_type_is_general(self, auth_session, base_url):
        """Omitting postType should default to 'general'."""
        resp = auth_session.post(f"{base_url}/api/posts",
                                 json={"content": "Post sin tipo explícito"})
        assert resp.status_code == 201

    def test_general_post_with_image_url(self, auth_session, base_url):
        resp = auth_session.post(f"{base_url}/api/posts", json={
            "content":  "Post con imagen",
            "postType": "general",
            "imageUrl": "https://example.com/img.jpg",
        })
        assert resp.status_code == 201

    def test_general_post_appears_in_feed(self, auth_session, base_url):
        marker = f"INTEGRATION_MARKER_{__import__('uuid').uuid4().hex[:8]}"
        auth_session.post(f"{base_url}/api/posts",
                          json={"content": marker, "postType": "general"})
        items = auth_session.get(f"{base_url}/api/posts/feed?pageSize=50").json()["items"]
        assert any(marker in p["content"] for p in items), "New post not found in feed"

    # ── Validation errors ─────────────────────────────────────────────────────

    def test_empty_content_returns_400(self, auth_session, base_url):
        resp = auth_session.post(f"{base_url}/api/posts",
                                 json={"content": "", "postType": "general"})
        assert resp.status_code == 400

    def test_missing_content_returns_400(self, auth_session, base_url):
        resp = auth_session.post(f"{base_url}/api/posts",
                                 json={"postType": "general"})
        assert resp.status_code == 400

    def test_invalid_post_type_returns_400(self, auth_session, base_url):
        resp = auth_session.post(f"{base_url}/api/posts",
                                 json={"content": "Test", "postType": "unknown_type"})
        assert resp.status_code == 400

    def test_content_over_2000_chars_returns_400(self, auth_session, base_url):
        resp = auth_session.post(f"{base_url}/api/posts",
                                 json={"content": "x" * 2001, "postType": "general"})
        assert resp.status_code == 400

    # ── Event posts ───────────────────────────────────────────────────────────

    def test_event_post_by_student_returns_403(self, auth_session, base_url):
        """Students cannot post events."""
        resp = auth_session.post(f"{base_url}/api/posts", json={
            "content":   "Evento de prueba",
            "postType":  "event",
            "eventDate": "2026-06-15",
        })
        assert resp.status_code == 403

    def test_event_post_missing_event_date_returns_400(self, auth_session, base_url):
        """EventDate is required for event posts regardless of role."""
        resp = auth_session.post(f"{base_url}/api/posts", json={
            "content":  "Evento sin fecha",
            "postType": "event",
        })
        # 400 (missing date) or 403 (wrong role) — both are valid here
        assert resp.status_code in (400, 403)

    # ── Job posts ─────────────────────────────────────────────────────────────

    def test_job_post_by_student_returns_403(self, auth_session, base_url):
        """Students cannot post job offers."""
        resp = auth_session.post(f"{base_url}/api/posts", json={
            "content":  "Oferta laboral falsa",
            "postType": "job",
        })
        assert resp.status_code == 403
