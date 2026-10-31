# The Second Sight code: assemble each source, place the sections, link.
#
# scripts/game.py runs the whole build: it writes the generated sources and
# the layout inputs into build/card/gen, then runs "make card". After that,
# "make card" alone builds build/card/card.elf again from changed sources.
# The sound stage (scripts/sound_assets.py) runs "make sound-renderer".

PYTHON ?= $(if $(wildcard .venv/bin/python),.venv/bin/python,python3)
Z80 ?= z80-elf-

CARD := build/card
CARD_GEN := $(CARD)/gen
-include $(CARD_GEN)/sources.mk
CARD_OBJECTS := $(patsubst src/card/%.s,$(CARD)/%.o,$(wildcard src/card/*.s)) \
	$(patsubst %,$(CARD)/gen_%.o,$(GENERATED))
ASFLAGS := -march=z180 --fatal-warnings -I src/card/include -I $(CARD_GEN)
LDFLAGS := -L $(CARD_GEN) --no-check-sections --no-warn-rwx-segments --orphan-handling=error

.PHONY: card sound-renderer
card: $(CARD)/card.elf

# The YM2203 renderer of the sound stage (scripts/sound_assets.py).
SOUND := build/sound
YMFM := third_party/ymfm/src
sound-renderer: $(SOUND)/ym_stems

$(SOUND)/ym_stems: scripts/ym_stems.cpp $(wildcard $(YMFM)/*)
	mkdir -p $(SOUND)
	$(CXX) -std=c++17 -O2 -I $(YMFM) -o $@ scripts/ym_stems.cpp $(YMFM)/ymfm_ssg.cpp $(YMFM)/ymfm_adpcm.cpp

$(CARD)/%.o: src/card/%.s
	$(Z80)as $(ASFLAGS) --MD $(@:.o=.d) -o $@ $<

$(CARD)/gen_%.o: $(CARD_GEN)/%.s
	$(Z80)as $(ASFLAGS) --MD $(@:.o=.d) -o $@ $<

$(CARD)/card.ld: $(CARD_OBJECTS) src/card/memory.toml src/card/variables.ld \
		$(CARD_GEN)/layout.json $(CARD_GEN)/defines.ld $(CARD_GEN)/formulas.ld \
		scripts/card_layout.py
	$(PYTHON) scripts/card_layout.py $(CARD) $(CARD_OBJECTS)

$(CARD)/card.elf: $(CARD)/card.ld
	$(Z80)ld $(LDFLAGS) -T $< -Map $(CARD)/card.map -o $@ $(CARD_OBJECTS)

-include $(CARD_OBJECTS:.o=.d)
