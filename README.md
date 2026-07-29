# Giorgione's Feast

A portrait, offline Godot 4 roguelite fan-game prototype: gather ingredients, cook upgrades, and impress the dinner guests.

## Run locally

1. Install **Godot 4.3 or newer** with Android and iOS export templates if you need device builds.
2. Import this folder through Godot's Project Manager.
3. Open `scenes/Main.tscn` or press **F6/F5** to run.

Desktop controls: **WASD / arrow keys** move and the on-screen `SCATTO` button (or touch) dashes. On a phone, drag in the bottom-left area to use the virtual joystick; attacks auto-target the closest enemy.

## Included vertical slice

- Three timed areas: Orto, Bosco dei Funghi, Vigneto.
- A scrolling semi-infinite world with a smooth player-follow camera and deterministic pixel-art biome tiles.
- Five enemies, including the Ispettore Sanitario miniboss.
- Ingredient pickups and four cookable recipes: Caprese, Tagliatelle, Polenta, Porchetta.
- Local cookbook/best-score persistence in `user://giorgiones_feast_save.json`.
- Object pools for enemy/projectile dictionaries and editable `Resource` data for enemies, recipes, ingredients, and zone rewards.
- Original editable SVG source art in [`assets/README.md`](assets/README.md).

## Mobile export notes

Set Android package/signing details in Godot's Export panel and configure an Apple development team on macOS/Xcode for iOS. Test safe areas and touch behavior on a real 16:9 and tall-device screen before release.

This is an unofficial fan work. Do not publish using a person's likeness, logo, name, or copyrighted media without the relevant permission.
