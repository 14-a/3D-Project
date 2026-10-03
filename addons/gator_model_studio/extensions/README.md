# Gator Model Studio extensions

This folder contains the versioned extension API and all loadable extension packages.

- `api/`: public extension base classes and API facade
- `registries/`: modelling-tool, modifier, importer, and exporter registries
- `runtime/`: manifest parsing, compatibility checks, loading, and unloading
- `installed/`: all loadable packages, including the bundled reference extension

Do not place third-party scripts directly in `api/`, `registries/`, or `runtime/`. Install each package as a direct child of `installed/`:

```text
installed/<extension_id>/extension.cfg
```

The folder name must exactly match the lowercase manifest ID. The bundled example follows the same contract at `installed/blackwater_gator.procedural_gear/`.

Developer documentation is in `../docs/extensions/`.
