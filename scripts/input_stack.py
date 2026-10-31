"""Native input bank in otherwise unused host RAM; no additional DOC voice."""

INPUT_CAPACITY = 0x5600


def reserve(host):
    # Keep near calls/data in one bank. Existing game/sound/art bytes stay put.
    write_defaults(host.out)
    from input_audio import prepare as prepare_mix

    prepare_mix(host)
    host.input_code_source = host.blob_at_input(INPUT_CAPACITY, "input_code")
    host.input_code_size = INPUT_CAPACITY
    host.routines += [
        '.segment "INPUT"',
        '.include "input_native.s"',
        '.include "cabinet_scores.s"',
        '.include "cabinet_post.s"',
        '.segment "NATIVE"',
    ]


def write_defaults(out):
    # Both keyboard sources share the user's defaults; source ownership remains
    # independent, and the menu may split any binding between ADB and J13.
    records = []

    def bind(key, action, source=3):
        records.append(bytes((key, source, action, 0)))

    for key, act in (
        (0x0D, 3),
        (0, 1),
        (1, 2),
        (2, 0),
        (0x3B, 1),
        (0x3C, 0),
        (0x3D, 2),
        (0x3E, 3),
        (0x7B, 1),
        (0x7C, 0),
        (0x7D, 2),
        (0x7E, 3),
        (0x5B, 3),
        (0x54, 2),
        (0x56, 1),
        (0x58, 0),
        (0x59, 3),
        (0x59, 1),
        (0x5C, 3),
        (0x5C, 0),
        (0x53, 2),
        (0x53, 1),
        (0x55, 2),
        (0x55, 0),
        (0x36, 4),
        (0x3A, 5),
        (0x38, 11),
        (0x4C, 11),
        (0x12, 12),
        (0x13, 13),
        (0x17, 14),
        (0x16, 15),
    ):
        bind(key, act)
    for key, act in enumerate((6, 7, 8, 9, 10)):
        bind(key, act, 4)
    for key, act in enumerate((6, 7, 8, 9, 10, 11)):
        bind(key, act, 5)
    for source, actions in ((6, (0, 1, 2, 3, 12, 14, 5, 4)), (7, (6, 7, 8, 9, 13, 15, 11, 10))):
        for key, act in enumerate(actions):
            bind(key, act, source)
    assert len(records) <= 64
    records += [bytes((255, 0, 255, 0))] * (64 - len(records))
    out.joinpath("input_defaults.inc").write_text(
        "".join("  .byte " + ",".join(str(b) for b in r) + "\n" for r in records)
    )
