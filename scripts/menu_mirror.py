"""Build and allocate the reversible Second Sight firmware-mirror transition."""

def allocate(host):
    """The menu mirror packets, after the final link: they end the payload.
    The helpers are regions mirror-bootstrap, mirror-enter and mirror-restore
    of src/card/memory.toml (src/card/menu_mirror.s)."""
    from card_link import after_link

    after_link(lambda: _allocate(host))


def _allocate(host):
    from card_link import region_bytes, region_image, symbol
    from stream_scene import RX_PTR

    assert region_bytes("playfield", symbol("stream_arm_next"), 5) == bytes(
        (0x3A, (RX_PTR + 1) & 255, (RX_PTR + 1) >> 8, 0xEE, 0xC0)
    ), "stream rearm continuation changed"
    bootstrap = region_image("mirror-bootstrap")
    enter = region_image("mirror-enter")
    enter += bytes(len(enter) & 1)
    restore = region_image("mirror-restore")
    restore += bytes(len(restore) & 1)
    assert len(bootstrap) == 175
    # PEI transport consumes byte-swapped words, including its length word.
    header = bytearray(66)
    header[27] = 127
    packet = bytes(header) + bootstrap
    packet += bytes(len(packet) & 1)
    wire = len(packet).to_bytes(2, "little") + packet
    wire = b"".join(wire[i : i + 2][::-1] for i in range(0, len(wire), 2))
    # The bank-alignment hole before INPUT is explicitly reserved and tracked
    # by input_stack. Claim it via the common allocator, after specials have
    # finished their own allocations. These bytes are menu-owned for the
    # entire game; only the snapshot contents change while gameplay is paused.
    # This immutable 244-byte packet is read only while entering the paused
    # menu, via a long-addressed CPU copy. Use remaining video-bank RAM first;
    # keep fast INPUT padding for executable code and mutable snapshots.
    try:
        host.slow_blob_at(wire, "MIRROR_PACKET")
    except ValueError:
        host.blob_at_padding_or_bank(wire, "MIRROR_PACKET")
    host.blob_at_padding_or_bank(enter, "MIRROR_ENTER")
    host.blob_at_padding_or_bank(restore, "MIRROR_RESTORE")
    # Menu-only scratch in Mega II RAM $E0/0800-$1FFF: no shadowing (only
    # text page 1 is shadowed), never touched by play, the menu or Save.
    # The buffers start empty; nothing is loaded there at boot.
    palette_addr = 0xE00800
    host.blob_at_padding_or_bank(bytes(8), "MIRROR_RETURN")
    text_addr = 0xE00B08
    slot_addr = 0xE00F08
    lc_state_addr = 0xE01F08
    assert slot_addr + 4096 <= lc_state_addr < 0xE02000
    # The packets and the return area stay in one bank by their allocators.
    for address, n in ((palette_addr, 776), (text_addr, 1024), (slot_addr, 4096)):
        assert (address & 65535) + n <= 65536, ("mirror allocation crosses bank", hex(address), n)
    # The SRAM snapshot is the last 64 KB of the 1 MiB expansion, after the
    # payload. The 32 KiB video snapshot is in $E0/$E1 language-card RAM
    # (src/menu_mirror_host.s), freeing $0E8000-$0EFFFF.
    host.reserve_top(0xF0000, 0x10000, "mirror_snapshot")
    (host.out / "menu-mirror.inc").write_text(
        "\n".join(
            (
                f"MIRROR_PACKET_BYTES = {len(wire)}",
                f"MIRROR_PAYLOAD_BYTES = {len(packet)}",
                f"MIRROR_ENTER_BYTES = {len(enter)}",
                f"MIRROR_RESTORE_BYTES = {len(restore)}",
                f"MIRROR_PALETTE = ${palette_addr:06x}",
                f"MIRROR_TEXT = ${text_addr:06x}",
                f"MIRROR_SLOT = ${slot_addr:06x}",
                f"MIRROR_LC_STATE = ${lc_state_addr:06x}",
            )
        )
        + "\n"
    )
    host.menu_mirror_code_source = 0x0F4000
    host.routines += [
        '.segment "MIRROR"',
        '.include "menu-mirror.inc"',
        '.include "menu_mirror_host.s"',
        '.segment "NATIVE"',
    ]
