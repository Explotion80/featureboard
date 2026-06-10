# Stage 1: Budowanie aplikacji
# buduje virtualvenv, instaluje zależności i kopiuje kod
# bazowy obraz python slim
FROM python:3.14-slim AS builder

WORKDIR /build

# tworzy venv w stałej lokalizacji, żeby później łatwo go skopiować
RUN python -m venv /opt/venv

#env path do venv, żeby pip i python były dostępne bezpośrednio
ENV PATH="/opt/venv/bin:$PATH"

# cache'owanie zależności: requirements.txt jest kopiowany przed kodem, żeby Docker mógł wykorzystać cache, jeśli zależności się nie zmieniły
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


# stage 2: runtime
# czyste środowisko + kopia gotowego venv i kodu
FROM python:3.14-slim AS runtime

# zainstaluj poprawki bezpieczeństwa debiana wydane po zbudowaniu obrazu bazowego
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# tworzymy nie-rootowego użytkownika do uruchamiania aplikacji, UID 1001
RUN useradd --create-home --uid 1001 --shell /bin/bash app

# kopiujemy gotowy venv z poprzedniego stage'a
COPY --from=builder /opt/venv /opt/venv

#PATH ustawiony na katalog domowy użytkownika, żeby aplikacja była uruchamiana z tego katalogu
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# kod aplikacji kopiowany z ownership do użytkownika app
COPY --chown=app:app app/ ./app/

# od tej linii proces uruchomi się jako app, nie jako root
USER app

EXPOSE 8000

# co się odpala, gdy kontener startuje
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]