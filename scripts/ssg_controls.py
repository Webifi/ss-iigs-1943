"""Captured SSG tone and noise tables, shared by all sound effects.

The tables come from the original parts, rendered from the effect log. No
square-wave substitute, no random-number noise.
"""
import json,math,subprocess
from functools import lru_cache
import numpy as np
from audio_config import DOC_RATE
from sound_model import resample,quantize_table,readwav
from ym_controls import ssg_states
from sound_files import EFFECTS,EFFECT_LOG,RENDERER,WORK

# YMFM SSG amplitude table, ymfm_ssg.cpp s_amplitudes. YM2203 fixed volume
# indexes the odd entries; the zero volume entry is explicitly silent.
AMP=np.array([0,32,78,141,178,222,262,306,369,441,509,585,701,836,965,1112,
              1334,1595,1853,2146,2576,3081,3576,4135,5000,6006,7023,8155,9963,11976,14132,16382])

def tone(row):
    states=ssg_states(row['command'])[row['channel']]
    if any(v and noisy for _,t,p,v,on,noisy,n in states):raise ValueError('captured mixed/noise timbre required')
    if any(v&16 for _,t,p,v,on,noisy,n in states):raise ValueError('SSG envelope needs its captured control curve')
    active=[s for s in states if s[3] and s[4] and s[2]>=8]
    if not active:raise ValueError('no audible stable tone')
    pitch=[93750/s[2]for s in active];low,high=min(pitch),max(pitch)
    N=max(256,1<<math.ceil(math.log2(DOC_RATE/low)))
    if N>32768:raise ValueError('tone table outside DOC')
    R=max(r for r in range(8)if round(high*(1<<(17+r))/DOC_RATE)<=65535)
    candidates=[]
    for i,state in enumerate(states[:-1]):
        _,t,p,v,on,noisy,n=state;duration=states[i+1][1]-t
        if v and on and p>=8 and duration>p/93750*3:candidates.append((duration,state))
    if not candidates:raise ValueError('no captured whole-period interval')
    duration,state=max(candidates);_,start,period,volume,*_=state
    raw,rate=readwav(row['file']);start+=duration/3
    highrate=resample(raw,rate,rate*8)
    positions=(start+np.arange(N)/N*period/93750)*rate*8
    wave=np.interp(positions,np.arange(len(highrate)),highrate);wave-=wave.mean()
    peak=float(max(abs(wave)));wave=quantize_table(wave/peak,N*93750/period)
    # One common captured level scale; volume moves come from YM writes.
    max_volume=max(s[3]for s in active);maximum=AMP[max_volume*2+1]
    model_peak=peak*maximum/AMP[volume*2+1]
    curve=[]
    for tick,t,p,v,on,noisy,n in states:
        audible=v and on and p>=8
        fc=round((93750/p)*(1<<(17+R))/DOC_RATE)if audible else 0
        level=round(255*AMP[v*2+1]/maximum)if audible else 0
        curve.append((max(0,round(t*DOC_RATE)),fc,level))
    model=dict(frequency=0,step=low*N/DOC_RATE,minimum_step=low*N/DOC_RATE,
        attack_peak=model_peak,body_peak=model_peak,switch_sample=0,cost=N,
        control_curve=curve,control_size=(N.bit_length()-9)*8+R,
        source_interval=[start,start+period/93750],oscillators=1,
        hardware_mode='SSG FREQ/VOL',source_period=period,
        ultrasonic_period_policy='Periods below 8 have no representable AC carrier; scored against the complete source')
    return model,dict(attack=wave,frequency=np.array(0),envelope=np.empty((0,2),int))

def noise_start():
    """Start of the noise-only state of FX18 part 0: volume 13, noise period 7."""
    return next(t for tick,t,p,v,on,noisy,n in ssg_states(24)[0]if noisy and not on and v==13 and n==7)

