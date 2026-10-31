"""The DOC sound bank: waveform tables and native tick records of all sounds.

bank.bin is the payload that the game installs. models.json, fit.json and
one NPZ file of tables per sound are the inputs of the game's sound player
build (scripts/fm_native.py, scripts/audio_bank_install.py).
"""
import json,os,struct
from concurrent.futures import ProcessPoolExecutor
from itertools import repeat
from pathlib import Path
import numpy as np
from audio_config import DOC_RATE,DOC_VOICES,DOC_TIMER,FM_PAIRS,SSG_VOICES,MASTER_GAIN,CHIME_PEAK
from audio_preview import layout
from audio_bank_codec import wave_encode,wave_decode
from fm_snapshots import convert,MAX_SNAPSHOTS
from ssg_logic import model as ssg_model,compact as ssg_compact
from sound_model import readwav
from sound_files import INSTRUMENTS,EFFECTS,BANK as OUT


def source_rows():
    library=json.loads((INSTRUMENTS/'captures.json').read_text())
    rows=[dict(r,name=Path(r['file']).stem,kind='instrument',capture_kind=r['kind'])for r in library]
    for r in json.loads((EFFECTS/'captures.json').read_text()):
        for channel in r['channels']:
            rows.append(dict(r,name=f'effect-{r["command"]:02x}-part{channel}',kind='effect',channel=channel,
                file=str(EFFECTS/f'{r["command"]:02x}/ssg-{channel}.wav'),hold_seconds=r['duration']))
    return rows


def reference_gain():
    """The startup sound peak over the peak of the loudest sound effect at
    the chip output, before any resampler adds overshoot to its edges."""
    return CHIME_PEAK/max(r['peak']for r in json.loads((EFFECTS/'captures.json').read_text()))


def model(source,common):
    """The DOC model and tables of one instrument capture or effect part."""
    if source['kind']=='instrument':return convert(source,common)
    m,w=ssg_model(source,common)
    raw,rate=readwav(source['file']);m.update(frames=round(len(raw)/rate*DOC_RATE),volume=255,passed=False,quality_pending=True)
    return m,w


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    common=(127*255/8)*MASTER_GAIN*(34/(DOC_VOICES+2))/reference_gain()
    rows=[];pool=[];binary=set();lookup={};records=bytearray();index=[]
    sources=source_rows()
    with ProcessPoolExecutor(os.cpu_count())as workers:
        models=list(workers.map(model,sources,repeat(common)))
    for source,(m,w) in zip(sources,models):
        name=source['name'];m.update(name=name,doc_rate=DOC_RATE,enabled_count=DOC_VOICES)
        ids={}
        for key,value in w.items():
            if not key.startswith('stage_'):continue
            raw=value.tobytes()
            if raw not in lookup:lookup[raw]=len(pool);pool.append(raw)
            ids[key]=lookup[raw]
            if source['kind']=='effect':binary.add(ids[key])
        start=len(records)
        if source['kind']=='instrument':
            # Carrier EG as (ticks, 0.375 dB attenuation) points. The player
            # steps a straight dB line between points.
            peak=m['envelope_peak'];segments=m['envelope_segments']
            records+=struct.pack('<BBHHHH',2,len(m['snapshot_schedule']),m['frequency'],m['frequency_size'],m['hold_tick'],len(segments))
            for (tick,key),scale in zip(m['snapshot_schedule'],m['snapshot_scales']):
                level=round(255*peak*scale/common)
                records+=struct.pack('<HHH',tick,ids[key],max(0,min(65535,level)))
            records+=bytes(v for point in segments for v in point)
            # Relative release curves, then each played hold's curve.
            records+=bytes([len(m['release_segments'])])
            for curve in m['release_segments']:records+=bytes([len(curve)])+bytes(v for point in curve for v in point)
            records+=bytes([len(m['release_holds'])])+b''.join(struct.pack('<HB',int(h),i)for h,i in m['release_holds'].items())
        else:
            records+=struct.pack('<BBHHH',3,m['tone_size'],ids['stage_gate'],ids['stage_noise'],ids['stage_on'])
            records+=b''.join(struct.pack('<H',ids[f'stage_square_{k}'])for k in range(8))
            records+=ssg_compact(m)
        m.update(bytes=sum(len(v)for k,v in w.items()if k.startswith('stage_')),pool_ids=ids,pages=sum(len(v)//256 for k,v in w.items()if k.startswith('stage_')),
            native_record=[start,len(records)-start])
        index.append((start,len(records)-start));rows.append(m)
        np.savez_compressed(OUT/(name+'.npz'),**w)
    # FM snapshots remain directly addressable. Shared two-state SSG pages
    # expand once at startup, straight to DOC RAM, without a host copy.
    directory=bytearray();waves=bytearray();decoded_wave_bytes=0;packed_tables=0
    for ident,b in enumerate(pool):
        kind,encoded=wave_encode(b,ident in binary)
        assert wave_decode(kind,encoded)==b
        directory+=struct.pack('<IHHB',len(waves),len(encoded),len(b),kind)
        waves+=encoded;decoded_wave_bytes+=len(b);packed_tables+=bool(kind)
    payload=b'SS43WAV2'+struct.pack('<HHII',len(rows),len(pool),len(records),len(waves))
    payload+=b''.join(struct.pack('<IH',*r)for r in index)+directory+records+waves
    (OUT/'bank.bin').write_bytes(payload)
    # All six FM parts and all six SSG parts coexist. Each FM slot holds
    # its entire snapshot sequence before the note, not each tick.
    shared=next(dict(np.load(OUT/(m['name']+'.npz')))for m in rows if m['source']['kind']=='effect')
    shared_bytes=len(layout(shared)[0]);fm_base=(shared_bytes+1023)&-1024
    fm_slot=MAX_SNAPSHOTS*256
    regions=[dict(name='SSG shared tone, level and noise tables',start=0,end=shared_bytes)]
    regions += [dict(name=f'FM part {ch} snapshot double buffer',start=fm_base+ch*fm_slot*2,end=fm_base+(ch+1)*fm_slot*2,oscillators=list(FM_PAIRS[ch]))for ch in range(6)]
    regions += [dict(name='silent timer',start=0xff00,end=0x10000,oscillators=[DOC_TIMER])]
    if regions[-2]['end']>0xff00:raise RuntimeError('The FM snapshot buffers do not fit in DOC RAM')
    for m in rows:
        if m['source']['kind']=='instrument' and m['bytes']>fm_slot:raise RuntimeError(f'{m["name"]}: snapshots exceed the FM slot')
    result=dict(components=len(rows),instrument_components=sum(m['source']['kind']=='instrument'for m in rows),
        waveform_tables=len(pool),unique_waveform_bytes=decoded_wave_bytes,stored_waveform_bytes=len(waves),binary_tables=packed_tables,
        native_record_bytes=len(records),bank_bytes=len(payload),
        enabled_oscillators=DOC_VOICES,scan_rate=DOC_RATE,fm_pairs=FM_PAIRS,ssg_pairs=[p[1:]for p in SSG_VOICES],
        doc_regions=regions,doc_used_bytes=fm_base+12*fm_slot+256,doc_free_bytes=65536-fm_base-12*fm_slot-256)
    (OUT/'models.json').write_text(json.dumps(rows,indent=2)+'\n')
    (OUT/'fit.json').write_text(json.dumps(result,indent=2)+'\n')
    return result
