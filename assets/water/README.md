# Stage water texture

`stage-water-4x30.json` is the texture of the stage water (the dark sea with
fine dots over soft waves). It is project-made data, not ROM data: it holds
only pattern entries and arcade colour numbers. The build reads it; the build
does not run the script below.

## Why the texture has this form

The port does not redraw water pixels while the sea moves. Each water pixel
keeps one of 120 palette entries, and the card rotates those entries one step
per picture (`scripts/game_water.py`). So the texture is 4 patterns of 30
entries; each of 60 repeating screen columns uses one pattern at its own
offset:

    pixel(sea line y, column x) = patterns[column_pattern[x % 60]][(y + column_offset[x % 60]) % 30]

Each entry is 0, 1 or 2: the arcade water colours `arcade_colour_index`
(dark, mid, light). The build takes their RGB values from the ROM palette.

## How it was made

`make_water.py` fits the texture to the arcade's stage water, read from your
ROM (the first 64x64 block of the sea map):

1. Blur the arcade water (sigma 1.5) to get its wave picture, and resize it to
   60 lines with a Fourier resize.
2. Group the 60 columns into 4 wave profiles, each column with its own offset.
3. With simulated annealing, choose each pattern entry so that the blurred
   texture matches the wave picture, the dots sit next to each other as the
   arcade dots do, and neighbour columns do not copy each other. The mix of the
   three colours stays exactly the arcade's.

Settings: 4 patterns of 30 entries, 60 columns, random seed 1, 300,000 steps,
dot weight 2.0, copy penalty 0.05.

    .venv/bin/python assets/water/make_water.py [output.json]

Without an argument it writes `assets/water/stage-water-4x30.json`. A run takes
about 4 minutes and gives the same file every time.
