/* The memory map of the Second Sight program (Z180), for GNU ld.

   Addresses
   - The VMA of an output section is its Z180 logical address: the address
     that the code uses. The LMA is its load address: load_sram + the physical
     SRAM address.
   - In the game, game_cbar makes logical $0000-$BFFF common area 0: there the
     physical address is the logical one. The bank area $C000-$DFFF (BBR) and
     common area 1 $E000-$FFFF (CBR) show other SRAM pages.
   - A data section without a run address has VMA = LMA: its labels are load
     addresses, and the code reads it through BBR or CBR.
   - An LMA at load_packets + VMA is code or data that no load record writes:
     the IIgs sends it later in a packet (the helpers), or the entry copies it
     (the runtime block). secondsight_link.region_image gives its bytes.

   Loading
   - An output section with data loads every byte from its start to its end:
     the variables (.vars sections) inside it load as zero.
   - An output section of variables only (NOLOAD) loads nothing: its
     variables start undefined. One that follows data starts at "." so that
     ld does not align its start to its largest input section.

   Free space
   - scripts/secondsight_fit.py puts the asset sections into free space: .desc
     (FIT_RECORD), .fonts (FIT_ENTRIES), .cab_group (FIT_GROUP), .cab_rows
     (FIT_ROWS), .common (FIT_COMMON), and .vram and .plane into free video
     RAM. Each free space NAME below gives it:
       fit_NAME__start, fit_NAME__end  its load addresses [start, end)
       fit_NAME__label                 the label of a record at its start
       fit_NAME__kinds                 the kinds of sections that it takes
       fit_NAME__align, fit_NAME__view (optional) the alignment of its start,
                                       and the run address of its 8 KB view
   - The Makefile links twice: the first link (fitting/placements.ld parks the
     asset sections) gives the free space; secondsight_fit.py writes placements.ld for
     the final link. */

INCLUDE defines.ld
INCLUDE fixed.ld

load_sram = 0x100000;           /* load address of SRAM byte 0 */
load_packets = 0x400000;        /* load addresses that no load record writes */

/* The MMU windows and the VGA window (src/secondsight/include/second_sight.inc). */
bank_window = 0xC000;           /* the bank area (BBR), 8 KB */
bank_window_upper = 0xD000;     /* its upper 4 KB */
common1_window = 0xE000;        /* common area 1 (CBR) */
vga_window = 0xA0000;           /* the Oak VGA window */
vga_window_bbr = (vga_window - bank_window) >> 12;      /* the BBR of the VGA window at bank_window */

/* The Z180 MMU setting of the game (the IIgs sends it with SS_RUN_CODE).
   CBAR: the bank area starts at logical $2000, common area 1 at $C000.
   BBR: the bank area $2000-$BFFF is logical + $10000 in SRAM.
   CBR: common area 1 $C000-$FFFF is logical + $84000. */
game_cbar = 0xC2;
game_bbr = 0x10;
game_cbr = 0x84;

vram_null = 0x0;                /* video RAM address 0: no art */

/* The kinds of asset sections (scripts/secondsight_fit.py). */
FIT_RECORD = 0x01;      /* banked data read through the bank area; stays in one 4 KB page */
FIT_ENTRIES = 0x02;     /* banked data copied in 16-byte pieces through the 8 KB bank area */
FIT_GROUP = 0x04;       /* a glyph group program: common SRAM, or the pattern view */
FIT_ROWS = 0x08;        /* the glyph row programs: the pattern view */
FIT_COMMON = 0x10;      /* data or code that the CPU reads at its physical address */

/* SRAM that the firmware uses until the entry code runs: page C, the
   SetPalette buffer, and the firmware ranges after the vectors, the SRAM test
   byte, the RST 38 body, the debug RETs and the stack at $032E-$03FF. The
   build loads their bytes into the video RAM staging area; the entry staging
   copies them in place. The menu entry saves low SRAM and rebuilds the ROM
   image; the menu return restores it. */
staged_0__start = 0x10C000; staged_0__end = 0x10D000;
staged_1__start = 0x10F000; staged_1__end = 0x10F300;
staged_2__start = 0x100004; staged_2__end = 0x100038;
staged_3__start = 0x10003C; staged_3__end = 0x100080;
staged_4__start = 0x100080; staged_4__end = 0x1001FC;
staged_5__start = 0x100208; staged_5__end = 0x10032A;
staged_6__start = 0x100A00; staged_6__end = 0x100C00;

/* The two packet receive buffers (stream.s): DMA channel 1 fills one while
   the card draws from the other, PACKET_AREA bytes (src/packet_layout.inc).
   The helpers of the hitch stage and the specials, and the menu bootstrap,
   run in the buffer that does not receive. */
packet_buffer_0__run = 0x4000; packet_buffer_0__limit = 0x4700;
packet_buffer_1__run = 0x8000; packet_buffer_1__limit = 0x8700;
/* The high bytes, for data (.byte cannot take a shifted symbol). */
packet_buffer_0__high = packet_buffer_0__run >> 8;
packet_buffer_1__high = packet_buffer_1__run >> 8;

/* XOR with the high byte of one packet buffer gives the other: the two high
   bytes have no common bit (checked below). */
stream_other = (packet_buffer_0__run + packet_buffer_1__run) >> 8;

/* The menu helper slot, one 4 KB page (menu_mirror.s): the enter or restore
   helper (it runs at $E000, sections .mirror_enter and .mirror_restore), then
   the saved palette and registers. It is the first page of .ready_rows: the
   IIgs saves the page first and puts it back last. */
mirror_helper__load = 0x11C000; mirror_helper__size = 0x800;
mirror_buffer__load = 0x11C800; mirror_buffer__limit = 0x11D000;

