from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # pole bez wartosci domyślnej = wymagane. Brak zmiennej środowiskowej
    # DATABASE_URL zatrzyma start apki czytelnym błędem walidacji.
    database_url: str
    
    # pola z deafultami są opcjonalne, jak dotychczasowe os.getenv(...., default)
    environment: str = "local"
    app_version: str = "0.0.0-dev"
    
settings = Settings()

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