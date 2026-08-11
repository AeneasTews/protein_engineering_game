# MutateIt — Frontend

Flutter app for the MutateIt protein engineering game, served at [mutateit.biocentral.cloud](https://mutateit.biocentral.cloud). Runs on web, macOS, Linux, and Windows.

## What it does

Players select a protein from the library, enter a username, then iteratively introduce amino acid mutations to maximize the protein's predicted fitness score. Each round the app sends the mutated sequence to the backend, which evaluates it using a deep mutational scanning (DMS) model and returns a score. The 3D structure is rendered by a custom viewer built on [`flutter_scene`](https://pub.dev/packages/flutter_scene) (Flutter GPU/Impeller), from residue data the backend has already fetched, validated against the protein's wildtype sequence, and extracted.

## Stack

- Flutter, on the `master` channel via [`fvm`](https://fvm.app/) — required, since `flutter_scene` needs Flutter GPU/Impeller, not yet on `stable`
- [flutter_bloc](https://pub.dev/packages/flutter_bloc) for state management
- [`flutter_scene`](https://pub.dev/packages/flutter_scene) for 3D structure rendering (`lib/structure/`)
- Communicates with the FastAPI backend over HTTP

## Development

See the [root README](../README.md#setup) for full setup (fvm install, native-assets config, per-platform build
prerequisites). Once set up:

```bash
fvm flutter pub get
fvm flutter run -d chrome   # or -d macos / -d linux / -d windows
```

The API base URL defaults to `http://localhost:8000`. Override it at build time:

```bash
fvm flutter build web --dart-define=API_BASE_URL=https://your-backend-url
```

## Production build (Docker)

Normally built and served via the project-level `docker-compose.yml` — see the [root README](../README.md). This
is currently **not working**: `Dockerfile` still targets Flutter `stable`, which can't build `flutter_scene` (see
the Gotchas section in the root README). Build locally with `fvm flutter build web` until that's updated.
