# Ambient pedestrians

Pedestrians are decorative sidewalk walkers, separate from passengers. They cannot board, earn fares, complete objectives, appear as passenger minimap markers, or trigger enforcement. Their collision layer is zero so they do not obstruct the player, traffic, or enforcers. They still check world/vehicle collision while moving.

## GameMap: crowds across the road network

`GameMap/SidewalkPopulation` replaces the three original sample crowd nodes. It indexes `LargeRoadGridMap` and `MediumRoadGridMap`, deriving patrol segments from the actual straight-road mesh transforms, including cell rotation and scale. It is independent of passenger and destination positions.

The current city_builder road mesh has raised sidewalk strips at local X between ±0.93 and ±1.0. Pedestrian centers use **±0.965**, rather than estimated world positions inside the asphalt. On the starting street, the west sidewalk center is **X=258.175**, not the old route's X=258.8. Actor height follows the transformed road top plus sprite clearance.

The manager generates candidates on both sides of straight street tiles throughout the map. It avoids overlaps with neighboring road tiles and checks the complete patrol segment for buildings and other collision obstacles before assigning a walker. Intersections and curved-road tiles are intentionally excluded; pedestrians do not cross traffic lanes. Blocked/absent sidewalks are left empty.

A spatial bucket index selects nearby candidates as the gameplay camera moves. The scene uses **Maximum Population = 40** for its single shared pool, rather than creating thousands of actors for the thousands of candidate sidewalk strips. Offscreen actors are reused when entering another neighborhood. Visible actors are never reassigned. New route assignments after initial loading happen outside the padded camera frustum. Culled or unused pool members are hidden and suspended.

Inspector settings on SidewalkPopulation:

- **Camera**: the gameplay camera; leave empty to use the viewport's current camera.
- **Road Grids**: GridMaps using the supported city_builder road assets.
- **Maximum Population**: total actor budget for this manager, including its inactive reusable pool.
- **Activation Distance**: radius around the camera from which sidewalk candidates are selected; default 65 units.
- **Culling Interval**: visibility checks every 0.15 seconds by default.
- **Frustum Margin**: conservative sphere, default 1.5 units, to keep sprite edges from disappearing prematurely.
- **Sidewalk Center**: local mesh X offset, default 0.965. This is specific to the current road assets; retune the generator for replacement mesh geometry.
- **Patrol Half Length**: default 0.8 in mesh coordinates, keeping patrol endpoints away from tile boundaries/intersections.
- **Minimum/Maximum Speed**: random walking speed per assignment.

Streaming refreshes after roughly four units of camera movement. The design anticipates normal driving with an ahead-of-view population; it deliberately avoids materializing pedestrians on already visible routes after a camera teleport. Road geometry is indexed once per level load; runtime road edits require reloading/rebuilding the system.

## Custom authored routes

`3D/Scenes/NPC/PedestrianSystem.tscn` remains available for parks, plazas, or other areas needing manually authored paths:

1. Drag PedestrianSystem.tscn into a level and position it on walkable ground.
2. Assign its gameplay camera, or leave Camera empty for the viewport camera.
3. Select its Sidewalk Path3D child and edit the Curve3D. Make the resource unique before editing only one of several instances.
4. Set Pedestrian Count, Minimum/Maximum Speed, and Endpoint Pause on the route.

Duplicate Sidewalk children to add routes under the same manager budget. Each route must be a direct Path3D child with `pedestrian_route.gd` attached. Curves need at least two distinct points and should remain at a consistent elevation. Walkers currently stay at their initial height, matching the game's flat pedestrian movement.

A manually authored system creates its fixed population once; Maximum Population defaults to 24 across its routes. Multiple manually placed systems have separate budgets. This mode does not automatically recognize sidewalks: authors must draw paths on safe walkable surfaces.

## Movement, appearance, and culling

Walkers patrol both directions, pause at endpoints, and reverse. If movement is blocked for 1.5 seconds, they pause and turn back. They do not run A* searches or require a navigation-mesh bake. Generated street patrols are constrained to their sidewalk segment so collision sliding cannot push them into the road.

A centered, small square collision footprint fits the narrower medium-road sidewalk regardless of tile orientation. Sprite artwork is unchanged. Pedestrian scenes retain the same Appearance fields as passengers; the default crowd uses randomized body, outfit, and hair.

Godot already culls rendering by camera frustum. These managers additionally suspend movement and layered sprite animation for offscreen or distant actors by disabling their whole subtree. Frustum planes are cached per culling pass. The road manager uses current frustum checks when deciding whether a pool member can safely be reused. Hidden assigned walkers freeze and resume from the same position if their route is retained; unassigned members remain hidden even if their previous location becomes visible.

Missing cameras safely suspend actors, game pause pauses them, and scene changes free the population. This is a limited ambient crowd simulation; it does not simulate every pedestrian moving across the city offscreen or claim a measured FPS improvement.

## Files

- `3D/Scenes/NPC/Pedestrian.tscn`: ambient body, layered visual, and small centered collision footprint.
- `3D/Scenes/NPC/PedestrianSystem.tscn`: reusable manually authored patrol system.
- `3D/Scripts/NPC/pedestrian.gd`: walking, pauses, collision response, optional sidewalk constraint, appearance, and suspension.
- `3D/Scripts/NPC/pedestrian_route.gd`: manual route properties.
- `3D/Scripts/NPC/pedestrian_system.gd`: manual population, camera lookup, frustum and distance culling.
- `3D/Scripts/NPC/sidewalk_population.gd`: road-derived sidewalk geometry, spatial index, safe segments, and shared crowd pool.
- `3D/Scenes/World/GameMap.tscn`: one SidewalkPopulation node referencing the two road GridMaps and Camera3D.
- `tests/test_pedestrians.gd`: original culling, movement, budget, pause, isolation, and cleanup coverage.
- `tests/test_sidewalk_population.gd`: real-road sidewalk coordinates, map-wide coverage, cell rotation, bounded regional streaming, pool reuse, no visible recycling, constrained walking, and cleanup.

No existing passenger, enforcer, finance, mission, or traffic-height scripts were changed by the pedestrian system.

## Test

After importing the project:

```sh
godot --headless --path . --script tests/test_pedestrians.gd
godot --headless --path . --script tests/test_sidewalk_population.gd
```

These checks use the real mesh resources and a real Camera3D frustum in the headless engine. Visual crowd density and artwork alignment should also be playtested in the target editor.
