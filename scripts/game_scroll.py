"""Two retained display pages, with the dominant layer selected by map stretch.

Both 256-row copies hold the background. Sprite/HUD damage is repaired from
source art before the next use. The scroll origin is continuous across layer
changes, so a choice change does not require copying a complete picture.
"""

CODE = 0xB000
MAPS = 0x5A00
PRIMARY_MODES = 0x2BBC
MODE = 0x2BC4
SEA = 0x2BC8
ROW = 0x2BCA
LO = 0x2BCB
HI = 0x2BCC
DEST0 = 0x2BD0
DEST1 = 0x2BD2
LEFT = 0x2BD4
RIGHT = 0x2BD5
OFFSET = 0x2BD6
PREV = 0x2BD7
MASK = 0x2BEA
BEG = 0x2BD9
END = 0x2BD9
SOURCE = 0x2BDC
RUN_SRC = 0x2BDE
DAMAGE = 0x2BE0
DEFER_SEA = 0x2BF2
FORCE_FG = 0x2BE2
PASS = 0x2BE3
TWIN = 0x2BE8
SEGMENT = 0x2BE9


