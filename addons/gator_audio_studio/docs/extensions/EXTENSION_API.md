# Gator Audio Studio Extension API

**GAS version:** 1.0.0  
**Extension API version:** 1  
**Target:** Godot 4.6+  
**Language:** fully typed GDScript

GAS extensions are normal GDScript packages discovered by Gator Audio Studio. They are not VST/VST3/LV2/AU plugins and require no native host.

## Installation layout

Every installed package is one direct child of:

```text
res://addons/gator_audio_studio/extensions/installed/
```

The folder name must exactly match the lowercase package ID:

```text
installed/
└── com.example.my_audio_extension/
    ├── manifest.json
    ├── extension.gd
    └── ...component scripts...
```

GAS scans direct children only. Loose scripts and nested packages are ignored.

## Manifest

`manifest.json` is required.

```json
{
  "id": "com.example.my_audio_extension",
  "name": "My Audio Extension",
  "version": "1.0.0",
  "api_version": 1,
  "min_gas_version": "0.12.18",
  "max_gas_version": "",
  "min_godot_version": "4.6.0",
  "entry": "extension.gd",
  "author": "Example Author",
  "description": "Adds an editor effect and generator.",
  "capabilities": ["editor_effects", "generators"],
  "enabled": true
}
```

Required fields are `id`, `name`, `version`, `api_version`, `min_gas_version`, `min_godot_version`, `capabilities`, and `entry`.

Supported capabilities:

- `editor_effects`
- `generators`
- `analyzers`

GAS rejects incompatible API versions, incompatible GAS/Godot versions, duplicate IDs, invalid folder/ID pairs, entries outside the package folder, and entry scripts that do not extend `GASExtension`.

## Package entry point

```gdscript
@tool
extends GASExtension

const MyEffect: GDScript = preload("my_effect.gd")
const MyGenerator: GDScript = preload("my_generator.gd")


func get_extension_id() -> StringName:
    return &"com.example.my_audio_extension"


func get_extension_name() -> String:
    return "My Audio Extension"


func get_version() -> String:
    return "1.0.0"


func get_author() -> String:
    return "Example Author"


func get_description() -> String:
    return "Adds an editor effect and generator."


func register_components(context: GASExtensionContext) -> void:
    context.register_editor_effect(MyEffect)
    context.register_generator(MyGenerator)


func on_loaded(_context: GASExtensionContext) -> void:
    pass


func on_unloaded(_context: GASExtensionContext) -> void:
    pass
```

The entry script ID, name and version must match the manifest. Use the supplied `GASExtensionContext` for component registration instead of reaching into GAS private nodes. If any declared component fails registration (for example because its ID collides with an already loaded component), GAS rejects the package and rolls back every component registered by that package.

## Editor effect extensions

Extend `GASEditorEffectExtension`. Registered editor effects automatically appear in GAS's Effect menu, destructive Effect panel, realtime effect racks, effect preset workflow and macro effect list.

```gdscript
@tool
extends GASEditorEffectExtension


func get_effect_id() -> StringName:
    return &"example.effect"


func get_display_name() -> String:
    return "Example Effect"


func get_description() -> String:
    return "Example offline/realtime-stack-safe effect."


func get_default_params() -> Dictionary:
    return {
        "amount": 0.5,
        "enabled_feature": true,
        "mode": "Soft",
    }


func get_parameter_specs() -> Array[Dictionary]:
    return [
        number_spec("Amount", "amount", 0.0, 1.0, 0.01),
        bool_spec("Feature", "enabled_feature"),
        enum_spec("Mode", "mode", PackedStringArray(["Soft", "Hard"])),
    ]


func get_presets() -> PackedStringArray:
    return PackedStringArray(["Default", "Strong"])


func apply_preset(params: Dictionary, preset_name: String) -> Dictionary:
    var output: Dictionary = params.duplicate(true)
    if preset_name == "Strong":
        output["amount"] = 0.9
    return output


func process(pcm: GASPCMData, params: Dictionary) -> GASPCMData:
    var amount: float = float(params.get("amount", 0.5))
    var left: PackedFloat32Array = pcm.left
    var right: PackedFloat32Array = pcm.right
    var frames: int = pcm.frame_count()
    for frame: int in range(frames):
        left[frame] *= amount
        if pcm.is_stereo():
            right[frame] *= amount
    return pcm
```

`process()` can be invoked from GAS worker threads. It must not access the active scene tree, editor Controls, or mutable global DSP state. Cache typed arrays/scalars before hot loops and avoid `Variant`/Dictionary lookups per sample.

Optional effect methods:

- `is_stack_safe() -> bool`
- `outputs_stereo() -> bool`
- `get_tail_frames(params, sample_rate) -> int`

If an extension is missing when a `.gasproj` is loaded, the effect token and saved parameter dictionary remain in the project. Audio processing bypasses the unavailable effect rather than discarding its data.

## Generator extensions

Extend `GASGeneratorExtension`. Registered generators automatically appear in the Generator's **Source** selector. GAS builds controls from the declared parameter specifications and integrates seed changes, randomization, mutation, extension-provided presets, GAS User/Project presets, variants, kept/favorite variants, project persistence and WAV export.

