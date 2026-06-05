# MutateIt — Frontend

Flutter web app for the MutateIt protein engineering game, served at [mutateit.biocentral.cloud](https://mutateit.biocentral.cloud).

## What it does

Players select a protein from the library, enter a username, then iteratively introduce amino acid mutations to maximize the protein's predicted fitness score. Each round the app sends the mutated sequence to the backend, which evaluates it using a deep mutational scanning (DMS) model and returns a score. The 3D structure is visualized in real time via [Mol*](https://molstar.org/).

## Stack

- Flutter (web target)
- [flutter_bloc](https://pub.dev/packages/flutter_bloc) for state management
- [Mol*](https://molstar.org/) for 3D structure rendering (via JS interop)
- Communicates with the FastAPI backend over HTTP

## Development

```bash
flutter pub get
flutter run -d chrome
```

The API base URL defaults to `http://localhost:8000`. Override it at build time:

```bash
flutter build web --dart-define=API_BASE_URL=https://your-backend-url
```

## Production build (Docker)

Built and served via the project-level `docker-compose.yml`. See the [root README](../README.md).