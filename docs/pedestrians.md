# Ambient pedestrians

Pedestrians are decorative sidewalk walkers, separate from passengers. They cannot board, earn fares, complete objectives, appear as passenger minimap markers, or trigger enforcement. Their collision layer is zero so they do not obstruct the player, traffic, or enforcers; their movement still checks the existing world/vehicle collision layer and turns back when blocked.

## Place a system

1. Drag `3D/Scenes/NPC/PedestrianSystem.tscn` into the level.
2. Position it at sidewalk height (the current GameMap uses approximately Y=2.235).
3. Assign the gameplay Camera3D, or leave Camera empty to use the viewport's current camera.
4. Select its `Sidewalk` Path3D child and edit the Curve3D to follow clear sidewalk space. Make the curve resource unique before changing only one of several instances.
5. Set Pedestrian Count, Minimum/Maximum Speed, and Endpoint Pause on the route.

To add more routes under the same population limit, duplicate the Sidewalk child, make its curve unique, and edit it. Each route must be a direct Path3D child with `pedestrian_route.gd` attached. A curve needs at least two distinct points. Routes should stay at a consistent elevation; walkers currently remain at their initial height, matching the game's flat pedestrian movement.

The GameMap includes systems near the initial pickup, School, and the west terminal. Each requests four walkers, for a total of up to twelve. Samples overlapping static geometry or vehicles at initialization are skipped, so the actual starting count may be lower (eleven in the headless map check). No visible pedestrians are teleported into view as the camera moves.

## Population and optimization

Each system creates a fixed population once. **Maximum Population** defaults to 24 and caps all routes under that system. Separate systems have separate caps: budget the sum of their counts for the whole level. Population is not replenished or recreated during camera movement.

Every **Culling Interval** (default 0.15 seconds), the system caches the camera's six frustum planes and checks its walkers:

- Outside the frustum, including the back of the camera: hidden and fully suspended.
- Farther than **Activation Distance** (default 65 units): hidden and fully suspended even if in view.
- Inside both limits: visible with movement and layered sprite animation enabled.

**Frustum Margin** (default 1.5 units) gives a conservative bounding sphere around each actor so its sprite does not disappear as its center crosses a screen edge. Increase it for larger artwork or faster camera motion. Visibility can update up to one culling interval after camera movement.

Godot already performs render-frustum culling; this system additionally stops offscreen physics logic and animated-sprite processing by disabling the entire walker subtree. Culled walkers freeze in place and resume from the same position when visible again. This is an intentional CPU-saving simulation policy, not a continuous offscreen crowd simulation.

Missing cameras suspend walkers safely. Pausing the game pauses the system and actors. Scene changes free the whole population. Spawn-overlap checks run once, rather than every frame; route following uses baked points and direct collision movement, with no recurring A* search or navigation-mesh bake.

## Behavior and appearance

Walkers patrol the path in both directions, pause at endpoints, and reverse. If movement is blocked for 1.5 seconds, they pause and turn back instead of pushing indefinitely. They do not navigate around arbitrary buildings: draw routes on clear sidewalks. Separate pedestrian scenes can be customized using the same Appearance fields as passengers; the stock system uses the stock Pedestrian scene with randomized body, outfit, and hair.

## Added files and nodes

- `3D/Scenes/NPC/Pedestrian.tscn`: CharacterBody3D with PassengerVisual and CollisionShape3D, without passenger boarding areas or markers.
- `3D/Scenes/NPC/PedestrianSystem.tscn`: reusable system with an editable Sidewalk Path3D.
- `3D/Scripts/NPC/pedestrian.gd`: walking, animation, pauses, blocked movement, and simulation suspension.
- `3D/Scripts/NPC/pedestrian_route.gd`: per-route crowd and speed settings.
- `3D/Scripts/NPC/pedestrian_system.gd`: bounded population, clear spawn samples, camera selection, and frustum/distance checks.
- `tests/test_pedestrians.gd`: real-camera culling, movement/animation suspension, reactivation identity, bounds, endpoint reversal, pause, overlap rejection, no-camera behavior, map population, mission isolation, and cleanup.
- `3D/Scenes/World/GameMap.tscn` adds PickupPedestrians, SchoolPedestrians, and WestPedestrians, all referencing its Camera3D.

No existing passenger, enforcer, finance, mission, or traffic-height scripts were changed.

## Test

After importing the project, run:

```sh
godot --headless --path . --script tests/test_pedestrians.gd
```

The check uses a real Camera3D frustum in the headless engine and verifies which actors are processing; it does not claim a measured FPS improvement. Visual crowd density and route placement can be tuned in the target Godot editor.