SECTIONS
{
  /* ---- Common SRAM below $C000: logical = physical ---- */

  /* Firmware ranges that are free after the entry. */
  fit_firmware_0004__start = 0x100004; fit_firmware_0004__end = 0x100038;
  fit_firmware_0004__label = 0x100004; fit_firmware_0004__kinds = FIT_COMMON;
  fit_firmware_003c__start = 0x10003C; fit_firmware_003c__end = 0x100080;
  fit_firmware_003c__label = 0x10003C; fit_firmware_003c__kinds = FIT_COMMON;
  fit_firmware_0080__start = 0x100080; fit_firmware_0080__end = 0x1001FC;
  fit_firmware_0080__label = 0x100080; fit_firmware_0080__kinds = FIT_COMMON;
  fit_firmware_0208__start = 0x100208; fit_firmware_0208__end = 0x10032A;
  fit_firmware_0208__label = 0x100208; fit_firmware_0208__kinds = FIT_COMMON;

  .entry 0x0400 : AT(0x100400) {
    *(.text.entry_begin)
    *(.text.entry_mode)
    *(.text.entry_end)
    *(.text.entry_staging)
    *(.text.cache_boot_clear)
    *(.rodata.cache_boot_clear_ranges)
    *(.text.entry_staging_done)
  }
  ASSERT(. <= 0x0A00, "the entry code reaches $0A00")

  /* The runtime block: the entry staging copies it over the entry mode table
     and the setup code before monitor_timing_ready, which do not run again. */
  .entry_runtime 0x0441 : AT(load_packets + 0x0441) {
    *(.text.quiet_art_load)
    *(.text.ship_one_fast)
    *(.text.wrap_repair_guard)
  }
  entry_runtime__run = ADDR(.entry_runtime);
  entry_runtime__end = ADDR(.entry_runtime) + SIZEOF(.entry_runtime);
  entry_runtime__size = SIZEOF(.entry_runtime);
  ASSERT(entry_runtime__end <= 0x064F, "the runtime block reaches $064F")

  fit_firmware_0a00__start = 0x100A00; fit_firmware_0a00__end = 0x100C00;
  fit_firmware_0a00__label = 0x100A00; fit_firmware_0a00__kinds = FIT_COMMON;

  /* The planner and HUD variables, in the page under the planner code. */
  .planner_variables 0x0C00 (NOLOAD) : {
    *(.vars.scene)
    *(.vars.hud_planner)
    *(.vars.priority)
    *(.vars.rect_masks)
    *(.vars.rows_world_row)
  }
  ASSERT(. <= 0x0D00, "the planner variables reach $0D00")

  /* The planner: it loads at $4400 and the entry staging copies it to $0D00,
     where the firmware runs until the entry. */
  .state_planner 0x0D00 : AT(0x104400) {
    *(.text.native_fg_row)
    *(.text.cache_bindings)
    *(.text.cache_resolve)
    *(.text.cache_source_lookup)
    *(.text.state_plan_a)
    *(.text.background_plan)
    *(.text.state_plan_b)
    *(.text.weapon_values)
    *(.text.weapon_values_p2)
    *(.text.state_plan_c)
    *(.text.hud_batch)
    *(.text.hud_damage)
    *(.rodata.hud_bounds)
    *(.text.planner_hitch_bridges)
    *(.text.object_priority)
    *(.text.object_compiled)
    *(.text.object_trim_vertical)
    *(.text.native_hud_pattern)
    *(.text.water_camera)
    *(.text.background_camera)
    *(.text.background_delta)
    *(.text.ship_column_draw)
    *(.text.background_anchor_camera)
    *(.text.world_rows_cache)
    *(.text.world_scatter)
    *(.text.world_upload_done)
    *(.text.cabinet_rank_load)
    *(.text.cabinet_regular_field)
    *(.text.combined_descriptor_select)
    *(.text.special_draw_bridge)
    *(.text.hitch_scene_common)
    *(.text.repair_core_registers)
  }
  state_planner__run = ADDR(.state_planner);
  state_planner__load = LOADADDR(.state_planner);
  state_planner__size = 0x2000 - state_planner__run;
  fit_planner_tail__start = LOADADDR(.state_planner) + SIZEOF(.state_planner);
  fit_planner_tail__end = state_planner__load + state_planner__size;
  fit_planner_tail__label = load_sram + ADDR(.state_planner) + SIZEOF(.state_planner);
  fit_planner_tail__kinds = FIT_RECORD | FIT_ENTRIES;

  /* The playfield code, then the variables of the scroll draw and the
     planner (zero at load). */
  .playfield 0x2000 : AT(0x102000) {
    *(.text.playfield_mode)
    *(.text.playfield)
    *(.text.game_world_receive)
    *(.text.canonical_masks)
    *(.text.object_compact_header)
    *(.text.state_object_order)
    *(.vars.family_staging)
    *(.data.row_offsets)
    *(.data.art_hash)
    *(.vars.combined_scroll)
    *(.data.bit_masks)
    *(.vars.water)
    *(.vars.background_motion)
    *(.vars.background_anchor)
    *(.vars.background_full)
    *(.data.scroll_column_key)
    *(.data.scroll_pan_applied)
    *(.vars.sea_features)
    *(.vars.ship_rows)
    *(.vars.ship_alignment)
    *(.vars.ship_columns)
    *(.vars.repair_core)
    *(.vars.hitch_water)
    *(.vars.hitch_stage)
    *(.vars.hud)
    *(.vars.playfield)
    *(.vars.stream)
    *(.vars.scene_kernel)
    *(.vars.object_kernel)
    *(.vars.glyph_kernel)
    *(.vars.special_scratch)
  }
  fit_row_gap__start = LOADADDR(.playfield) + SIZEOF(.playfield);
  fit_row_gap__end = 0x103400;
  fit_row_gap__label = load_sram + ADDR(.playfield) + SIZEOF(.playfield);
  fit_row_gap__kinds = FIT_COMMON;
  fit_row_gap__align = 16;

  /* The time-shared scratch page: one user at a time. */
  OVERLAY scratch__run : NOCROSSREFS AT(load_packets + scratch__run) {
    .scratch.upload { *(.vars.world_upload_buffer) }
    .scratch.object { *(.vars.object_stage) }
    .scratch.hud { *(.vars.hud_stream_scratch) }
    .scratch.sea { *(.vars.sea_bands) }
  }
  ASSERT(SIZEOF(.scratch.upload) <= 0x100 && SIZEOF(.scratch.object) <= 0x100
         && SIZEOF(.scratch.hud) <= 0x100 && SIZEOF(.scratch.sea) <= 0x100,
         "a user of the scratch page needs more than 256 bytes")

  playfield_code__run = 0x3500;
  .playfield.code playfield_code__run : AT(load_sram + playfield_code__run) {
    *(.text.scene_kernel)
    *(.text.stream)
    *(.text.glyph_kernel)
    *(.text.object_kernel)
    *(.text.ship_cpu_copy)
    *(.text.ship_cpu_column)
    *(.text.background_calls)
  }
  ASSERT(. <= 0x4000, "the playfield code reaches $4000")

  /* The helpers of the hitch stage and the specials, and the menu bootstrap:
     one copy for each packet buffer N; a copy runs in the buffer that does not
     receive. Their bytes are host packets (scripts/hitch_stage.py,
     scripts/special_wave.py, scripts/menu_mirror.py). */
  .hitch_stage_draw_0 0x4000 : AT(load_packets + 0x4000) {
    *(.text.hitch_stage_draw_buffer0)
    *(.rodata.hitch_stage_blocks_buffer0)
  }
  hitch_stage_draw_0__run = ADDR(.hitch_stage_draw_0);
  hitch_stage_draw_0__size = SIZEOF(.hitch_stage_draw_0);
  hitch_stage_draw_0__limit = 0x4300;
  ASSERT(. <= hitch_stage_draw_0__limit, "hitch stage helper 0 reaches its limit")
  .special_bolt_helper_0 0x4000 : AT(load_packets + 0x4000) { *(.text.special_bolt_draw_buffer0) }
  special_bolt_helper_0__run = ADDR(.special_bolt_helper_0);
  special_bolt_helper_0__size = SIZEOF(.special_bolt_helper_0);
  ASSERT(. <= 0x4300, "special bolt helper 0 reaches $4300")
  .special_wave_helper_0 0x4000 : AT(load_packets + 0x4000) { *(.text.special_wave_draw_buffer0) }
  special_wave_helper_0__run = ADDR(.special_wave_helper_0);
  special_wave_helper_0__size = SIZEOF(.special_wave_helper_0);
  ASSERT(. <= 0x4480, "special wave helper 0 reaches $4480")

  /* The hook jumps that the special packets write into the playfield and the
     planner. The run address is a placeholder: a jump holds its absolute
     target. */
  .special_hooks 0x4000 : AT(load_packets + 0x4000) { *(.text.special_hooks) }
  special_hooks__run = ADDR(.special_hooks);
  ASSERT(. <= 0x4006, "the special hooks reach $4006")

  /* The menu bootstrap, then its saved state in the packet buffer. The IIgs
     keeps the first 0x400 bytes of the packet as scratch, except the saved MMU
     bytes at mirror_saved (src/menu_mirror_host.s). */
  .mirror_bootstrap 0x4000 : AT(load_packets + 0x4000) { *(.text.mirror_boot) }
  ASSERT(. <= 0x4100, "the menu bootstrap reaches $4100")
  ASSERT(SIZEOF(.mirror_bootstrap) == 175, "the menu packet header (scripts/menu_mirror.py) is made for a 175-byte bootstrap")
  .mirror_state 0x4100 (NOLOAD) : { *(.vars.mirror) }
  ASSERT(. <= 0x4400, "the menu state reaches $4400")

  /* The drawing commands of a picture (scene_next runs them). */
  .commands 0x4800 (NOLOAD) : { *(.vars.commands) }
  ASSERT(. <= 0x5800, "the drawing commands reach $5800")

  .sprite_fast 0x5800 : AT(0x105800) {
    *(.text.sprite_fast)
    *(.text.cache_retire_art)
    *(.text.source_mask_entries)
  }
  ASSERT(. <= 0x5A00, "the fast sprite code reaches $5A00")

  /* The damage maps of the scroll draw (combined_scroll.s). */
  .damage_map_0 0x5A00 (NOLOAD) : { *(.vars.damage_map_0) }
  ASSERT(. <= 0x5C00, "damage map 0 reaches $5C00")

  /* The ship staging: the rectangle list of a ship column (ship_columns.s,
     scripts/ship_columns.py), or the repair core code (repair_core.s). */
  .ship_staging 0x5C00 (NOLOAD) : { *(.vars.ship_rectangles) }
  ship_staging__run = 0x5C00;
  ship_staging__size = 0x5DA0 - ship_staging__run;
  ASSERT(. <= 0x5DA0, "the ship staging reaches $5DA0")

  .background_anchors 0x5DA0 : AT(0x105DA0) { *(.text.background_anchor) }
  ASSERT(. <= 0x5E00, "the background anchor code reaches $5E00")

  .damage_map_1 0x5E00 (NOLOAD) : { *(.vars.damage_map_1) }
  ASSERT(. <= 0x6000, "damage map 1 reaches $6000")

  .sprite_cache 0x6000 : AT(0x106000) {
    *(.text.cache_search)
    *(.text.cache_propeller)
    *(.text.cache_allocate_pixel)
    *(.text.cache_begin)
    *(.text.cache_relink)
    *(.text.cache_clone)
    *(.text.cache_prefetch)
    *(.text.combined_rows_helpers)
    *(.text.combined_rows_coverage)
    *(.text.scroll_damage)
    *(.text.game_hud_values)
    *(.rodata.game_hud_messages)
    *(.text.world_upload_batch)
    *(.text.cabinet_overlay)
    *(.text.ship_column_direct)
    *(.text.cache_ready)
  }
  fit_sprite_cache_tail__start = LOADADDR(.sprite_cache) + SIZEOF(.sprite_cache);
  fit_sprite_cache_tail__end = 0x107000;
  fit_sprite_cache_tail__label = load_sram + ADDR(.sprite_cache) + SIZEOF(.sprite_cache);
  fit_sprite_cache_tail__kinds = FIT_GROUP | FIT_COMMON;

  .damage_map_2 0x7000 (NOLOAD) : { *(.vars.damage_map_2) }
  ASSERT(. <= 0x7200, "damage map 2 reaches $7200")

  /* The slot keys and bounds of the sprite cache, the row classes and the
     ready-row staging. */
  .sprite_tables 0x7200 : AT(0x107200) { *(.data.art_keys) }
  .sprite_tables.vars . (NOLOAD) : {
    *(.vars.art_bounds)
    *(.vars.row_classes)
    *(.vars.ship_span_buffer)
  }
  ASSERT(. <= 0x7800, "the sprite tables reach $7800")

  .sprite_cache_descriptors 0x7800 : AT(0x107800) {
    *(.text.cache_headers)
    *(.text.prefetch_time)
    *(.text.archive_find)
  }
  ASSERT(. <= 0x7900, "the sprite cache descriptor code reaches $7900")

  .sprite_wire 0x7900 (NOLOAD) : { *(.vars.art_wire) }
  ASSERT(. <= 0x7910, "the sprite wire reaches $7910")

  .sprite_cache_header 0x7910 : AT(0x107910) {
    *(.text.cache_slot_table)
    *(.text.cache_descriptor)
  }
  ASSERT(. <= 0x7A00, "the sprite cache header code reaches $7A00")

  .sprite_temp 0x7A00 (NOLOAD) : { *(.vars.art_temp) }
  ASSERT(. <= 0x7A98, "the sprite temp reaches $7A98")

  .sprite_retained 0x7A98 : AT(0x107A98) { *(.text.archive_write_index) }
  ASSERT(. <= 0x7B00, "the retained sprite code reaches $7B00")

  /* The cabinet, sprite cache and world upload state. */
  .cache_variables 0x7B00 : AT(0x107B00) {
    *(.data.cabinet_values)
    *(.data.cab_digits)
    *(.data.art_pixel_next)
    *(.data.art_pins)
    *(.data.hitch_scene)
  }
  .cache_variables.vars . (NOLOAD) : {
    *(.vars.art_state)
    *(.vars.art_pixels)
    *(.vars.world_upload_job)
    *(.vars.world_palette)
    *(.vars.cabinet_state)
    *(.vars.cab_glyph)
    *(.vars.cabinet_live)
    *(.vars.hitch_scene)
  }
  ASSERT(. <= 0x7C00, "the cache variables reach $7C00")

  /* The hash chains and the slot phases of the sprite cache. */
  .sprite_chain 0x7C00 : AT(0x107C00) { *(.data.art_chain) }
  .sprite_chain.vars . (NOLOAD) : { *(.vars.art_slot_phases) }
  ASSERT(. <= 0x7D00, "the sprite chain reaches $7D00")

  .sprite_cache_masks 0x7D00 : AT(0x107D00) {
    *(.text.cache_masks)
    *(.text.archive_read_tag)
    *(.text.sprite_mark)
  }
  ASSERT(. <= 0x7E00, "the sprite cache mask code reaches $7E00")

  /* The pan, the current row and the row cache of the planner. */
  .row_variables 0x7E00 (NOLOAD) : {
    *(.vars.combined_rows)
    *(.vars.row_cache)
    *(.vars.background_plan)
  }
  ASSERT(. <= 0x8000, "the row variables reach $8000")

  /* The helper copies for packet buffer 1. */
  .hitch_stage_draw_1 0x8000 : AT(load_packets + 0x8000) {
    *(.text.hitch_stage_draw_buffer1)
    *(.rodata.hitch_stage_blocks_buffer1)
  }
  hitch_stage_draw_1__run = ADDR(.hitch_stage_draw_1);
  hitch_stage_draw_1__size = SIZEOF(.hitch_stage_draw_1);
  hitch_stage_draw_1__limit = 0x8300;
  ASSERT(. <= hitch_stage_draw_1__limit, "hitch stage helper 1 reaches its limit")
  .special_bolt_helper_1 0x8000 : AT(load_packets + 0x8000) { *(.text.special_bolt_draw_buffer1) }
  special_bolt_helper_1__run = ADDR(.special_bolt_helper_1);
  special_bolt_helper_1__size = SIZEOF(.special_bolt_helper_1);
  ASSERT(. <= 0x8300, "special bolt helper 1 reaches $8300")
  .special_wave_helper_1 0x8000 : AT(load_packets + 0x8000) { *(.text.special_wave_draw_buffer1) }
  special_wave_helper_1__run = ADDR(.special_wave_helper_1);
  special_wave_helper_1__size = SIZEOF(.special_wave_helper_1);
  ASSERT(. <= 0x8480, "special wave helper 1 reaches $8480")

  .cabinet_common 0x8700 : AT(0x108700) {
    *(.rodata.cab_damage)
    *(.text.cab_demo_fast)
    *(.data.cab_demo_tables)
    *(.text.cabinet_presentation)
    *(.text.cabinet_draw)
    *(.text.cabinet_plane)
    *(.text.cabinet_expand_2bit)
    *(.text.cabinet_actors)
    *(.text.cabinet_bridges)
  }
  fit_cabinet_tail__start = LOADADDR(.cabinet_common) + SIZEOF(.cabinet_common);
  fit_cabinet_tail__end = 0x109000;
  fit_cabinet_tail__label = load_sram + ADDR(.cabinet_common) + SIZEOF(.cabinet_common);
  fit_cabinet_tail__kinds = FIT_GROUP | FIT_COMMON;

  /* The canonical masks of the sprite slots and the roots of the ring rows. */
  .mask_tables 0x9000 (NOLOAD) : {
    *(.vars.canonical_masks)
    *(.vars.mask_roots)
  }
  ASSERT(. <= 0xA300, "the mask tables reach $A300")

  .background_migration 0xA300 : AT(0x10A300) {
    *(.text.background_migration)
    *(.text.ship_alignment_view)
    *(.text.sea_occupancy_bridge)
  }
  ASSERT(. <= 0xA400, "the background migration code reaches $A400")

  /* The water gaps of the ring rows and the roots of its columns. */
  .water_bounds 0xA400 (NOLOAD) : {
    *(.vars.water_bounds)
    *(.vars.cloud_roots)
  }
  ASSERT(. <= 0xA618, "the water bounds reach $A618")

  .water_copy 0xA618 : AT(0x10A618) {
    *(.text.water_copy)
    *(.text.background_families)
    *(.text.world_scatter_table)
  }
  ASSERT(. <= 0xA6C0, "the water copy code reaches $A6C0")

  .ship_alignment 0xA6C0 : AT(0x10A6C0) {
    *(.text.ship_alignment)
    *(.rodata.ship_alignment_bases)
  }
  ASSERT(. <= 0xA700, "the ship alignment code reaches $A700")

  /* The mod 30 tables of water_mod30: the low byte table in common SRAM, the
     high byte table (.water_residues_high) through BBR. */
  .water_residues_low 0xA700 : AT(0x10A700) { *(.rodata.water_low_residues) }
  ASSERT(. <= 0xA800, "the low water residues reach $A800")

  .game_scroll_fast 0xA800 : AT(0x10A800) {
    *(.text.scroll_helpers)
    *(.text.water_fast)
    *(.text.game_low_hidden)
    *(.text.ship_linear)
    *(.text.ship_column_map)
    *(.text.cabinet_rank_dispatch)
  }
  fit_fast_scroll_tail__start = LOADADDR(.game_scroll_fast) + SIZEOF(.game_scroll_fast);
  fit_fast_scroll_tail__end = 0x10B000;
  fit_fast_scroll_tail__label = load_sram + ADDR(.game_scroll_fast) + SIZEOF(.game_scroll_fast);
  fit_fast_scroll_tail__kinds = FIT_COMMON;
  fit_fast_scroll_tail__align = 2;

  .game_scroll 0xB000 : AT(0x10B000) {
    *(.text.scroll_draw)
    *(.text.combined_sea)
    *(.text.repair_groups)
    *(.text.feature_open)
    *(.text.compose_source)
    *(.text.scroll_camera)
  }
  fit_scroll_tail__start = LOADADDR(.game_scroll) + SIZEOF(.game_scroll);
  fit_scroll_tail__end = 0x10B800;
  fit_scroll_tail__label = load_sram + ADDR(.game_scroll) + SIZEOF(.game_scroll);
  fit_scroll_tail__kinds = FIT_COMMON;
  fit_scroll_tail__align = 2;

  /* The hidden sprites of the picture (sprite_cache.s). */
  .hidden_queue 0xB800 (NOLOAD) : { *(.vars.art_hidden_queue) }
  ASSERT(. <= 0xBA00, "the hidden queue reaches $BA00")

  .ship_rows 0xBA00 : AT(0x10BA00) {
    *(.text.ship_rows)
    *(.text.combined_position)
    *(.text.combined_repairs)
    *(.text.ship_reuse)
    *(.text.combined_rows_column)
    *(.text.ship_rows_tail)
    *(.text.sea_helpers)
    *(.text.cab_demo_finish_dispatch)
  }
  fit_ship_row_tail__start = LOADADDR(.ship_rows) + SIZEOF(.ship_rows);
  fit_ship_row_tail__end = 0x10C000;
  fit_ship_row_tail__label = load_sram + ADDR(.ship_rows) + SIZEOF(.ship_rows);
  fit_ship_row_tail__kinds = FIT_COMMON;
  fit_ship_row_tail__align = 2;

  /* ---- Code that runs through the bank area or common area 1 ---- */

  /* Page C: the energy cache code runs at $C000 through BBR; the code after it
     runs through common area 1 at $E000 (CBR). */
  .bank_code 0xC000 : AT(0x10C000) { *(.text.hud_energy_cache) }
  bank_code__load = LOADADDR(.bank_code);
  .bank_code.e000 (0xE000 + LOADADDR(.bank_code) + SIZEOF(.bank_code) - bank_code__load)
      : AT(LOADADDR(.bank_code) + SIZEOF(.bank_code)) {
    *(.text.cabinet_live)
    *(.rodata.cabinet_live_lists)
    *(.text.hitch_water)
    *(.text.hitch_scene_banked)
  }
  /* The labels of records in page C are their load addresses. */
  fit_page_c__start = LOADADDR(.bank_code.e000) + SIZEOF(.bank_code.e000);
  fit_page_c__end = 0x10D000;
  fit_page_c__label = fit_page_c__start;
  fit_page_c__kinds = FIT_RECORD | FIT_ENTRIES;

  /* The pattern pages: records, and the glyph programs of one 8 KB view that
     runs at $C000. */
  pattern_pages__load = 0x10D000;
  fit_pattern_pages__start = 0x10D000;
  fit_pattern_pages__end = 0x110000;
  fit_pattern_pages__label = 0x10D000;
  fit_pattern_pages__kinds = FIT_RECORD | FIT_ENTRIES | FIT_GROUP | FIT_ROWS;
  fit_pattern_pages__view = 0xC000;

  .sea_occupancy 0xCC00 : AT(0x117C00) {
    *(.data.sea_occupancy_map)
    *(.text.sea_occupancy)
  }
  sea_occupancy__load = LOADADDR(.sea_occupancy);
  .sea_occupancy.e000 (0xEC00 + LOADADDR(.sea_occupancy) + SIZEOF(.sea_occupancy) - sea_occupancy__load)
      : AT(LOADADDR(.sea_occupancy) + SIZEOF(.sea_occupancy)) {
    *(.text.water_flash)
  }
  ASSERT(LOADADDR(.sea_occupancy.e000) + SIZEOF(.sea_occupancy.e000) <= 0x117E00,
         "the sea occupancy code reaches $117E00")

  .sprite_retained_banked 0xCE80 : AT(0x117E80) { *(.text.archive_banked) }
  ASSERT(. <= 0xCFE0, "the banked retained sprite code reaches $CFE0")

  .background_full 0xC700 : AT(0x11B700) {
    *(.text.background_full)
    *(.text.water_refresh)
    *(.text.combined_descriptor_prepare)
  }
  background_full__load = LOADADDR(.background_full);
  ASSERT(. <= 0xCB00, "the background code reaches $CB00 (.world_side1_high)")
  .background_full.limits 0xCE00 : AT(0x11BE00) { *(.rodata.background_empty_limits) }
  ASSERT(. <= 0xD000, "the background empty limits reach $D000")

  /* The menu helpers: they run at $E000 in the helper slot. */
  .mirror_enter 0xE000 : AT(load_packets + 0xE000) { *(.text.mirror_enter) }
  mirror_enter__run = ADDR(.mirror_enter);
  mirror_enter__end = ADDR(.mirror_enter) + SIZEOF(.mirror_enter);
  .mirror_restore 0xE000 : AT(load_packets + 0xE000) { *(.text.mirror_restore) }
  mirror_restore__run = ADDR(.mirror_restore);
  /* mirror_final runs at $4000: the restore helper copies it there. */
  .mirror_restore.final 0x4000 : AT(LOADADDR(.mirror_restore) + SIZEOF(.mirror_restore)) {
    *(.text.mirror_final)
  }
  .mirror_restore.apply (mirror_restore__run + LOADADDR(.mirror_restore.final)
                         + SIZEOF(.mirror_restore.final) - LOADADDR(.mirror_restore))
      : AT(LOADADDR(.mirror_restore.final) + SIZEOF(.mirror_restore.final)) {
    *(.text.mirror_apply_mode)
  }
  mirror_restore__end = ADDR(.mirror_restore.apply) + SIZEOF(.mirror_restore.apply);
  ASSERT(mirror_enter__end - mirror_enter__run <= mirror_helper__size
         && mirror_restore__end - mirror_restore__run <= mirror_helper__size,
         "the menu helpers must fit the helper slot before the buffer")

  /* ---- Data read through BBR or CBR: labels are load addresses ---- */

  /* The stage water palette (water.s through BBR). */
  .water_colours 0x110800 : AT(0x110800) { *(.rodata.water_colours) }
  ASSERT(. <= 0x110C80, "the water colours reach $110C80")

  fit_page_10__start = 0x110C80; fit_page_10__end = 0x111000;
  fit_page_10__label = 0x110C80; fit_page_10__kinds = FIT_RECORD | FIT_ENTRIES;

  .phase_records 0x111000 : AT(0x111000) { *(.rodata.phase_records) }
  ASSERT(. <= 0x112000, "the phase records reach $112000")

  /* The draw headers and the mask tables of the sprite cache: one 4 KB page
     through one BBR (sprite_cache.s). */
  .sprite_headers 0x112000 : AT(0x112000) {
    *(.data.art_headers)
    *(.data.pair_masks)
    *(.rodata.span_headers)
    *(.rodata.span_masks)
  }
  ASSERT(. <= 0x112F00, "the sprite headers reach $112F00")

  /* The sprite position records (state_plan.s; scripts/state_scene.py), read
     through BBR. */
  .position_records 0x113000 : AT(0x113000) { *(.rodata.position_records) }
  ASSERT(. <= 0x114800, "the position records reach $114800")

  /* The world column map and column descriptors (scripts/world_stream.py),
     read through BBR (combined_rows.s). The side 1 table has two fragments:
     the second fills a gap of .background_full. The IIgs updates the
     descriptors at these load addresses (scripts/combined_world.py jobs). */
  .world_side0 world_side0__load : AT(world_side0__load) { *(.rodata.world_side0) }
  ASSERT(. <= 0x115000, "the side 0 descriptors reach $115000")

  .hud_templates 0x115000 : AT(0x115000) { *(.rodata.hud_templates) }
  fit_hud_page__start = .; fit_hud_page__end = 0x116000;
  fit_hud_page__label = .; fit_hud_page__kinds = FIT_RECORD | FIT_ENTRIES;

  .world_column_map 0x116000 : AT(0x116000) { *(.rodata.world_column_map) }
  ASSERT(. <= 0x117000, "the world column map reaches $117000")

  /* The bindings and the phase links of the sprite cache: one 4 KB page. */
  .sprite_links 0x117000 : AT(0x117000) {
    *(.data.art_bindings)
    *(.data.phase_links)
  }
  ASSERT(. <= 0x117C00, "the sprite links reach $117C00")

  /* The ready row programs of the strip families (scripts/combined_world.py),
     read through the bank window at $C000 with the BBR of the column families
     at $D000: they start a 4 KB page, and the column families are in the
     next. */
  .row_programs 0x118000 : AT(0x118000) { *(.rodata.row_programs) }
  ASSERT(. <= 0x119100, "the row programs reach $119100")

  /* The column cache of the scroll draw (combined_scroll.s, through the upper
     half of the bank area). */
  .column_cache 0x119100 (NOLOAD) : {
    *(.vars.column_families)
    *(.vars.column_recipes)
  }
  ASSERT(. <= 0x119600, "the column cache reaches $119600")

  /* The sea directory, the cloud palette and the sea records: sea_sram maps
     SRAM bank SEA_SRAM (sea_features.s). */
  .sea_directory 0x119600 : AT(0x119600) {
    *(.rodata.sea_directory)
    ASSERT(. <= 0x800, "the sea directory reaches $119E00");
    . = 0x800;                  /* $119E00 */
    *(.rodata.cloud_palette)
    ASSERT(. <= 0x860, "the cloud palette reaches $119E60");
    . = 0x860;                  /* $119E60 */
    *(.rodata.sea_records)
  }
  sea_directory__load = LOADADDR(.sea_directory);
  sea_directory__limit = 0x11B000;
  ASSERT(. <= sea_directory__limit, "the sea records reach $11B000")

  /* The pixel row addresses of the world slots (world_rows.s), read through
     the upper half of the bank area. */
  .row_address_cache 0x11B000 (NOLOAD) : { *(.vars.row_address_cache) }
  ASSERT(. <= 0x11B400, "the row address cache reaches $11B400")

  .world_side1_low world_side1_low__load : AT(world_side1_low__load) { *(.rodata.world_side1_low) }
  ASSERT(. <= 0x11B600, "the side 1 low descriptors reach $11B600")

  .water_residues_high 0x11B600 : AT(0x11B600) { *(.rodata.water_high_residues) }
  ASSERT(. <= 0x11B700, "the high water residues reach $11B700")

  .world_side1_high world_side1_high__load : AT(world_side1_high__load) { *(.rodata.world_side1_high) }
  ASSERT(. <= 0x11BE00, "the side 1 high descriptors reach $11BE00")

  /* The ready-row commands: 64 bytes for each of the 256 world rows, read
     through CBR (combined_rows.s, background_full.s). */
  .ready_rows 0x11C000 (NOLOAD) : { *(.vars.ready_rows) }
  ASSERT(. <= 0x120000, "the ready rows reach $120000")

  INCLUDE placements.ld
  /DISCARD/ : { *(.text*) *(.rodata*) *(.data*) *(.bss*) }
}

