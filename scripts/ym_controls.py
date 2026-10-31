"""SSG part states of a sound effect, from the effect log of the sound program."""
import collections,struct
from functools import lru_cache
from sound_files import EFFECT_LOG

@lru_cache(maxsize=None)
def ssg_states(command):
    """Final state of each source part at every original driver tick.

    High/low period register transactions within one tick become one FREQ
    value. Keep the absolute time as well, for capture alignment/auditing.
    """
    regs=[bytearray(16),bytearray(16)];ticks=collections.defaultdict(dict);first=None
    for t,cmd,tick,chip,r,v in struct.iter_unpack('<dBIBBB',(EFFECT_LOG/'ym.bin').read_bytes()):
        if r>=16:continue
        regs[chip][r]=v
        if cmd!=command:continue
        if first is None:first=t
        for ch in range(6):
            z=regs[ch//3];local=ch%3
            ticks[tick][ch]=(t-first,max(1,z[local*2]|(z[local*2+1]&15)<<8),z[8+local],
                not bool(z[7]&(1<<local)),not bool(z[7]&(8<<local)),max(1,z[6]&31))
    result=[[]for _ in range(6)];previous=[None]*6
    for tick,parts in sorted(ticks.items()):
        for ch,state in parts.items():
            if state[1:]!=previous[ch]:result[ch].append((tick,*state));previous[ch]=state[1:]
    return result
