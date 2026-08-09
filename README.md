# orbits

[![test](https://github.com/kojix2/orbits/actions/workflows/test.yml/badge.svg)](https://github.com/kojix2/orbits/actions/workflows/test.yml)
[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Forbits%2Flines)](https://tokei.kojix2.net/github/kojix2/orbits)

Strange attractors, rendered directly in the terminal.

## Install

```sh
shards build --release -Dexecution_context
cp bin/orbits ~/.local/bin
```

`-Dexecution_context` is required so multi-orbit rendering uses Crystal's
parallel execution context. The build intentionally fails when it is omitted.

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
`--seed N` to reproduce the complete selection. Interactive runs show the
generated seed in the render status, and `--print-params` includes it too.

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

## Animate

Reveal the attractor, follow a moving trail, or morph its coefficients:

```sh
orbits clifford --seed 42 --animate reveal
orbits dejong --animate trail --trail 10K --duration 8
orbits ikeda --u 0.9 --animate morph --morph-amount 1.5
```

For `reveal` and `trail`, `--points` is the total calculation budget divided
across the requested duration. `reveal` accumulates all points, while `trail`
retains only the newest `--trail` points. Their default budgets are 10M and
100K points, respectively. For `morph`, `--points` is the budget for each
independent frame; its default is 1M points. Morph previews the full
coefficient loop once, reduces unstable motion when necessary, and uses one
fixed window that contains the complete loop. Frames are redrawn in the
terminal's alternate screen. Press Ctrl-C to stop early and keep the current
frame. Redirected stdout falls back to one static frame. Animation output files
are not supported yet.

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
--animate MODE      reveal, trail, morph
--fps N             animation frame rate (12)
--duration SECONDS  animation duration (5)
--trail N           points retained by trail mode (10K)
--morph-amount N    coefficient motion multiplier (1.0)
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
