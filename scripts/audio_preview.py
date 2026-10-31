"""DOC RAM layout of the tables of one sound model."""


def layout(waves):
    data = bytearray()
    places = {}
    names = [k for k in waves if k in ("attack", "loop", "release") or k.startswith("stage_")]
    for name in sorted(names, key=lambda k: (-len(waves[k]), k)):
        n = len(waves[name])
        at = (len(data) + n - 1) & -n
        data.extend(bytes([128]) * (at - len(data)))
        places[name] = at
        data.extend(waves[name].tobytes())
    assert len(data) <= 65536, len(data)
    return bytes(data), places
