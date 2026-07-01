# orbits

[![test](https://github.com/kojix2/orbits/actions/workflows/test.yml/badge.svg)](https://github.com/kojix2/orbits/actions/workflows/test.yml)
[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Forbits%2Flines)](https://tokei.kojix2.net/github/kojix2/orbits)

Strange attractors, rendered directly in the terminal.

## Install

```sh
shards build --release -Dexecution_context
cp bin/orbits ~/.local/bin
```

## Draw

```sh
orbits
orbits clifford
orbits dejong
orbits ikeda
orbits hopalong
```

Without an attractor subcommand, `orbits` randomly selects the attractor. The
parameters and colormap are randomized with or without a subcommand. Use
`--seed N` to reproduce the complete selection.

Tune the orbit when you want the image back:

```sh
orbits clifford --seed 42 --points 10M --size 720x720
orbits clifford --abcd -1.3,-1.3,-1.8,-1.9 --orbits 4
orbits ikeda --u 0.9 --colormap ice
orbits hopalong --seed 2026 --print-params
```

Save instead of displaying:

```sh
orbits clifford --output orbit.png
orbits dejong --output orbit.six
```

Display as Unicode text when terminal graphics are unavailable:

```sh
orbits dejong --protocol braille --size 160x80
orbits dejong --protocol shades --size 80x40
```

Braille and shades output use Unicode text with ANSI truecolor. Braille defaults
to a 120x120 raster and shades to 60x30; an explicit `--size` always takes
precedence. `--colormap turbo` and every other colormap color both text modes.

## Controls

```text
--points N          K/M/G suffixes accepted
--orbits N          independent nearby starts
--size WxH          raster size (640x640; Braille: 120x120; shades: 60x30)
--window X1,X2,Y1,Y2
--xform NAME        boolean, linear, log, loglog, cubic, equalized
--colormap NAME     gray, ice, fire, gr8, turbo
--protocol NAME     auto, iterm2, kitty, sixel, braille, shades
--seed N            reproduce random selection
```

Attractor coefficients live on their subcommands:

```text
clifford --a A --b B --c C --d D
clifford --abcd A,B,C,D
dejong --a A --b B --c C --d D
ikeda --u U
hopalong --a A --b B --c C
```

`orbits --detect` shows the terminal graphics protocol that will be used. Auto
detection falls back to colored Braille unless the environment indicates
iTerm2, Kitty, or SIXEL support.

For formulas, defaults, and every flag:

```sh
orbits clifford --help
```
