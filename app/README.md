# MutateIt — Frontend

Flutter app for the MutateIt protein engineering game, served at [mutateit.biocentral.cloud](https://mutateit.biocentral.cloud). Runs on web, macOS, Linux, and Windows.

## What it does

Players select a protein from the library, enter a username, then iteratively introduce amino acid mutations to maximize the protein's predicted fitness score. Each round the app sends the mutated sequence to the backend, which evaluates it using a deep mutational scanning (DMS) model and returns a score. The 3D structure is rendered by `ProteinViewer` from [`bio_flutter`](https://github.com/biocentral/bio_flutter) (built on [`flutter_scene`](https://pub.dev/packages/flutter_scene), Flutter GPU/Impeller). The backend serves mmCIF trimmed to the chain and residues that match the protein's wildtype sequence, plus a map from sequence positions to residues; the app parses it with bio_flutter's `MmcifParser`.

## Stack

- Flutter, on the `master` channel via [`fvm`](https://fvm.app/) — required, since `flutter_scene` needs Flutter GPU/Impeller, not yet on `stable`
- [flutter_bloc](https://pub.dev/packages/flutter_bloc) for state management
- [`bio_flutter`](https://github.com/biocentral/bio_flutter)'s `ProteinViewer` for 3D structure rendering (path dependency on `../../bio_flutter`; see `lib/widgets/structure_panel.dart`)
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
