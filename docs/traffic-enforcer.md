# Traffic enforcers, income, and level results

Implemented on `Test`. `mark` is unchanged by this implementation.

## Play the sample

Run `3D/Scenes/World/GameMap.tscn` or press Play in the main menu.

- The passenger going to **North Terminal** has **Legal Pickup** disabled. The other pickup is legal.
- **School** has **Legal Dropoff** disabled. North Terminal is legal.
- `TrafficEnforcers/PickupEnforcer` watches the pickup area. `SchoolEnforcer` watches School.
- Stopping for an illegal pickup or starting an illegal drop-off triggers the nearest idle enforcer with range and line of sight. An illegal stop without a witness carries no penalty.
- The whistle plays first. The enforcer approaches using the existing passenger obstacle pathfinder. Stop and remain near it through its dialogue to accept the ticket. Driving away interrupts ticketing and starts pursuit.
- A ticket adds **₱300 in deferred fines and +1 violation point**. Escaping beyond the post's pursuit radius adds **+2 points and no fine**. Each later witnessed evasion adds another two points.
- The enforcer returns to the position where its scene was placed, then becomes available again. A blocked approach to a driver who stayed put times out without falsely counting an evasion.

## Add enforcers to another map

Drag `3D/Scenes/NPC/TrafficEnforcer.tscn` into the level, position it on clear walkable ground, and duplicate as needed. No hard-coded map node paths are required.

Scene tree:

```text
TrafficEnforcer (CharacterBody3D, traffic_enforcer.gd)
├── PassengerVisual (existing layered animated character)
├── CollisionShape3D
├── Whistle (AudioStreamPlayer3D, SFX bus)
└── Status (Label3D)
```

The blue-tinted uniform and status label distinguish it from passengers. Replace the visual or whistle resource as desired, retaining the named children/interfaces. The bundled whistle is an original synthesized two-tone WAV.

Inspector settings:

| Setting | Default | Purpose |
| --- | --- | --- |
| Detection Radius | 14 | Maximum distance for witnessing a stop; walls block sight |
| Pursuit Radius | 28 | Distance from the initial post beyond which the driver escapes |
| Pursuit Timeout | 20 seconds | Limits stalled chases; stationary drivers are not penalized for an unreachable approach |
| Walk Speed | 3.5 | Approach, pursuit, and return speed |
| Path Refresh Interval | 0.7 seconds | Frequency of obstacle path recalculation |
| Ticket Distance | 1.5 | Distance from the vehicle's boarding point for ticket delivery |
| Alert Duration | 0.6 seconds | Whistle lead-in |
| Ticket Duration | 1.5 seconds | Minimum stopped acceptance time; the dialogue must also finish |
| Ticket Dialogue | “Akala mo lusot ka, boss? ₱300 'yan!” | Cocky ticket line, shown before the fine is recorded |
| Whistle Sound | Bundled WAV | Replaceable AudioStream |

Pursuit radius is clamped to at least detection radius. Multiple nearby enforcers claim one encounter per vehicle, avoiding duplicate tickets for the same pickup/drop-off.

`Passenger` exposes **Stop Rules → Legal Pickup** and **Is Mission Passenger**. `PassengerDestination` exposes **Stop Rules → Legal Dropoff**. Legality defaults to legal. Existing passengers default to mission passengers; disable that flag for optional fares.

## Economy and progression

All balances use integer centavos; fractional fuel charges accumulate before rounding so a higher frame rate does not increase the price.

- A fresh campaign starts with **₱100**. Each passenger removed from the onboard manifest at its matching drop-off earns **₱15**, exactly once.
- Refueling still requires the vehicle to stop in a station marker. Fuel increases gradually and cash decreases with fuel actually added. Full tanks, moving vehicles, and empty wallets incur no charge. Overlapping markers cannot multiply the rate.
- Stations expose **Refuel Rate** (default 10 fuel units/second) and **Price Per Fuel Unit** (centavos; default 200 = ₱2). The HUD shows the price when inside a station.
- A ticket does not immediately spend cash. Cash remains available for fuel until the level ends.
- Completion deducts fines from available cash, including the opening balance. The results show starting cash, passenger earnings, fuel purchases, total fines, net income, carried cash, persistent violation points, tickets, and evasions.
- **Net income = passenger earnings − fuel purchases − total fines.** It can be negative. **Cash carried forward** is the actual nonnegative remaining wallet balance.
- If cash cannot cover all fines, cash becomes zero and the **next level starts at 75% of maximum fuel**. The unpaid shortfall is cleared in exchange for that one-level penalty; it is not collected twice. A later unaffordable fine can impose a new penalty.
- Cash, points, and pending fuel penalties carry into the next level **only within the current run**. No campaign data is read from or written to disk. Old `user://campaign.cfg` files from earlier builds are ignored.
- Retrying an unfinished level restores that level's opening cash, points, and fuel penalty. This avoids repeated fare farming.
- A fresh game process, main-menu **Play**, or results-screen **Drive again** starts a fresh run with **₱100, zero violations, and no fuel penalty**. Closing the game or stopping it in Godot ends the run.

