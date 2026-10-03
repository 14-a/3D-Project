# GAS Example - Arcade Laser Generator

This is the reference **Generator extension** for Gator Audio Studio Extension API v1.

It demonstrates:

- generator package registration and lifecycle
- multiple extension categories
- generated parameter controls
- deterministic seeded synthesis
- extension-provided presets
- custom randomization distributions
- spec-driven mutation plus relationship clamping
- GAS User/Project preset compatibility
- background generation through `WorkerThreadPool`
- variants, Keep/Favorite, Send to Editor and WAV export through the normal Generator workflow
- project persistence of the extension ID/category/parameters
- typed PCM synthesis with no Dictionary/Variant access inside the sample loop

## Enable the bundled reference extension

This reference extension is already installed with GAS under:

```text
res://addons/gator_audio_studio/extensions/installed/com.blackwatergator.gas.example.arcade_laser/
```

To use it:

1. Open GAS.
2. Press **Extensions**.
3. Enable **GAS Example - Arcade Laser Generator**.
4. Open **Generator**.
5. In **Source**, select **Arcade Laser (Example Extension)**.
6. Choose a category or preset and generate variants normally.

The manifest ships with `"enabled": false`; users must explicitly enable the bundled reference extension. Use **Reload** if you modify its files while Godot is running.

## Categories

- Arcade Laser
- Heavy Plasma
- UI Zap

## Presets

- Default
- Arcade Pew
- Retro Zap
- Charge Shot
- Boss Laser

## Files

- `manifest.json` — package identity and the `generators` capability.
- `extension.gd` — package entry point.
- `arcade_laser_generator.gd` — parameters, presets, randomization, mutation and synthesis.

## Performance pattern

`generate()` runs on GAS worker threads. Read the parameter Dictionary only before synthesis begins. Cache all scalar values and the output `PackedFloat32Array`, then keep the sample loop fully typed and allocation-free.

Do not access the active SceneTree, editor Controls, `EditorInterface`, or shared mutable generator state from `generate()`.

## Turn this into your own generator

1. Copy and rename the folder.
2. Change the manifest `id`.
3. Change `EXTENSION_ID` in `extension.gd` to the same value.
4. Give the generator component a globally unique `GENERATOR_ID`.
5. Replace categories, parameter specs, presets and `generate()`.
6. Reload GAS Extensions and enable your package.
