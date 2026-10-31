"""Wire the existing native sound bank into the bootable game."""

import re
from harness import ROOT


def prepare(out, host):
    from audio_song_native import prepare as bank

    meta = bank(out, host)
    text = (out / "audio_data.inc").read_text()
    # Commands come from gameplay.
    text = (
        "\n".join(
            s
            for s in text.splitlines()
            if not s.startswith(("MUSIC_FEATURE_", "SSG_FEATURE_", "AUDIO_PROFILE"))
        )
        + "\n"
    )
    (out / "audio_data.inc").write_text(text)

    def local(s):
        return re.sub(r"\b(jsr|jmp) ([A-Za-z_][\w]*)", r"\1 .loword(\2)", s)

    doc = (ROOT / "src/doc.s").read_text()
    doc = doc[doc.index("doc_write:") : doc.index("doc_init:")]
    doc = doc.replace("doc_write", "audio_doc_write").replace("doc_read", "audio_doc_read")
    irq = (
        (ROOT / "src/music_irq.s")
        .read_text()
        .replace("doc_write", "audio_doc_write")
        .replace("doc_read", "audio_doc_read")
    )
    (out / "audio_doc.inc").write_text(".a8\n.i16\n" + local(doc))
    (out / "audio_music_irq.inc").write_text(local(irq))
    host.sound_bank = True
    host.emit("AUDIO_GAME = 1")
    return meta


def install(host):
    return


def routines():
    return [
        '.include "audio_game.s"',
        '.segment "NATIVE"',
        '.segment "SOUND"',
        *[
            '.include "' + s + '"'
            for s in (
                "audio_data.inc",
                "audio_doc.inc",
                "audio_upload.s",
                "music_player.s",
                "fm_voice.s",
                "audio_music_irq.inc",
            )
        ],
        # Startup only: the bank initialization runs from the far sound segment.
        ".ifdef CONTINUOUS_GAME",
        '.segment "SOUND_EXTRA"',
        ".endif",
        '.include "audio_bank.inc"',
        ".ifdef CONTINUOUS_GAME",
        '.segment "SOUND"',
        ".endif",
        *['.include "' + s + '"' for s in ("audio_binary.s", "audio_ssg.s")],
        '.segment "NATIVE"',
    ]
