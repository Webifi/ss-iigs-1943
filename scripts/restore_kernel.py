"""Compact old-object rectangles; identical four-plane latch copies."""


def merge_hud_runs(runs):
    merged = []
    for offset, count in sorted(runs):
        if merged and 0 <= offset - sum(merged[-1]) <= 16:
            merged[-1] = (merged[-1][0], offset + count - merged[-1][0])
        else:
            merged.append((offset, count))
    return merged


