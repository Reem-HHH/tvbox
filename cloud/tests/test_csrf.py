from fastapi.testclient import TestClient


def test_admin_post_rejects_missing_csrf(client: TestClient):
    # Establish session CSRF via login page.
    login_page = client.get("/admin/login")
    assert login_page.status_code == 200
    assert "csrf_token" in login_page.text

    # POST without token must fail.
    bad = client.post(
        "/admin/login",
        data={"email": "admin@example.com", "password": "test-admin-password-ok"},
    )
    assert bad.status_code == 403


def test_admin_login_accepts_csrf(client: TestClient):
    page = client.get("/admin/login")
    # Extract token from hidden input.
    marker = 'name="csrf_token" value="'
    assert marker in page.text
    token = page.text.split(marker, 1)[1].split('"', 1)[0]
    assert len(token) >= 16

    ok = client.post(
        "/admin/login",
        data={
            "email": "admin@example.com",
            "password": "test-admin-password-ok",
            "csrf_token": token,
        },
        follow_redirects=False,
    )
    assert ok.status_code == 303
    assert ok.headers.get("location") == "/admin"
