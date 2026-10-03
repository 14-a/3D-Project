# GAS Example - Retro Radio

This is the reference **Audio Editor extension** for Gator Audio Studio Extension API v1.

It demonstrates:

- manifest metadata and compatibility fields
- package entry-point lifecycle
- editor-effect registration through `GASExtensionContext`
- a fully typed `GASEditorEffectExtension`
- automatically generated parameter controls
- extension-provided presets
- use in Effects, FX Rack, destructive processing and macros
- worker-safe PCM processing
- using stateless output buffers plus cached `PackedFloat32Array` and scalar values before the sample loop
- deterministic local noise without shared mutable DSP state
- clean unload/disable behavior

## Enable the bundled reference extension

This reference extension is already installed with GAS under:

```text
res://addons/gator_audio_studio/extensions/installed/com.blackwatergator.gas.example.retro_radio/
```

To use it:

1. Open GAS.
2. Press **Extensions**.
3. Enable **GAS Example - Retro Radio**.
4. Open the Audio Editor Effects/FX Rack.
5. Select **Retro Radio (Example Extension)**.

The manifest ships with `"enabled": false`, so the bundled reference extension never silently adds processing to a project. Use **Reload** if you modify its files while Godot is running.

## Files

- `manifest.json` — package identity, compatibility and capabilities.
- `extension.gd` — package entry point and lifecycle.
- `retro_radio_effect.gd` — the actual editor effect.

## Presets

- Default
- Telephone
- Walkie-Talkie
- Broken Speaker

## Version 1.0.3 behavior

The processor is deliberately stateless. Every `process()` call builds its output from only the current PCM and current parameter dictionary, so changing presets repeatedly cannot reuse stale DSP state. GAS **Overall Wet** is the only wet/dry control; the older redundant extension-level Mix control was removed.

The Walkie-Talkie preset uses 300–3200 Hz band limiting, 10-bit quantization, 0.3% deterministic static and stronger saturation. Broken Speaker uses 0.4% static. Telephone and Default noise values are unchanged.

## Performance pattern

Do not perform Dictionary lookups in DSP hot loops. Read extension parameters once at the start of `process()`, convert them to typed locals, cache `PackedFloat32Array` channel references, then iterate the samples.

`process()` may run on a GAS worker thread. Do not touch Controls, the active SceneTree, EditorInterface, or mutable shared DSP state from it.

## Turn this into your own extension

1. Copy the folder.
2. Rename the folder.
3. Change `manifest.json` `id`.
4. Change `EXTENSION_ID` in `extension.gd` to exactly the same ID.
5. Change the effect ID in `retro_radio_effect.gd` so it cannot collide with another component.
6. Replace the metadata, parameters and DSP.
7. Reload the GAS Extensions manager.


## PackedFloat32Array output rule

This example allocates one typed output PCM buffer, writes directly into cached `PackedFloat32Array` channel references, explicitly commits those arrays to the returned `GASPCMData`, and never stores mutable DSP state on the extension instance. This is the safest reference pattern for effects that may be instantiated repeatedly on WorkerThreadPool.