## Completion and UI nodes

`MissionManager` counts the scene's designated mission passengers at initialization. Completion occurs after they actually reach their destination entry points, and after any active enforcement and dialogue finish. Levels with no designated mission passengers do not auto-complete.

New `GameMap` nodes:

```text
GameMap
├── TrafficEnforcers
│   ├── PickupEnforcer
│   └── SchoolEnforcer
└── HUD
    ├── EconomyHUD
    └── LevelResults
```

The old `HUD/MissionComplete` instance is replaced by `HUD/LevelResults`; the original completion scene/script remain available for legacy scenes. `HUD/MissionFailed` is retained. `PauseMenu.results_window` and `MissionManager.results_window` reference the new results control.

For another level, instance the HUD/results scenes, add/configure its mission manager and passengers, and assign the manager's **Next Level Scene**. With no next level assigned, the button reads **Drive again** and replays the current map as a fresh run with ₱100 and zero violations. No second level was invented.

The pause menu cannot unpause a completed level behind the results screen. Returning to the main menu retains the earlier dialogue cleanup fix. Dialogue lives on its own persistent CanvasLayer above the level HUD. A cancelable frame-driven state machine replaces delayed dialogue callbacks; replay, retry, and level initialization clear the previous dialogue before starting again.

## File inventory

Added:

- `3D/Scripts/Singleton/GameSession.gd` — economy carried between levels in a run, incident ownership, ticket/evasion accounting, settlement; registered as an autoload in `project.godot`.
- `3D/Scripts/NPC/traffic_enforcer.gd` and `3D/Scenes/NPC/TrafficEnforcer.tscn` — modular NPC and state machine.
- `3D/Scripts/HUD/economy_hud.gd` and `3D/Scenes/HUD/EconomyHUD.tscn` — cash, pending fines, points, remaining mission passengers, enforcement notices, station pricing.
- `3D/Scripts/HUD/level_results.gd` and `3D/Scenes/Menu/LevelResults.tscn` — results, next-level/replay, main-menu actions.
- `3D/Assets/Audio/enforcer_whistle.wav` and its `.import` metadata.
- Godot `.uid` sidecars for new scripts.
- `tests/test_traffic_economy.gd` — headless economy and enforcement integration coverage.
- `tests/test_replay_lifecycle.gd` — fresh-process, replay, next-level, menu, retry, and dialogue-overlay regressions.
- `docs/traffic-enforcer.md` — this setup guide and change inventory.

Modified:

- `3D/Scenes/World/GameMap.tscn` — example enforcers, illegal stop settings, new UI instances and node references.
- `3D/Scripts/NPC/passenger.gd` — inspector flags, illegal pickup report, mission arrival notification.
- `3D/Scripts/NPC/passenger_destination.gd` — legal drop-off flag.
- `3D/Scripts/Player/player3D.gd` — mission flag in the onboard manifest, illegal drop-off report, one fare per disembarkation.
- `3D/Scripts/Environment/refuelingarea.gd` — inspector price and paid fuel purchases.
- `3D/Scripts/Mission/mission_manager.gd` — level initialization, mission delivery tracking, completion settlement, results integration.
- `3D/Scripts/Menu/pause_menu.gd` — prevent resuming behind results.
- `3D/Scripts/Singleton/DialogueManager.gd` — dedicated overlay and cancelable dialogue playback across replay/retry.
- `3D/Scripts/Menu/main_menu.gd` — start a fresh campaign when Play is pressed.
- `project.godot` — GameSession autoload.

The previously deferred NPC traffic-height issue remains untouched.

## Verification

The headless integration test exercises real player, station, enforcer, passenger, GameMap, and result scenes. It covers fares, movement/full-tank/no-cash fuel rules, fractional billing, overlapping stations, sight obstruction, nearest-enforcer ownership, duplicate incident prevention, approach and return movement, accepted tickets, repeated evasions, settlement, next-level fuel penalties, retries, legal/illegal pickup and drop-off wiring, and results/pause behavior.

Run after importing the project:

```sh
godot --headless --editor --import --path .
# Use a disposable XDG_DATA_HOME for test data, including the legacy-save fixture.
XDG_DATA_HOME="$PWD/work/test-runtime/data" godot --headless --path . --script tests/test_traffic_economy.gd
XDG_DATA_HOME="$PWD/work/test-runtime/data" godot --headless --path . --script tests/test_replay_lifecycle.gd -- --seed-legacy
XDG_DATA_HOME="$PWD/work/test-runtime/data" godot --headless --path . --script tests/test_replay_lifecycle.gd
# Repeat the last command as a second process: no prior run should persist.
```

Validated with Godot 4.6.3. The project declares 4.7; visual appearance, whistle volume, and final difficulty should be playtested in the target editor.