```gdscript
@tool
extends GASGeneratorExtension


func get_generator_id() -> StringName:
    return &"example.generator"


func get_display_name() -> String:
    return "Example Generator"


func get_description() -> String:
    return "Creates example procedural audio."


func get_categories() -> PackedStringArray:
    return PackedStringArray(["Laser", "UI"])


func get_default_params(category: String, seed: int) -> Dictionary:
    return {
        "category": category,
        "seed": seed,
        "frequency": 440.0,
        "duration": 0.2,
    }


func get_parameter_specs(_category: String) -> Array[Dictionary]:
    return [
        number_spec("Frequency", "frequency", 40.0, 8000.0, 1.0),
        number_spec("Duration", "duration", 0.01, 4.0, 0.01),
    ]


func generate(params: Dictionary) -> GASPCMData:
    var sample_rate: int = 44100
    var duration: float = float(params.get("duration", 0.2))
    var frequency: float = float(params.get("frequency", 440.0))
    var frame_count: int = maxi(1, int(round(duration * sample_rate)))
    var pcm: GASPCMData = GASPCMData.new()
    pcm.sample_rate = sample_rate
    pcm.channels = 1
    pcm.left.resize(frame_count)
    var samples: PackedFloat32Array = pcm.left
    var phase_step: float = TAU * frequency / float(sample_rate)
    for frame: int in range(frame_count):
        samples[frame] = sin(float(frame) * phase_step) * 0.4
    return pcm
```

Generation occurs through `WorkerThreadPool`, including extension variant batches. Do not touch UI/scene-tree objects in `generate()`.

`GASGeneratorExtension` supplies generic `randomize_params()` and `mutate_params()` implementations from parameter specs. Override them when the generator needs specialized distributions or locked relationships.

## Analyzer extensions

Extend `GASAnalyzerExtension`. Registered analyzers appear in the Analyzer panel's extension selector and run through the analyzer background worker.

```gdscript
@tool
extends GASAnalyzerExtension


func get_analyzer_id() -> StringName:
    return &"example.analyzer"


func get_display_name() -> String:
    return "Example Analyzer"


func analyze(pcm: GASPCMData, start_frame: int, end_frame: int) -> Dictionary:
    return {
        "frames": maxi(0, end_frame - start_frame),
        "sample_rate": pcm.sample_rate,
    }
```

Return JSON-compatible values when possible; GAS displays the returned result in the Analyzer metrics panel.

## Declarative parameter controls

Editor effects and generators use the same parameter spec format:

- `number_spec(label, key, minimum, maximum, step)`
- `number_spec(..., true)` for integer controls
- `bool_spec(label, key)`
- `enum_spec(label, key, options)`

The spec is parsed at the UI boundary. DSP code receives the resulting parameter dictionary and should cast values to concrete types once before hot loops.

## Lifecycle and reload

- GAS discovers extensions when the plugin is enabled.
- **Extensions** lists installed packages and allows persistent enable/disable.
- **Reload Extensions** unloads registered components cleanly, reloads package entry scripts and refreshes Editor/Generator/Analyzer integration.
- `on_unloaded()` is called before owned component registrations are removed.
- GAS stores enable/disable overrides in `user://gator_audio_studio/extension_state.json` rather than modifying third-party manifests.
- If an extension is missing or disabled, saved generator parameters remain attached to the project/preset and GAS shows the missing dependency instead of feeding those parameters to the built-in synth.

## Compatibility rules

API version 1 is intentionally narrow. Extensions may use only the public base classes/context described here as their integration contract. Private GAS UI/model implementation details can change without preserving compatibility.

For maximum performance, components should remain `RefCounted`, stateless across worker calls where practical, fully typed, allocation-light, and free of per-sample `Variant` operations.

## Shipped reference extensions

GAS ships two complete reference packages under:

```text
res://addons/gator_audio_studio/extensions/installed/
```

They are installed with GAS but their manifests default to `enabled: false`, so they are discoverable in the Extensions panel without adding effect/generator entries until the user explicitly enables them.

### Audio Editor reference

```text
com.blackwatergator.gas.example.retro_radio/
```

Demonstrates:

- `editor_effects` package capability
- extension lifecycle and registration
- declarative parameter UI
- extension presets
- FX Rack/destructive/macro integration
- fully typed, worker-safe `PackedFloat32Array` DSP
- caching all Dictionary values before sample loops

### Generator reference

```text
com.blackwatergator.gas.example.arcade_laser/
```

Demonstrates:

- `generators` package capability
- multiple generator categories
- deterministic seeds
- custom randomization and mutation
- extension-provided presets
- GAS User/Project presets
- worker-thread synthesis
- variants, Keep/Favorite, Send to Editor and export integration

To test an example, copy its entire package folder into `extensions/installed/`, press **Extensions → Reload**, then explicitly enable it. Both manifests use `"enabled": false` so the first activation is always deliberate.


## PackedFloat32Array output rule

Editor effects often cache `pcm.left` and `pcm.right` into typed `PackedFloat32Array` locals to avoid repeated property lookup in the sample loop. After modifying those locals, **assign them back to `GASPCMData` before returning**:

```gdscript
var left: PackedFloat32Array = pcm.left
var right: PackedFloat32Array = pcm.right
# ... typed DSP loop ...
pcm.left = left
if pcm.is_stereo():
	pcm.right = right
return pcm
```

This is part of the GAS extension contract. It avoids depending on packed-array alias/copy-on-write behavior across Object, Variant, and WorkerThreadPool boundaries while retaining typed hot loops.
