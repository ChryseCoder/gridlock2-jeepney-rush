# NPC Appearance Inspector

Select a placed **Passenger** or **TrafficEnforcer** root (`CharacterBody3D`) in the scene tree and expand **Appearance** in the Inspector. You do not need to edit the nested `PassengerVisual` scene.

| Property | Behavior |
| --- | --- |
| Randomize Appearance | Enabled by default. Picks from the existing body, outfit, and hair resources each time the NPC spawns. Disable to use the three fixed resource fields. |
| Body Sprite Frames | Body `SpriteFrames` resource for a fixed appearance. An empty slot uses `body_02.tres`. |
| Outfit Sprite Frames | Clothing `SpriteFrames` resource for a fixed appearance. An empty slot uses `outfit_02.tres`. |
| Hair Sprite Frames | Hair `SpriteFrames` resource for a fixed appearance. An empty slot uses `hair_02.tres`. |
| Outfit Tint | Per-instance clothing color multiplier. Works with either randomized or fixed resources. Defaults to white for passengers and blue for enforcers. Use white to show a custom uniform's original colors. |

Changes take effect when the scene runs. The editor preview still shows the nested visual scene's existing sprites; this implementation does not run gameplay scripts in the editor.

## Choose an appearance

1. Select the NPC root in the map.
2. Disable **Randomize Appearance**.
3. Drag `.tres` files from `3D/Assets/Images/Sprites/Passengers/` into the Body, Outfit, and Hair fields.
4. Set **Outfit Tint**, then run the scene.

For example, assign `body_01.tres`, `outfit_03.tres`, and `hair_01.tres` to a passenger. For an enforcer with a dedicated uniform resource, assign that resource to Outfit Sprite Frames and use a white tint.

Instances can share the same resources while using different tints. The scripts assign resources and tint the sprite nodes; they do not modify the shared `.tres` files. Editing a resource itself in Godot will still affect every instance that references it, so duplicate the resource first when creating a new variant.

## Custom sprite requirements

Assign a **SpriteFrames** resource, not an individual PNG. It must contain nonempty animations named:

```text
idle_down   idle_left   idle_right   idle_up
walk_down   walk_left   walk_right   walk_up
```

If a required animation is missing or empty, the game warns and uses the default resource for that layer. A mismatched animation frame count is clamped to valid indices to prevent invalid frame access, but matching frame counts, alignment, and sprite dimensions are recommended for coordinated animation.

The body drives frame synchronization. Appearance changes do not resize collision shapes or alter movement, pathfinding, detection, legality, income, or violations. Very large or differently aligned artwork may therefore need separate visual/collision adjustments.

## Boarding and drop-off

`PassengerVisual.get_appearance()` now includes the outfit tint alongside the three SpriteFrames resources. The existing player manifest stores that dictionary and restores it to the passenger spawned at drop-off. The same selected body, outfit, hair, and tint survive the trip.

## Changed files

- `3D/Scripts/NPC/passenger.gd`: exported Appearance properties on the passenger root; configures the visual at startup.
- `3D/Scripts/NPC/traffic_enforcer.gd`: matching properties on the enforcer root; blue is now an editable default instead of a forced tint.
- `3D/Scripts/NPC/passenger_visual.gd`: shared random/fixed appearance configuration, animation validation, frame synchronization, and tint capture/restore.
- `tests/test_npc_appearance.gd`: checks Inspector grouping, startup selection, serialized scene overrides, per-instance tint, defaults, resource validation, animation bounds, and actual boarding/drop-off appearance preservation.
- `docs/traffic-enforcer.md`: points to this guide.

No new sprite assets or scene nodes are required. Existing scenes retain randomized appearances and the enforcers' blue tint by default.

## Run tests

After importing the project:

```sh
godot --headless --path . --script tests/test_npc_appearance.gd
```

The test deliberately supplies one invalid SpriteFrames resource to verify the warning and safe fallback. That warning is expected; the final result should be `CHECKS: 18; FAILURES: 0`.
