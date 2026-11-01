/* The places of the Second Sight memory map that the asset builder needs
   before the link: the world packets write into them, and they are packed
   (scripts/world_rows.py, scripts/combined_world.py). secondsight.ld includes
   this file; the Makefile links it alone (build/secondsight/fixed.elf) for
   the asset builder. */

scratch__run = 0x3400;                  /* the time-shared scratch page: the world upload buffer starts it */
world_side0__load = 0x114800;           /* the column descriptors of side 0 */
world_side1_low__load = 0x11B400;       /* the column descriptors of side 1: two fragments */
world_side1_high__load = 0x11BB00;