/* The entry staging (playfield.s entry_staging): the IIgs loads the bytes of
   each staged range, then of the runtime block, into plane 0 of the groups
   from entry_stage_N on, in display page 0, which the entry repaints
   completely (scripts/playfield.py). The entry copies them into place. */
staged_0__size = staged_0__end - staged_0__start;
staged_1__size = staged_1__end - staged_1__start;
staged_2__size = staged_2__end - staged_2__start;
staged_3__size = staged_3__end - staged_3__start;
staged_4__size = staged_4__end - staged_4__start;
staged_5__size = staged_5__end - staged_5__start;
staged_6__size = staged_6__end - staged_6__start;
entry_stage_0 = entry_stage_base;
entry_stage_1 = entry_stage_0 + staged_0__size;
entry_stage_2 = entry_stage_1 + staged_1__size;
entry_stage_3 = entry_stage_2 + staged_2__size;
entry_stage_4 = entry_stage_3 + staged_3__size;
entry_stage_5 = entry_stage_4 + staged_4__size;
entry_stage_6 = entry_stage_5 + staged_5__size;
entry_stage_7 = entry_stage_6 + staged_6__size;         /* the runtime block */
entry_stage_end = entry_stage_7 + entry_runtime__size;
ASSERT(entry_stage_end - entry_stage_base <= 2 * ring_groups,
       "the entry staging reaches past the ring rows that the entry draws over it")
