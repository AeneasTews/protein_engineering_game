# MutateIt — Protein Engineering Game

An interactive web game where players engineer proteins by introducing amino acid mutations, aiming to maximize predicted fitness.
Live at: **[mutateit.biocentral.cloud](https://mutateit.biocentral.cloud)**

## How it works

1. Select a protein from the library and enter a username.
2. Introduce mutations to the amino acid sequence.
3. The backend evaluates your sequence against a deep mutational scanning (DMS) model and returns a fitness score.
4. You have 20 turns — try to find the highest-scoring variant.
5. High scores are tracked per protein.

## Repository structure

```
app/        Flutter web frontend
backend/    FastAPI backend (Python)
docker-compose.yml
```

## Running locally

```bash
docker compose up --build
```

The frontend will be available at `http://localhost` and the backend API at `http://localhost:8000`.

### Without Docker

**Backend:**
```bash
cd backend
uv run uvicorn main:app --reload
# or: ./run.sh
```

**Frontend:**
```bash
cd app
flutter run -d chrome
```

## Deployment

Set the following environment variables before deploying:

| Variable | Description | Default |
|---|---|---|
| `API_BASE_URL` | Backend URL used by the frontend build | `http://localhost:8000` |
| `ALLOWED_ORIGINS` | CORS allowed origins for the backend | `*` |

## License

See [LICENSE](LICENSE).