"""Isolated instrument notes: each patch alone on a fresh YM, from silence.

A note cut out of a song carries that song's next key-on, re-keys and level
changes. Here the patch registers from the song context are written to an
idle channel, keyed on for the longest hold that any song plays with this
sample, then keyed off and run until the release is below the 16-bit floor.
The same YMFM build-time renderer gives PCM, carrier EG and frozen-EG cycles.
"""
import json,math,os,struct,subprocess
from collections import defaultdict
from concurrent.futures import ProcessPoolExecutor
from functools import lru_cache
from pathlib import Path
import numpy as np
from sound_files import INSTRUMENTS as OUT,SCORE_LOG,SCORE,RENDERER,WORK
from sound_model import resample,wav
from fm_snapshots import pitch,TICK,MAX_SNAPSHOTS,FADE_TICKS

LOG=SCORE_LOG/'ym.bin'
COMMAND=99
SETUP=1.0
KEY=1.05
MINIMUM_HOLD=.25
RELEASE_LIMIT=8.0

def stages(row):
    """The EG ticks of the snapshot captures of a note."""
    hold=round(row['hold_seconds']*TICK)
    candidates=sorted(set([0]+[round(v)for v in np.geomspace(FADE_TICKS,max(FADE_TICKS,hold-1),MAX_SNAPSHOTS-1)]))
    kept=[]
    for t in candidates:
        if not kept or t-kept[-1]>=FADE_TICKS:kept.append(t)
    return kept

def longest_holds():
    from music_score import expand
    info=json.loads((SCORE/'score.json').read_text());score=(SCORE/'score.bin').read_bytes()
    hold=defaultdict(float)
    for p in info['parts']:
        horizon=p['end_tick']+(p['loop']['end_tick']if p['loop']else 0)
        events,_=expand(score[p['offset']:p['offset']+p['bytes']],horizon)
        i=0
        while i<len(events):
            e=events[i]
            if e[1]!='on':i+=1;continue
            j=i+1
            while j<len(events)and not(events[j][1]=='on'and not(events[j][2]&128)):j+=1
            off=next((q[0]for q in events[i+1:j]if q[1]=='off'),events[j][0]if j<len(events)else e[0])
            hold[e[2]&127]=max(hold[e[2]&127],(off-e[0])/TICK)
            i=j
    return hold

def patch_writes(row):
    chip,slot=row['channel']//3,row['channel']%3;context=row['context']
    regs=[base+slot+4*k for base in range(0x30,0xa0,0x10)for k in range(4)]
    regs+=[0xb0+slot,0xa4+slot,0xa0+slot]
    return chip,slot,[(reg,context[reg])for reg in regs]

AVERAGE_PERIODS=16
APERIODIC=.8

@lru_cache(maxsize=None)
def init_writes():
    """The prescaler writes of the sound program's start, before SETUP."""
    source=struct.iter_unpack('<dBIBBB',LOG.read_bytes())
    return [(t,0,0,c,r,d)for t,cmd,_,c,r,d in source if cmd==0 and t<SETUP and r in(0x2d,0x2e,0x2f)]

def render(row,hold,name):
    chip,slot,writes=patch_writes(row)
    log=list(init_writes())
    log+=[(SETUP+i*1e-5,COMMAND,0,chip,r,d)for i,(r,d)in enumerate(writes)]
    log+=[(KEY,COMMAND,0,chip,0x28,0xf0|slot),(KEY+hold,COMMAND,0,chip,0x28,slot)]
    seconds=hold+RELEASE_LIMIT
    multipliers=[row['context'][0x30+slot+4*i]&15 for i in range(4)]
    cycles=2 if 0 in multipliers else 1;period=cycles/pitch(row['fnum'])
    ticks=stages(dict(hold_seconds=hold))
    requests=[(KEY+max(.001,t/TICK),row['channel'],math.ceil(period*AVERAGE_PERIODS*125000)+8,t)for t in ticks]
    base=WORK/(name+'-isolated')
    logfile=base.with_suffix('.log');pcm=base.with_suffix('.pcm');env=base.with_suffix('.eg');req=base.with_suffix('.requests')
    logfile.write_bytes(b''.join(struct.pack('<dBIBBB',*w)for w in log))
    req.write_bytes(b''.join(struct.pack('<dBI',t,c,n)for t,c,n,_ in requests))
    subprocess.run([str(RENDERER),str(logfile),str(COMMAND),str(pcm),str(seconds),str(KEY-SETUP),'1e99',str(env),str(req)],check=True,stdout=subprocess.DEVNULL)
    index=row['channel']if row['channel']<3 else row['channel']+4
    x=np.fromfile(pcm,'<i2').reshape(-1,14)[:,index].astype(float)
    g=np.fromfile(env,'<f4').reshape(-1,6)[:,row['channel']].astype(float)
    generated=Path(str(req)+'.raw').read_bytes();at=0;parts={}
    for t,c,n,tick in requests:
        rate=struct.unpack_from('<I',generated,at)[0];at+=4
        wave=np.frombuffer(generated,'<i2',n,at).astype(float)*.1;at+=n*2
        age=t-KEY;phase=(age/period)%1
        start=(1-phase)%1*period*rate
        held=[np.interp(start+(j+np.arange(2048)/2048)*period*rate,np.arange(len(wave)),wave)for j in range(AVERAGE_PERIODS)]
        parts[f'cycle_{tick}']=held[0].astype('<f4')
        # RMS harmonic levels over AVERAGE_PERIODS periods, and how well each
        # period matches the next. A noise-like patch does not repeat.
        parts[f'level_{tick}']=np.sqrt(np.mean([abs(np.fft.rfft(h))**2 for h in held],axis=0)).astype('<f4')
        parts[f'match_{tick}']=np.float32(np.median([np.corrcoef(a,b)[0,1]for a,b in zip(held,held[1:])]))
        # Harmonics read over all periods through a Hann window. Detuned
        # carriers never close one period exactly; a single cut period
        # leaks its seam jump into false components.
        window=np.hanning(2048*AVERAGE_PERIODS)
        spectrum=np.fft.rfft(np.concatenate(held)*window)[::AVERAGE_PERIODS]*2048/window.sum()
        parts[f'harmonics_{tick}']=spectrum.astype('<c8')
    assert at==len(generated)
    for p in (logfile,pcm,env,req,Path(str(req)+'.raw')):p.unlink()
    # Trim the release where the carrier and the output are both below the
    # 16-bit floor of the scaled capture. The hold is never trimmed.
    y=resample(x,125000,48000)*.1
    level=np.abs(y)>.5
    after=round(hold*48000)
    last=after+int(np.max(np.nonzero(level[after:])[0]))+1 if level[after:].any()else after
    last=min(len(y),last+480)
    return y[:last],g[:round(last/48000*125000)]*.1,parts