ASSERT(entry_stage_end <= 0x10000, "the entry staging leaves video RAM segment 0 (playfield.s entry_staging)")

/* The window values of the labels that the asset sources use (LABEL__KIND,
   scripts/asset_source.py writes formulas.ld). */
INCLUDE formulas.ld

/* The window values that the hand-written sources use. */
/* physical SRAM addresses */
mirror_buffer__load__phys = mirror_buffer__load - load_sram;
mirror_helper__load__phys = mirror_helper__load - load_sram;
staged_0__start__phys = staged_0__start - load_sram;
staged_1__start__phys = staged_1__start - load_sram;
staged_2__start__phys = staged_2__start - load_sram;
staged_3__start__phys = staged_3__start - load_sram;
staged_4__start__phys = staged_4__start - load_sram;
staged_5__start__phys = staged_5__start - load_sram;
staged_6__start__phys = staged_6__start - load_sram;
state_planner__load__phys = state_planner__load - load_sram;
/* physical address / 2 */
art_headers__half = ((art_headers - load_sram) >> 1) & 0xFFFF;
/* the low 16 bits */
sea_directory__low16 = sea_directory & 0xFFFF;
/* BBR values that show the label at $C000 */
art_bindings__bbr = (((art_bindings - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
art_headers__bbr = (((art_headers - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
background_full__load__bbr = (((background_full__load - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
bank_code__load__bbr = (((bank_code__load - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
cloud_palette_normal__bbr = (((cloud_palette_normal - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
pattern_pages__load__bbr = (((pattern_pages__load - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
phase_records__bbr = (((phase_records - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
ready_rows__bbr = (((ready_rows - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
sea_occupancy__load__bbr = (((sea_occupancy__load - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
water_high_residues__bbr = (((water_high_residues - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
water_palette_indices__bbr = (((water_palette_indices - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
world_column_map__bbr = (((world_column_map - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
world_side0__bbr = (((world_side0 - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
world_side1_high__bbr = (((world_side1_high - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
world_side1_low__bbr = (((world_side1_low - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
x_records__bbr = (((x_records - load_sram) >> 12) - (bank_window >> 12)) & 0xFF;
/* pointers through the bank window at $C000 */
cloud_palette_lit__ptr = bank_window + (cloud_palette_lit & 0xFFF);
cloud_palette_normal__ptr = bank_window + (cloud_palette_normal & 0xFFF);
hud_boss_template__ptr = bank_window + (hud_boss_template & 0xFFF);
water_high_residues__ptr = bank_window + (water_high_residues & 0xFFF);
water_palette_indices__ptr = bank_window + (water_palette_indices & 0xFFF);
world_side0__ptr = bank_window + (world_side0 & 0xFFF);
world_side1_high__ptr = bank_window + (world_side1_high & 0xFFF);
world_side1_low__ptr = bank_window + (world_side1_low & 0xFFF);
x_records__ptr = bank_window + (x_records & 0xFFF);
y_records__ptr = bank_window + (y_records & 0xFFF);
/* BBR values that show the label at $D000 */
cached_row_addresses__bbrd = (((cached_row_addresses - load_sram) >> 12) - (bank_window_upper >> 12)) & 0xFF;
column_families__bbrd = (((column_families - load_sram) >> 12) - (bank_window_upper >> 12)) & 0xFF;
/* pointers at $D000 */
cached_row_addresses__ptrd = bank_window_upper + (cached_row_addresses & 0xFFF);
column_families__ptrd = bank_window_upper + (column_families & 0xFFF);
column_recipes__ptrd = bank_window_upper + (column_recipes & 0xFFF);
/* CBR values that show the label at $E000 */
bank_code__load__cbr = (((bank_code__load - load_sram) >> 12) - (common1_window >> 12)) & 0xFF;
mirror_helper__load__cbr = (((mirror_helper__load - load_sram) >> 12) - (common1_window >> 12)) & 0xFF;
ready_rows__cbr = (((ready_rows - load_sram) >> 12) - (common1_window >> 12)) & 0xFF;
sea_occupancy__load__cbr = (((sea_occupancy__load - load_sram) >> 12) - (common1_window >> 12)) & 0xFF;
/* pointers through common area 1 at $E000 */
mirror_buffer__load__ptre = common1_window + (mirror_buffer__load & 0xFFF);
/* Oak segments of video RAM labels */
bolt_table__vseg = (bolt_table >> 18) & 0xFF;
game_coverage__vseg = (game_coverage >> 18) & 0xFF;
row_pixels__vseg = (row_pixels >> 18) & 0xFF;
row_table__vseg = (row_table >> 18) & 0xFF;
special_wave__vseg = (special_wave >> 18) & 0xFF;
/* group addresses in their Oak segment */
game_coverage__group16 = (game_coverage >> 2) & 0xFFFF;
special_wave__group16 = (special_wave >> 2) & 0xFFFF;
/* DMA addresses through the VGA window */
game_coverage__dma = vga_window + ((game_coverage >> 2) & 0xFFFF);
/* BBR values of the 4 KB VGA window */
bolt_table__vbbr4k = vga_window_bbr + (((bolt_table >> 2) & 0xFFFF) >> 12);
/* pointers through the 4 KB VGA window */
bolt_table__vptr4k = bank_window + ((bolt_table >> 2) & 0xFFF);

/* Checks of the layout that the code needs. */
ASSERT(repair_core_select == ship_staging__run, "the repair code must run in the ship staging buffer")
ASSERT(repair_core_end - repair_core_select <= ship_staging__size, "the repair code exceeds the ship staging buffer")
ASSERT(repair_core_groups >= ship_staging__size, "plane 3 of the repair core block is shorter than the ship staging (scripts/repair_core.py)")
ASSERT(entry_mode_data <= entry_runtime__run, "the entry mode table starts after the runtime block")
ASSERT(entry_runtime__end <= monitor_timing_ready, "the runtime block overwrites entry code that still runs")
ASSERT(monitor_timing_ready < entry_staging_call, "the entry staging call comes before the monitor timing setup")
ASSERT((art_headers & 0xFFF) == 0 && pair_masks == art_headers + 0x800 && span_headers == art_headers + 0xC00
       && span_masks == art_headers + 0xD00, "the sprite cache tables leave the window offsets of sprite_cache.s")
ASSERT((art_bindings & 0xFFF) == 0 && phase_links == art_bindings + 0x800 && (phase_records & 0xFFF) == 0,
       "the sprite cache links leave the window offsets of sprite_cache.s")
ASSERT((world_side1_low >> 12) == (world_side1_high >> 12), "the two side 1 descriptor fragments need one BBR (combined_rows.s)")
ASSERT(packet_buffer_0__run == 0x4000 && packet_buffer_1__run == 0x8000,
       "stream_arm makes the handshake token from bits 6 and 7 of the buffer high byte")
ASSERT((mirror_helper__load >> 12) == (mirror_buffer__load >> 12) && mirror_buffer__limit - mirror_helper__load == 0x1000,
       "the menu helper and its buffer fill one 4 KB page (menu_mirror.s SLOT_BYTES, HELPER_CBR)")
ASSERT(((sea_directory__load - load_sram) >> 16) == 1 && ((sea_directory__limit - 1 - load_sram) >> 16) == 1,
       "sea_sram maps SRAM bank SEA_SRAM (sea_features.s): the sea directory and records must be in it")
ASSERT((row_programs & 0xFFF) == 0 && (column_families >> 12) == (row_programs >> 12) + 1,
       "the row programs start the 4 KB page before the column families (combined_scroll.s maps both with one BBR)")
ASSERT(hitch_stage_draw_0__run == packet_buffer_0__run && hitch_stage_draw_1__run == packet_buffer_1__run
       && special_bolt_helper_0__run == packet_buffer_0__run && special_bolt_helper_1__run == packet_buffer_1__run
       && special_wave_helper_0__run == packet_buffer_0__run && special_wave_helper_1__run == packet_buffer_1__run,
       "each helper copy runs at the start of its packet buffer (state_plan.s and hitch_scene.s jump to the other buffer)")
ASSERT(world_upload_buffer == scratch__run, "the upload buffer starts the scratch page")
ASSERT(world_side0 == world_side0__load && world_side1_low == world_side1_low__load
       && world_side1_high == world_side1_high__load, "the descriptor tables start their sections (fixed.ld)")
ASSERT(fit_planner_tail__start <= fit_planner_tail__end && fit_row_gap__start <= fit_row_gap__end
       && fit_sprite_cache_tail__start <= fit_sprite_cache_tail__end && fit_cabinet_tail__start <= fit_cabinet_tail__end
       && fit_fast_scroll_tail__start <= fit_fast_scroll_tail__end && fit_scroll_tail__start <= fit_scroll_tail__end
       && fit_ship_row_tail__start <= fit_ship_row_tail__end && fit_page_c__start <= fit_page_c__end
       && fit_hud_page__start <= fit_hud_page__end, "code or data reaches the end of its region")
ASSERT((cab_digits >> 8) == (cabinet_values >> 8) && ((cab_digits + 10) >> 8) == (cab_digits >> 8),
       "cabinet_regular_field keeps H: cab_digits must be in the page of cabinet_values")
