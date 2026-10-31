"""Menu-only mix controls; leave the native players' event paths unchanged."""

from audio_config import KNEE, volume_register


def prepare(host):
    registers = host.address("fm_register_table")
    original = bytes(host.contents["fm_register_table"])
    assert len(original) == 1088
    tables = host.address("audio_tables")
    count = len(host.data_sources["audio_tables"])
    assert count == 66
    fm = bytes(
        (v if level == 10 else volume_register(KNEE[v] * level / 10, "knee"))
        for level in range(11)
        for v in range(256)
    )
    # Only the packed non-envelope waveforms use this menu lookup. Verify
    # every page header so future sound-bank changes cannot silently widen it.
    used = set()
    parts = host.data_sources["audio_tables"].parts
    for (_, (source,)), (_, (_, gate, pages)) in zip(parts[::2], parts[1::2]):
        if gate:
            continue
        data = host.contents[source.label]
        for page in range(pages):
            samples = data[page * 34 : page * 34 + 2]
            assert len(samples) == 2
            used.update(samples)
    assert used <= {1, 128, 255}, f"unexpected SSG amplitudes: {sorted(used)}"
    wave = bytes(
        max(1, min(255, 128 + round((v - 128) * level / 10)))
        for v in (1, 128, 255)
        for level in range(11)
    )

    # These tables are read only while applying menu settings, never by IRQ.
    # Production may use the spare slow video bank; fixtures keep fast RAM.
    def settings_blob(data):
        try:
            return host.slow_blob_at(data)
        except ValueError:
            pass

    orig = settings_blob(original)
    fmap = settings_blob(fm)
    wmap = host.blob_at_bank(wave)

    (host.out / "input_audio.inc").write_text(
        f"MIX_FM_REGISTERS = {registers.label}\nMIX_FM_ORIGINAL = {orig.label}\nMIX_FM_BYTES = {len(original)}\nMIX_FM_GAINS = {fmap.label}\nMIX_WAVE_GAINS = {wmap.label}\nMIX_SSG_TABLES = {tables.label}\nMIX_SSG_TABLE_BYTES = {count}\n"
    )
