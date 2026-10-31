"""Build-time foreground rows and native IIgs placement for the live component.

Rows are ROM-derived spatial data, indexed by the current camera. They are not
frame command recordings. This first integration covers a fixed pan and the
normal sea:+1 / foreground:+2 path, before a physical ring-start wrap.
"""

from stream_scene import StreamScene

FG_BANK = 0x3B
CHAR_BANK = 0x3C
FG_ROW = 0x3370
FG_LITERAL = 0x3372


class LiveScene(StreamScene):
    maximum_rectangle_width = 5

def runs(masks):
    result = []
    x = 0
    while x < 56:
        if not masks[x]:
            x += 1
            continue
        end = x + 1
        while end < 56 and masks[end] == masks[x]:
            end += 1
        result.append((x, end - x, masks[x]))
        x = end
    return result


def prepare(scene, pool, initial, updates, pan=0):
    from world_stream import prepare as game_prepare

    return game_prepare(scene, pool, initial)


def compile_rows(out, host, scene, config):
    from world_stream import install as install_game

    return install_game(out, host, scene)
