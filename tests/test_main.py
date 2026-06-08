from fastapi.testclient import TestClient
from app.main import app
import sys
print(sys.path)

client = TestClient(app)


def test_health_returns_ok():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_root_returns_environment_and_version():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "environment" in data
    assert "version" in data