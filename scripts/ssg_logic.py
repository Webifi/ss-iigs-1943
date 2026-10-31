"""Build-time YM SSG mixer expressed by a DOC AM pair.

The SSG DAC is unipolar. Preserve its AND mixer directly: the odd DOC
oscillator supplies the tone/mixer/level gate, and the even oscillator
supplies the captured noise bit. No separately started correction tone.
These are two-state logic tables, not reduced-resolution audio decays.
"""

import numpy as np
from audio_config import DOC_RATE
from ssg_controls import mixed_bank, AMP
from ym_controls import ssg_states

ROTATIONS = 8
TICK = 6e6 / (384 * 262) * 4
# Effect states take effect every 8th sound tick (30 Hz, half the video
# frame rate). In listening comparisons of all effects this sounds the same
# as once per frame.
STEP = 8


def model(row,common_peak):
    shared,receipt=mixed_bank(common_peak)
    # Offset-binary 128 is zero output, 255 is the captured high state.
    # A byte of zero would halt the DOC and is never used for a low bit.
    noise=np.where(shared['stage_noise']>128,255,128).astype('u1')
    levels=[round(255*float(AMP[v*2+1])*.15/common_peak)if v else 0 for v in range(16)]
    polarity=shared['stage_tone']>128
    gates=np.concatenate([np.where(polarity,max(1,min(255,v)),1).astype('u1')for v in levels]+
        [np.full(256,max(1,min(255,v)),dtype='u1')for v in levels])
    # Tone alone plays a full-swing square on the even oscillator at half
    # the level (constant gate page v-2: the YM steps are 3 dB). A one-sided
    # table at full level would pass the volume register at volume 15. The
    # square starts from the rotation that continues the odd oscillator's
    # running tone phase, so a switch to or from tone and noise keeps it.
    square=np.where(polarity,255,1).astype('u1')
    waves=dict(stage_gate=gates,stage_noise=noise,stage_on=np.full(256,255,dtype='u1'),
        **{f'stage_square_{k}':np.roll(square,-k*256//ROTATIONS)for k in range(ROTATIONS)})
    states=ssg_states(row['command'])[row['channel']]
    if any(s[3]&16 for s in states):raise ValueError('source envelope commands need their ready level curve')
    pitches=[93750/s[2]for s in states if s[2]>=6]
    R=max(r for r in range(8)if max(pitches,default=0)*(1<<(17+r))/DOC_RATE<=65535)
    curve=[]
    for tick,t,p,v,on,noisy,n in states:
        ft=round(93750/p*(1<<(17+R))/DOC_RATE)if p>=6 else 0
        fn=round(93750/n/DOC_RATE*512)
        selector=v if on and p>=6 else 16+v
        curve.append((round(t*DOC_RATE),ft,fn,selector,noisy,bool(on and p<6)))
    return dict(source=row,frequency=0,step=min(pitches,default=0)*256/DOC_RATE,
        minimum_step=min(pitches,default=0)*256/DOC_RATE,body_peak=common_peak,attack_peak=common_peak,
        ssg_logic_curve=curve,tone_size=R,noise_size=54,am_tables=['stage_gate'],oscillators=2,
        hardware_mode='captured SSG AND mixer on a DOC AM pair',capture=receipt,
        table_roles=dict(stage_gate='unsigned AM logic and source levels',stage_noise='captured unipolar noise logic',stage_on='mixer disabled high state',**{f'stage_square_{k}':f'full-swing tone alone, {k}/{ROTATIONS} turn'for k in range(ROTATIONS)}),
        source_levels=levels,saturated_source_levels=[v for v,level in enumerate(levels)if level>255],
        cost=sum(map(len,waves.values()))),waves



def tick_curve(curve, tone_size):
    """The SSG states on sound ticks, as the native player steps them: a
    state takes effect at the next multiple of STEP ticks from the effect's
    start; the last state of each such tick wins. Flags: bit 0 noise, bit 1 ultrasonic tone,
    bits 2-4 the square rotation where tone alone starts, which continues
    the odd oscillator's running phase (its accumulator restarts with the
    effect)."""
    merged = {}
    for pos, ft, fn, selector, noisy, ultrasonic in curve:
        merged[-(-round(pos / DOC_RATE * TICK) // STEP) * STEP] = (
            ft,
            fn,
            selector,
            noisy,
            ultrasonic,
        )
    out = []
    phase = 0
    last = None
    was_alone = False
    for tick in sorted(merged):
        ft, fn, selector, noisy, ultrasonic = merged[tick]
        frame = round(tick * DOC_RATE / TICK)
        if last is not None:
            phase = (phase + last[1] * (frame - last[0])) & 0xFFFFFF
        last = (frame, ft)
        alone = selector < 16 and not noisy and selector >= 3
        rotation = (
            round(((phase >> (9 + tone_size)) & 255) * ROTATIONS / 256) % ROTATIONS
            if alone and not was_alone
            else 0
        )
        out.append((tick, ft, fn, selector, int(noisy) | int(ultrasonic) << 1 | rotation << 2))
        was_alone = alone
    return out


LIST_FILLER = 0x40  # a record that only waits
LIST_REPEAT = 0x80
LONGEST_DELAY = 254  # the native start adds one tick of count


def compact(model):
    """Native SSG list (src/audio_ssg.s): per record a delay byte, a change
    mask (bit 0 tone, 1 noise, 2 selector, 3 flags) and the changed fields.
    Longer gaps use filler records, exact repeats jump back, and a zero
    mask ends the list."""
    from audio_bank_codec import repeat_records

    states = tick_curve(model["ssg_logic_curve"], model["tone_size"])
    records = []
    prior = None
    last = 0
    expected = []
    for tick, *values in states:
        mask = sum(1 << i for i, v in enumerate(values) if prior is None or v != prior[i])
        if not mask:
            continue
        delay = tick - last
        records.append(
            bytes([delay, mask])
            + b"".join(
                v.to_bytes(2 if i < 2 else 1, "little")
                for i, v in enumerate(values)
                if mask >> i & 1
            )
        )
        prior = values
        last = tick
        expected.append((tick, *values))
    data = repeat_records(records) + b"\0\0"
    assert decode_list(data) == expected
    return data


def decode_list(data):
    p = t = 0
    state = [0] * 4
    out = []
    loop = -1
    left = 0
    while True:
        origin = p
        delay, mask = data[p], data[p + 1]
        p += 2
        t += delay
        if mask == 0:
            return out
        if mask == LIST_REPEAT:
            copies = data[p]
            target = int.from_bytes(data[p + 1 : p + 3], "little")
            p += 3
            assert delay == 0 and target < origin
            if loop != origin:
                loop = origin
                left = copies
            if left:
                left -= 1
                p = target
            else:
                loop = -1
            continue
        for i in range(4):
            if mask >> i & 1:
                n = 2 if i < 2 else 1
                state[i] = int.from_bytes(data[p : p + n], "little")
                p += n
        out.append((t, *state))