def noise_bits():
    """The shared noise table: one byte per noise clock of the FX18 noise-only
    state, read at its bit midpoint. The held render replays all earlier
    writes, then freezes that state; no random-number generator."""
    noise_path=WORK/'ssg-noise-held.raw'
    start=noise_start()
    WORK.mkdir(parents=True,exist_ok=True)
    subprocess.run([str(RENDERER),str(EFFECT_LOG/'ym.bin'),
        '24',str(noise_path),'2.5',str(start),str(start+7e-4)],check=True,stdout=subprocess.DEVNULL)
    raw=np.memmap(noise_path,'<i2',mode='r').reshape(-1,14)[:,3]
    positions=(np.arange(16384)+.5)*7/93750*125000
    values=np.interp(positions,np.arange(len(raw)),raw)
    (EFFECTS/'noise-bits.bin').write_bytes(np.where(values>(float(raw.max())+float(raw.min()))/2,255,1).astype('u1').tobytes())
    del raw;noise_path.unlink()

@lru_cache(maxsize=4)
def mixed_bank(common_peak):
    """Shared, captured tone/noise data for the six original SSG parts.

    Tone*noise is represented by an AM pair plus its tone/DC correction.
    All waves come from actual effect channels. No procedural square/noise
    source and no duplicate voices used simply to increase gain.
    """
    row=next(r for r in json.loads((EFFECTS/'captures.json').read_text())if r['command']==11)
    row=dict(row,channel=0,file=str(EFFECTS/'0b/ssg-0.wav'))
    m,_=tone(row);raw,rate=readwav(row['file']);lo,hi=m['source_interval']
    count=256
    # One period of the capture, read from an 8x resample: the cut never
    # depends on where the period edges fall between source samples.
    highrate=resample(raw,rate,rate*8)
    wave=np.interp((lo+np.arange(count)/count*(hi-lo))*rate*8,np.arange(len(highrate)),highrate)
    wave-=wave.mean();peak=max(abs(wave));unit=np.clip(wave/peak,-1,1)
    tone_peak15=float(AMP[31])*.15/2
    # Keep the captured polarity and duty cycle. The DOC output filter,
    # not a filter baked at one root pitch, supplies the final bandwidth.
    unit=np.where(unit>=0,1.,-1.)
    carrier=quantize_table(unit,count/(hi-lo))
    bit_path=EFFECTS/'noise-bits.bin'
    rate=125000;start=noise_start();count_noise=16384
    seconds=count_noise*7/93750
    # One sample per original noise clock, read at its bit midpoint. The
    # held capture replays all earlier writes before freezing FX18's actual
    # noise-only state; no random-number generator or synthetic noise.
    noise_table=np.frombuffer(bit_path.read_bytes(),dtype='u1').copy()
    # The captured AC peak at volume13 gives the fixed YM->DOC scale.
    # Do not fit output gain to the reference or a comparison score.
    peak15=float(AMP[31])*.15/2
    volumes=[round(255*peak15*AMP[v*2+1]/AMP[31]/common_peak)if v else 0 for v in range(16)]
    tone_volumes=[round(255*tone_peak15*AMP[v*2+1]/AMP[31]/common_peak)if v else 0 for v in range(16)]
    if max(volumes)>255:raise ValueError('SSG amplitude exceeds DOC register')
    gates=np.concatenate([np.where(unit>0,max(1,v),1).astype('u1')for v in volumes]+
        [np.full(count,max(1,v),dtype='u1')for v in volumes])
    return dict(stage_gate=gates,stage_noise=noise_table,stage_tone=carrier),dict(
        tone_file=row['file'],tone_interval=[lo,hi],noise_file=str(bit_path),noise_interval=[start,start+seconds],
        noise_period=7,noise_volume=13,volumes=volumes,tone_volumes=tone_volumes,tone_bytes=count,noise_bytes=count_noise,noise_seconds=seconds,
        formula='A*(tone*noise-1/4) = A/2*tone*(2*noise-1) + A/4*(2*tone-1)',
        sharing='All effects reference the same tables; counted once in a packaged bank')
