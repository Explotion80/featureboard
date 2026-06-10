import os

os.environ.setdefault(
    "DATABASE_URL",
    "postgresql://featureboard:localdevpassword@localhost:5432/featureboard",
)