"""Final FM form: captured single-cycle tables and ready envelope events.

No recorded attack or fixed release sample. Both oscillators run the same
phase/frequency; the even one syncs its odd partner. Pointer changes target
the muted member, followed by a prepared crossfade.
"""
import math,struct
from pathlib import Path
import numpy as np
from audio_config import DOC_RATE
from sound_model import readwav,quantize

TICK=6e6/(384*262)*4
TABLE_BYTES=256
MAX_SNAPSHOTS=12
SLOT_BYTES=MAX_SNAPSHOTS*256
TABLE_LIMIT=2048
MOST_SNAPSHOTS=6
CUTOFF_HZ=11000
TABLE_RATE_HZ=20000
FADE_TICKS=2

def pitch(word):
    return (1500000/36)*(((word&2047)<<((word>>11)&7))>>1)/(1<<21)

STEP_DB=.375
FLOOR_STEPS=255
TOLERANCE_DB=.25

def tolerance(down):
    """Half a volume-register step at this depth below register 255, never
    finer than TOLERANCE_DB: the register cannot play a finer change."""
    v=255*10**(-down/20)
    return max(TOLERANCE_DB,10*math.log10((v+1)/v)if v>0 else 99)

def envelope_segments(volume,peak):
    """Carrier EG as (ticks, attenuation step) points joined by dB lines."""
    db=[-20*math.log10(max(v/peak,1e-12))for v in volume]
    steps=[min(FLOOR_STEPS,round(d/STEP_DB))for d in db]
    points=[(0,steps[0])];i=0
    while i<len(db)-1:
        best=i+1
        for j in range(i+2,min(len(db),i+256)):
            a,b=steps[i]*STEP_DB,steps[j]*STEP_DB
            if all(abs(a+(b-a)*(k-i)/(j-i)-min(db[k],FLOOR_STEPS*STEP_DB))<=tolerance(db[k])for k in range(i+1,j)):best=j
            else:break
        points.append((best-i,steps[best]));i=best
    return points

PRUNE_DB=-40

def prune(kept,units,most):
    """Drop the snapshot that the player's crossfade of its neighbours
    replaces best, while that error is within PRUNE_DB or more than `most`
    remain. The first snapshot stays; one table holds the whole note."""
    kept=list(kept)
    if most==1:
        # One table for the whole note: the stage nearest all others in
        # harmonic magnitudes, since nothing crossfades.
        return [min(kept,key=lambda c:sum(np.sum((abs(units[c])-abs(units[t]))**2)for t in kept))]
    def error(i):
        a,t,b=kept[i-1],kept[i],kept[i+1];alpha=(t-a)/(b-a)
        mix=(1-alpha)*units[a]+alpha*units[b]
        return 10*math.log10(max(1e-30,np.sum(abs(mix-units[t])**2))/max(1e-30,np.sum(abs(units[t])**2)))
    while len(kept)>2:
        worst=min(range(1,len(kept)-1),key=error)
        if error(worst)>PRUNE_DB and len(kept)<=most:break
        del kept[worst]
    return kept

RELEASE_MATCH_DB=.5
RELEASE_END_DB=-60

def release_set(path,waves):
    """Relative release curve for each played hold, shared when two agree
    within RELEASE_MATCH_DB down to -60 dB. Decoded curves go in waves."""
    curves=dict(np.load(path));unique=[];decoded=[];holds={}
    for key in sorted(curves,key=lambda k:int(k[5:])):
        hold=int(key[5:]);amp=curves[key].astype(float)
        rel=[min(1.,v/max(amp[hold],1e-12))for v in amp[hold:]]
        # Below RELEASE_END_DB the volume register is already zero.
        live=[i for i,v in enumerate(rel)if v>=10**(RELEASE_END_DB/20)]
        rel=rel[:(live[-1]+2)if live else 2]
        points=envelope_segments(rel,1.)
        curve=np.asarray(decode_segments(points,len(rel),1.))
        db=20*np.log10(np.maximum(curve,1e-6))
        for i,other in enumerate(decoded):
            n=max(len(db),len(other));a=np.pad(db,(0,n-len(db)),constant_values=-120);b=np.pad(other,(0,n-len(other)),constant_values=-120)
            live=(a>-60)|(b>-60)
            if np.max(abs(np.maximum(a,-60)-np.maximum(b,-60))[live])<=RELEASE_MATCH_DB:holds[hold]=i;break
        else:
            holds[hold]=len(unique);unique.append(points);decoded.append(db)
            waves[f'fall_{len(unique)-1:02d}']=curve.astype('<f4')
    return unique,holds

