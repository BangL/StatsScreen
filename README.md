# Stats Screen

A lifetime statistics screen for RAID: World War II (SuperBLT mod).

Adds a **Statistics** entry to the options list of the Raid menu. The screen shows what the game's `StatisticsManager` already records for your profile, but never displays:

- **Overview** - play time, sessions, kills, headshot rate, shots fired / hit, accuracy, reloads, revives, downs, deaths, objectives, dog tags, loot crates, ...
- **Weapons** - kills, headshot rate and accuracy per weapon
- **Melee weapons** and **grenades** - kills per item
- **Enemies** - kills and headshot rate per enemy type (weapon variants are summed up)
- **Missions** - started, completed, quit and time played per mission
- **Characters played**

## Requirements

- [RAID-SuperBLT](https://github.com/RAIDModding/RAID-SuperBLT) with the Lua base (`mods/base`) 2.0.3 or newer

## Installation

Put the `StatsScreen` folder into `mods/`.

## Notes

- Languages: English and German. Add a `loc/<language>.json` and an entry in `supermod.xml` for more.
- Statistics are read from the loaded profile. Turret kills of flak guns are not tracked by the game and therefore not shown.
- Mission entries with the id `fake_mission*` are hidden, `ger_bridge_operation` is summed up with `ger_bridge`.

## License

Author: BangL
