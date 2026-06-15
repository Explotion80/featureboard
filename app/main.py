from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    environment: str = "local"
    app_version: str = "0.0.0-dev"

    # Wariant lokalny / CI: pełny URL podany wprost
    database_url: str | None = None

    # Wariant chmurowy: składniki + nazwa sekretu z hasłem w Secret Managerze
    db_host: str | None = None
    db_name: str = "featureboard"
    db_user: str = "featureboard"
    db_password_secret: str | None = None  # pełna nazwa wersji sekretu


settings = Settings()


def resolve_database_url() -> str:
    # 1) Jeśli mamy gotowy URL (lokalnie/CI) — używamy go bez sięgania do chmury
    if settings.database_url:
        return settings.database_url
    # 2) Wariant chmurowy: pobierz hasło z Secret Managera (przez Workload Identity)
    if settings.db_host and settings.db_password_secret:
        from google.cloud import secretmanager

        client = secretmanager.SecretManagerServiceClient()
        resp = client.access_secret_version(name=settings.db_password_secret)
        password = resp.payload.data.decode()
        return (
            f"postgresql://{settings.db_user}:{password}"
            f"@{settings.db_host}:5432/{settings.db_name}"
        )
    raise RuntimeError(
        "Brak konfiguracji bazy: ustaw DATABASE_URL albo DB_HOST + DB_PASSWORD_SECRET"
    )


DATABASE_URL = resolve_database_url()



def init_db():
    with psycopg.connect(settings.database_url, connect_timeout=5) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS notes (
                id SERIAL PRIMARY KEY,
                content TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            """
        )

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield
    
app = FastAPI(lifespan=lifespan)


class NoteIn(BaseModel):
    content: str



@app.get("/")
def root():
    return {
        "environment": settings.environment,
        "version": settings.app_version,
    }


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    try:
        with psycopg.connect(settings.database_url, connect_timeout=4) as conn:
            conn.execute("SELECT 1")
        return {"status": "ready"}
    except Exception:
        raise HTTPException(status_code=503, detail="database unavailable")
    
    
@app.post("/notes")
def create_note(note: NoteIn):
    with psycopg.connect(settings.database_url) as conn:
        row = conn.execute(
            "INSERT INTO notes (content) VALUES (%s) RETURNING id, content, created_at",
            (note.content,),
        ).fetchone()
    return {"id": row[0], "content": row[1], "created_at": row[2]}

@app.get("/notes")
def list_notes():
    with psycopg.connect(settings.database_url) as conn:
        rows = conn.execute(
            "SELECT id, content, created_at FROM notes ORDER BY id"
        ).fetchall()
    return [{"id": r[0], "content": r[1], "created_at": r[2]} for r in rows]