def decode_segments(points,length,peak):
    curve=[points[0][1]*STEP_DB];level=points[0][1]
    for ticks,target in points[1:]:
        curve+=[(level+(target-level)*k/ticks)*STEP_DB for k in range(1,ticks+1)];level=target
    curve+=[curve[-1]]*(length-len(curve))
    return [0.0 if d>=FLOOR_STEPS*STEP_DB else peak*10**(-d/20)for d in curve[:length]]

def convert(row,common_peak):
    raw,rate=readwav(row['file'])
    env=dict(np.load(row['envelope_file']))
    gain=np.interp(np.arange(len(raw))/rate,np.arange(len(env['envelope']))/float(env['rate']),env['envelope'])
    # The divisor is the actual YM carrier EG, not a fitted output gain.
    unit=np.divide(raw,gain,out=np.zeros_like(raw),where=gain>max(gain)*1e-4)
    base=pitch(row['fnum']);period=rate/base
    # A half-rate operator repeats over two fundamental cycles. The source
    # patch's multiplier data chooses this; retaining two periods for every
    # patch would unnecessarily halve the available harmonic resolution.
    multipliers=[row['context'][0x30+row['channel']%3+4*i]&15 for i in range(4)]
    cycles=2 if 0 in multipliers else 1
    period*=cycles
    hold=round(row['hold_seconds']*TICK)
    ticks=sorted(set([0]+[round(v)for v in np.geomspace(FADE_TICKS,max(FADE_TICKS,hold-1),MAX_SNAPSHOTS-1)]))
    kept=[]
    for t in ticks:
        if not kept or t-kept[-1]>=FADE_TICKS:kept.append(t)
    capture=Path(row['file']).with_suffix('.cycles.npz')
    if not capture.exists():raise ValueError('Frozen-EG stage captures must be built first')
    frozen=dict(np.load(capture))
    # The pitches this table really plays: the player takes the capture
    # nearer in log pitch. No harmonic may pass the board filter's cutoff at
    # the highest of them, and the table rate at the lowest keeps the DOC's
    # held-sample images above that cutoff.
    played=[pitch(w)for w in row['plan']['played_fnums']]
    root,top=pitch(row['plan']['root_fnum']),pitch(row['plan']['played_fnums'][-1])
    mine=[f for f in played if(abs(math.log2(f/root))<=abs(math.log2(f/top)))==(row['capture_kind']=='root')]or[base]
    limit=max(1,math.floor(min(DOC_RATE/2,CUTOFF_HZ)*cycles/max(mine)))
    wanted=1<<max(8,math.ceil(math.log2(max(2*limit+2,TABLE_RATE_HZ*cycles/min(mine)))))
    table_bytes=min(TABLE_LIMIT,wanted)
    units={};prior=None
    for t in kept:
        eg=float(gain[min(len(gain)-1,round(max(.001,t/TICK)*rate))])
        spectrum=frozen[f'harmonics_{t}'].astype(complex)/max(1e-12,eg)
        spectrum[0]=0;spectrum[min(limit,table_bytes//2-1)+1:]=0
        # A noise-like patch: one period is a random sample of its spectrum.
        # Use the harmonic levels averaged over many periods, all stages on
        # one phase set, so the crossfade pair always adds in phase.
        if row.get('aperiodic'):
            level=frozen[f'level_{t}'].astype(float)/max(1e-12,eg);level[0]=0;level[min(limit,table_bytes//2-1)+1:]=0
            spectrum=level*np.exp(1j*np.angle(prior if prior is not None else np.fft.rfft(frozen[f'cycle_{t}'].astype(float))))
        # Detune moves the chip's phase away from the nominal period. Turn
        # each stage to its best match with the stage before it, so that
        # the crossfade pair adds in phase.
        elif prior is not None:
            lag=int(np.argmax(np.fft.irfft(prior*np.conj(spectrum),2048)))
            spectrum=spectrum*np.exp(-2j*np.pi*np.arange(len(spectrum))*lag/2048)
        units[t]=prior=spectrum
    kept=prune(kept,units,max(1,min(MOST_SNAPSHOTS,SLOT_BYTES//table_bytes)))
    waves={};schedule=[];scales=[];dither=[]
    from scipy.signal import resample
    for t in kept:
        cycle=resample(np.fft.irfft(units[t],2048),table_bytes)
        scale=max(1e-12,float(max(abs(cycle))))
        q,receipt=quantize(cycle/scale*(127/128),table_bytes*base/cycles)
        name=next((k for k,v in waves.items()if np.array_equal(v,q)),None)
        if name is None:name=f'stage_{len(waves):02d}';waves[name]=q
        schedule.append((t,name));scales.append(scale);dither.append(receipt)
    # Table RMS and the correlation of each scheduled pair let the player
    # keep the interpolated loudness through a crossfade of unlike shapes.
    signed={k:waves[k].astype(float)-128 for k in waves}
    rms=[float(np.sqrt(np.mean(signed[k]**2)))/127 for _,k in schedule]
    rho=[float(np.dot(signed[a],signed[b])/max(1e-12,np.sqrt(np.dot(signed[a],signed[a])*np.dot(signed[b],signed[b]))))
        for (_,a),(_,b) in zip(schedule,schedule[1:])]
    # Frequency is the repeat rate of the two-period table. The octave
    # range, not just the root, constrains the 16-bit frequency register.
    high=max(pitch(w)for w in row['plan']['played_fnums'])/cycles
    R=max(r for r in range(8)if round(high*(1<<(17+r))/DOC_RATE)<=65535)
    fc=round(base/cycles*(1<<(17+R))/DOC_RATE)
    length=math.ceil(len(raw)/rate*TICK)+1
    volume=[]
    for t in range(length):
        lo=min(len(gain)-1,round(t/TICK*rate));hi=min(len(gain),max(lo+1,round((t+1)/TICK*rate)))
        volume.append(float(np.sqrt(np.mean(gain[lo:hi]**2))))
    # The player steps straight dB lines between stored points. Every user
    # of the model hears the decoded curve, not the measured one.
    peak=max(volume);segments=envelope_segments(volume,peak)
    amplitude=np.asarray(decode_segments(segments,length,peak),dtype='<f4')
    waves['amplitude_ticks']=amplitude
    releases,release_holds=release_set(Path(row['file']).with_suffix('.releases.npz'),waves)
    return dict(source=row,snapshot_version=2,snapshot_schedule=schedule,snapshot_scales=scales,
        frequency=fc,frequency_size=(table_bytes.bit_length()-9)*8+R,cycles_per_table=cycles,operator_multipliers=multipliers,source_pitch=base,
        snapshot_capture_sha256=__import__('hashlib').sha256(capture.read_bytes()).hexdigest(),
        step=base/cycles*table_bytes/DOC_RATE,minimum_step=min(pitch(w)for w in row['plan']['played_fnums'])/cycles*table_bytes/DOC_RATE,
        step_one_bytes=1<<max(8,math.ceil(math.log2(DOC_RATE*cycles/min(pitch(w)for w in row['plan']['played_fnums'])))),
        hold_tick=hold,release_ticks=max(0,length-hold),frames=round(len(raw)/rate*DOC_RATE),
        envelope_segments=segments,envelope_peak=peak,snapshot_rms=rms,snapshot_rho=rho,release_segments=releases,release_holds=release_holds,
        body_peak=common_peak,attack_peak=common_peak,volume=255,oscillators=2,
        hardware_mode='single-cycle snapshots with synchronized crossfade pair',
        dither=dither,quality_pending=True,passed=False),waves
