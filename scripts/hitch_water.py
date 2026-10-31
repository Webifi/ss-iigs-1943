"""Batch complete water rows when a ship slide starts ($2EC7 = 1) or the ring
wraps (combined_scroll.py combined_refresh). The final placement ($2EC7 = 2)
gets no refresh."""


def install(scene, host):
    """The water and scene helpers, in the banked code page (region bank-code of src/card/memory.toml)."""

    from hitch_stage import install as install_hitch_stage

    install_hitch_stage(scene, host)
    from hitch_scene import place_banked

    place_banked(scene)
    host.upload(0x107BF7, bytes(2))
