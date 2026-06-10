from fastapi.testclient import TestClient

from app.main import app


def test_readyz_returns_ready():
    with TestClient(app) as client:
        response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_create_and_list_note():
    with TestClient(app) as client:
        created = client.post("/notes", json={"content": "testowa notatka"})
        assert created.status_code == 200
        note = created.json()
        assert note["content"] == "testowa notatka"
        assert "id" in note

        listed = client.get("/notes")
        assert listed.status_code == 200
        ids = [n["id"] for n in listed.json()]
        assert note["id"] in ids