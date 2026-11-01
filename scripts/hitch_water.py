"""Batch complete water rows when a ship slide starts (scroll_pan_slide =
PAN_SLIDE_START) or the ring wraps (combined_scroll.py combined_refresh). The
final placement (PAN_SLIDE_PLACED) gets no refresh."""


def install(scene, host):
    """The water and scene helpers, in the banked code page (.bank_code of secondsight.ld)."""

    from hitch_stage import install as install_hitch_stage

    install_hitch_stage(scene, host)
    from hitch_scene import place_banked

    place_banked(scene)