def note_holds():
    """Every key-on to key-off length, in ticks, that the songs play per sample."""
    from music_score import expand
    info=json.loads((SCORE/'score.json').read_text());score=(SCORE/'score.bin').read_bytes()
    holds=defaultdict(set)
    for p in info['parts']:
        horizon=p['end_tick']+(p['loop']['end_tick']if p['loop']else 0)
        events,_=expand(score[p['offset']:p['offset']+p['bytes']],horizon)
        i=0
        while i<len(events):
            e=events[i]
            if e[1]!='on':i+=1;continue
            j=i+1
            while j<len(events)and not(events[j][1]=='on'and not(events[j][2]&128)):j+=1
            off=next((q[0]for q in events[i+1:j]if q[1]=='off'),None)
            if off is not None:holds[e[2]&127].add(off-e[0])
            i=j
    return holds

def release_curves(row,holds,name):
    """Carrier EG per tick for each hold. Carriers with unequal release rates
    make the release shape depend on the key-off time."""
    chip,slot,writes=patch_writes(row);curves={}
    base=WORK/(name+'-release')
    logfile=base.with_suffix('.log');env=base.with_suffix('.eg')
    for hold in sorted(holds):
        log=list(init_writes())
        log+=[(SETUP+i*1e-5,COMMAND,0,chip,r,d)for i,(r,d)in enumerate(writes)]
        log+=[(KEY,COMMAND,0,chip,0x28,0xf0|slot),(KEY+hold/TICK,COMMAND,0,chip,0x28,slot)]
        logfile.write_bytes(b''.join(struct.pack('<dBIBBB',*w)for w in log))
        subprocess.run([str(RENDERER),str(logfile),str(COMMAND),'-',str(hold/TICK+RELEASE_LIMIT),str(KEY-SETUP),'1e99',str(env)],check=True,stdout=subprocess.DEVNULL)
        g=np.fromfile(env,'<f4').reshape(-1,6)[:,row['channel']].astype(float)*.1
        ticks=int(len(g)/125000*TICK)
        amp=np.array([np.sqrt(np.mean(g[round(t/TICK*125000):max(round(t/TICK*125000)+1,round((t+1)/TICK*125000))]**2))for t in range(ticks)])
        alive=np.nonzero(amp>amp.max()*10**(-96/20))[0]
        curves[f'hold_{hold}']=amp[:max(hold+2,int(alive[-1])+2 if len(alive)else hold+2)].astype('<f4')
    for p in (logfile,env):p.unlink()
    return curves

def capture_note(row,hold,played):
    """The files of one note: PCM, carrier EG, frozen-EG cycles, release curves."""
    name=f'sample-{row["sample"]:02d}-{row["kind"]}'
    y,g,parts=render(row,hold,name)
    path=OUT/(name+'.wav');wav(path,y)
    np.savez_compressed(OUT/(name+'.eg.npz'),envelope=g,rate=125000)
    np.savez_compressed(OUT/(name+'.cycles.npz'),**parts)
    match=float(np.median([v for k,v in parts.items()if k.startswith('match_')]))
    row=dict(row,period_match=match,aperiodic=match<APERIODIC)
    np.savez_compressed(OUT/(name+'.releases.npz'),**release_curves(row,played,name))
    return dict(row,file=str(path),envelope_file=str(OUT/(name+'.eg.npz')),hold_seconds=hold,duration_seconds=len(y)/48000,
        start=KEY,off=KEY+hold,end=KEY+len(y)/48000,fresh=True,source='isolated YMFM note from song-context patch registers')

def capture(rows):
    """ROWS: the song notes of scripts/instrument_library.py. The notes
    render in parallel, one process for each CPU core."""
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    holds=longest_holds();played=note_holds()
    jobs=[(row,max(MINIMUM_HOLD,holds[row['sample']]),played[row['sample']])for row in rows]
    with ProcessPoolExecutor(os.cpu_count())as pool:
        result=list(pool.map(capture_note,*zip(*jobs)))
    (OUT/'captures.json').write_text(json.dumps(result,indent=2)+'\n')
    return result
