# pokemon-randomizer

A Pokémon Rom randomizer tool written in Zig

For now, this project exists for me to test out the [Zig](http://ziglang.org/)
programming language and its features.

## Supported games

Each Pokémon game exists in multiple different languages. The reason this is important is that different languages have different data layouts. The Japanese version of Pokémon Emerald might not work with the randomizer even though a US version does.

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
| Ruby        |                    | :heavy_check_mark: |
| Sapphire    |                    | :heavy_check_mark: |
| Emerald     |                    | :heavy_check_mark: |
| Fire Red    |                    | :heavy_check_mark: |
| Leaf Green  |                    | :heavy_check_mark: |
|             |                    |                    |
| Diamon      |                    | :heavy_check_mark: |
| Pearl       |                    | :heavy_check_mark: |
| Platinum    |                    | :heavy_check_mark: |
| Heart Gold  |                    | :heavy_check_mark: |
| Soul Silver |                    | :heavy_check_mark: |
|             |                    |                    |
| Black       | :heavy_check_mark: |                    |
| White       | :heavy_check_mark: |                    |
| Black 2     | :heavy_check_mark: |                    |
| White 2     | :heavy_check_mark: |                    |

## Build

The randomizer relies on libraries which are included as git submodules. You,
therefore, need to clone with `--recursive`, in order to get these libraries on
clone.

The repo contains both the Pokémon randomizer, but also a few tools used to make
development of the randomizer a little simpler.

Here are the different build commands:

* `zig build randomizer` builds the randomizer (default).
* `zig build tools` builds the tools.
* `zig build test` runs all tests.
* `zig build all` builds everything and runs all tests.

## Resources

Useful links with information on the structure of roms, or where data exists in different Pokémon games.

### Roms

* [Gameboy Advance / Nintendo DS / DSi - Technical Info](http://problemkaputt.de/gbatek.htm)
* [Pan Doc (Gb info)](http://gbdev.gg8.se/files/docs/mirrors/pandocs.html)
* [Nds formats](http://www.romhacking.net/documents/%5B469%5Dnds_formats.htm)

### Gen 1

### Gen 2

### Gen 3

* [Pokémon Emerald Offsets](http://www.romhack.me/database/21/pok%C3%A9mon-emerald-rom-offsets/)

### Gen 4

* [HGSS File System](https://projectpokemon.org/docs/gen-4/hgss-file-system-r21/)
* [HG/SS Mapping File Specifications](https://projectpokemon.org/home/forums/topic/41695-hgss-mapping-file-specifications/?tab=comments#comment-220455)
* [HG/SS Pokemon File Specifications](https://projectpokemon.org/home/forums/topic/41694-hgss-pokemon-file-specifications/?tab=comments#comment-220454)
* [HG/SS Encounter File Specification](https://projectpokemon.org/home/forums/topic/41693-hgss-encounter-file-specification/?tab=comments#comment-220453)

### Gen 5

* [BW2 File System](https://projectpokemon.org/docs/gen-5/b2w2-file-system-r8/)
* [BW Trainer data](https://projectpokemon.org/home/forums/topic/22629-b2w2-general-rom-info/?do=findComment&comment=153174)
* [BW Move data](https://projectpokemon.org/home/forums/topic/14212-bw-move-data/?do=findComment&comment=123606)

### All Gens

* [Bulbapedia on Pokemon Data Structures](https://bulbapedia.bulbagarden.net/wiki/Category:Structures)
* [Pokemon Game Disassemblies](https://github.com/search?utf8=%E2%9C%93&q=Pokemon+Disassembly&type=)
