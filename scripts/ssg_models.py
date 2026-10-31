"""SSG solo captures of each sound effect, rendered from the effect log."""
import json,math,struct,subprocess
import numpy as np
from sound_model import resample,wav
from ssg_controls import noise_bits
from sound_files import EFFECTS as OUT,EFFECT_LOG,RENDERER,WORK
LOG=EFFECT_LOG/'ym.bin'
COMMANDS=[*range(1,31),58]

def capture_all():
 OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
 writes=list(struct.iter_unpack('<dBIBBB',LOG.read_bytes()));ticks=list(struct.iter_unpack('<BIBd',(LOG.parent/'ticks.bin').read_bytes()));records=[]
 # One clocked pass keeps the arcade noise/tone phase and avoids replaying
 # the same prefix for every command. The multichannel PCM is only staging.
 raw=WORK/'ssg-stems.raw';first=next(w[0]for w in writes if w[1]==0);end=max(t[3]for t in ticks)+.02
 subprocess.run([str(RENDERER),str(LOG),'0',str(raw),str(end),str(-first)],check=True,stdout=subprocess.DEVNULL)
 x=np.memmap(raw,'<i2',mode='r').reshape(-1,14)
 for command in COMMANDS:
  events=[w for w in writes if w[1]==command];first=events[0][0];end=max(t[3]for t in ticks if t[0]==command);duration=end-first
  lo=math.ceil(first*125000);hi=math.ceil(end*125000);part=x[lo:hi];channels=[];mix=np.zeros(len(part));path=OUT/f'{command:02x}';path.mkdir(exist_ok=True)
  for channel,index in enumerate([3,4,5,10,11,12]):
   a=part[:,index].astype(float)*.15;mix+=a
   if np.max(a)==0:continue
   a=resample(a,125000,48000);wav(path/f'ssg-{channel}.wav',a);channels.append(channel)
  mix+=(part[:,6].astype(float)+part[:,13])*.1
  record=dict(command=command,first_write=first,duration=duration,channels=channels,
      peak=float(np.max(abs(mix))),source_sample_range=[lo,hi])
  records.append(record)
 del part,x;raw.unlink()
 (OUT/'captures.json').write_text(json.dumps(records,indent=2)+'\n')
 noise_bits();return records
