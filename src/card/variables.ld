/* Card variables at fixed logical addresses. Each subsystem keeps its
 * variables in its own .vars section; the linker reports any overlap. */

SECTIONS
{
    .vars_compiled_hud 0x0CF0 (NOLOAD) : { *(.vars.compiled_hud) }
    .vars_hitch_stage 0x2EF5 (NOLOAD) : { *(.vars.hitch_stage) }
    .vars_object_kernel 0x3390 (NOLOAD) : { *(.vars.object_kernel) }
    .vars_restore_kernel 0x33C0 (NOLOAD) : { *(.vars.restore_kernel) }
    .vars_scene 0x0C00 (NOLOAD) : { *(.vars.scene) }
    .vars_priority 0x0C74 (NOLOAD) : { *(.vars.priority) }
    .vars_rect_masks 0x0CDC (NOLOAD) : { *(.vars.rect_masks) }
    .vars_scene_kernel 0x3342 (NOLOAD) : { *(.vars.scene_kernel) }
    .vars_playfield 0x3300 (NOLOAD) : { *(.vars.playfield) }
    .vars_glyph_kernel 0x33D0 (NOLOAD) : { *(.vars.glyph_kernel) }
    .vars_hitch_scene 0x7BF7 (NOLOAD) : { *(.vars.hitch_scene) }
    .vars_art_hash 0x2F00 (NOLOAD) : { *(.vars.art_hash) }
    .vars_art_keys 0x7400 (NOLOAD) : { *(.vars.art_keys) }
    .vars_art_bounds 0x7600 (NOLOAD) : { *(.vars.art_bounds) }
    .vars_art_wire 0x7900 (NOLOAD) : { *(.vars.art_wire) }
    .vars_art_temp 0x7A00 (NOLOAD) : { *(.vars.art_temp) }
    .vars_art_state 0x7B20 (NOLOAD) : { *(.vars.art_state) }
    .vars_art_chain 0x7C00 (NOLOAD) : { *(.vars.art_chain) }
    .vars_water 0x2E30 (NOLOAD) : { *(.vars.water) }
    .vars_background_motion 0x2E40 (NOLOAD) : { *(.vars.background_motion) }
    .vars_sea_features 0x2EA0 (NOLOAD) : { *(.vars.sea_features) }
    .vars_background_anchor 0x2E5A (NOLOAD) : { *(.vars.background_anchor) }
    .vars_ship_alignment 0x2EED (NOLOAD) : { *(.vars.ship_alignment) }
    .vars_repair_core 0x2EF8 (NOLOAD) : { *(.vars.repair_core) }
    .vars_ship_columns 0x2EF8 (NOLOAD) : { *(.vars.ship_columns) }
    .vars_ship_rectangles 0x5C00 (NOLOAD) : { *(.vars.ship_rectangles) }
}
