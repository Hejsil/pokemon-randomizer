# pokemon-randomizer

A Pokémon Rom randomizer tool written in Zig

For now, this project exists for me to test out the [Zig](http://ziglang.org/)
programming language and its features.

## Supported games

* :heavy_check_mark: means that the game is implemented in code and is completable without any major issues.
* :heavy_minus_sign: means that the game is implemented in code but haven't been tested.

| Version:    | International (O)  | English/USA (E)    |
|-------------|--------------------|--------------------|
| Red         |                    |                    |
| Blue        |                    |                    |
| Green       |                    |                    |
| Yellow      |                    |                    |
| Gold        |                    |                    |
|             |                    |                    |
| Gold        |                    |                    |
| Silver      |                    |                    |
| Crystal     |                    |                    |
|             |                    |                    |
| Ruby        |                    | :heavy_minus_sign: |
| Sapphire    |                    | :heavy_minus_sign: |
| Emerald     |                    | :heavy_check_mark: |
| Fire Red    |                    | :heavy_minus_sign: |
| Leaf Green  |                    | :heavy_minus_sign: |
|             |                    |                    |
| Diamon      |                    |                    |
| Pearl       |                    |                    |
| Platinum    |                    |                    |
| Heart Gold  |                    |                    |
| Soul Silver |                    |                    |
|             |                    |                    |
| Black       |                    |                    |
| White       |                    |                    |
| Black 2     | :heavy_minus_sign: |                    |
| White 2     |                    |                    |

## Build

The randomizer relies on libraries which are included as git submodules. You,
therefore, need to clone with `--recursive`, in order to get these libraries on
clone.

The repo contains both the Pokémon randomizer, but also a few tools used to make
development of the randomizer a little simpler.

Here are the different build commands:

* `zig build randomizer` builds the randomizer.
* `zig build tools` builds the tools.
* `zig build test` runs all tests.
* `zig build` builds everything and runs all tests.

## Useful Links

Useful documentation of the Pokémon data and Rom file structure.

* [BW2 File System](https://projectpokemon.org/docs/gen-5/b2w2-file-system-r8/)
* [HGSS File System](https://projectpokemon.org/docs/gen-4/hgss-file-system-r21/)
* [Gameboy Advance / Nintendo DS / DSi - Technical Info](http://problemkaputt.de/gbatek.htm)
* [Pan Doc (Gb info)](http://gbdev.gg8.se/files/docs/mirrors/pandocs.html)
* [Bulbapedia on Pokemon Data Structures](https://bulbapedia.bulbagarden.net/wiki/Category:Structures)
* [Pokemon Game Disassemblies](https://github.com/search?utf8=%E2%9C%93&q=Pokemon+Disassembly&type=)
* [Pokémon Emerald Offsets](http://www.romhack.me/database/21/pok%C3%A9mon-emerald-rom-offsets/)
* [Nds formats](http://www.romhacking.net/documents/%5B469%5Dnds_formats.htm)
