"""Song notes in the score's exact YM register context, from the score log."""
import struct
from collections import defaultdict,deque
from sound_files import SCORE_LOG

def note_windows(command=0x20):
 out=SCORE_LOG
 notes=defaultdict(deque)
 for cmd,tick,ch,kind,fnum,patch in struct.iter_unpack('<BIBBHB',(out/'notes.bin').read_bytes()):
  if cmd==command and kind==1:notes[ch].append((tick,fnum,patch))
 registers=[bytearray(256),bytearray(256)];windows=[[]for _ in range(6)];active=[None]*6
 for time,cmd,tick,chip,reg,value in struct.iter_unpack('<dBIBBB',(out/'ym.bin').read_bytes()):
  registers[chip][reg]=value
  if cmd!=command or reg!=0x28 or value&3>=3:continue
  ch=chip*3+(value&3)
  if value&0xf0:
   data=notes[ch].popleft();fnum=registers[chip][0xa0+ch%3]|registers[chip][0xa4+ch%3]<<8
   assert fnum==data[1]
   if active[ch]is not None:active[ch]['end']=time
   record=dict(channel=ch,tick=data[0],fnum=fnum,patch=data[2],start=time,fresh=active[ch]is None or active[ch].get('off')is not None,
    context=list(registers[chip]),end=None,off=None)
   windows[ch].append(record);active[ch]=record
  elif active[ch]is not None:active[ch]['off']=time
 end=max(t for cmd,tick,phase,t in struct.iter_unpack('<BIBd',(out/'ticks.bin').read_bytes())if cmd==command)
 for r in active:
  if r is not None and r['end']is None:r['end']=end
 return [r for w in windows for r in w if r['end']is not None]
