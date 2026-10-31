"""Sample helpers of the sound stage: resample, WAV files and 8-bit DOC tables."""
import subprocess,wave
import numpy as np
import soxr
from audio_config import DOC_RATE

def quantize_table(unit,rate=DOC_RATE):
 return np.clip(np.rint(np.asarray(unit)*127)+128,1,255).astype('u1')

def quantize(a,rate,shape='auto'):
    """8-bit DOC table with SoX noise shaping, and a record of the filter used."""
    # SoX's published Shibata tables have discrete rates; it accepts +/-5%.
    # Sloped TPDF is the supported arbitrary-rate high-pass dither fallback.
    rates=(8000,11025,16000,22050,32000,37800,44100,48000)
    nearest=min(rates,key=lambda r:abs(r-rate))
    if shape not in ('auto','tpdf'):raise ValueError(shape)
    opts=(['-f','shibata']if abs(nearest-rate)/nearest<.05 else['-S'])if shape=='auto'else[]
    result=subprocess.run(['sox','-R','-D','-t','f64','-r',str(rate),'-c','1','-',
        '-t','u8','-','dither',*opts],input=np.asarray(a,'<f8').tobytes(),capture_output=True,check=True)
    data=np.frombuffer(result.stdout,'u1').copy();zeros=int(np.count_nonzero(data==0));data[data==0]=1
    return data,dict(tool='SoX',rate=rate,filter='shibata'if opts and opts[0]=='-f'else'sloped TPDF'if opts else'TPDF',
                     source_filter_rate=nearest if opts and opts[0]=='-f'else None,zero_codes_changed_to_one=zeros)

def resample(data,source,target=DOC_RATE):
 return soxr.resample(np.asarray(data,dtype=np.float64),source,target,quality='VHQ')
def wav(path,data,rate=48000):
 data=np.asarray(data);peak=np.max(np.abs(data))
 assert peak<=32767.5,(path,peak)
 with wave.open(str(path),'wb')as f:
  f.setparams((1 if data.ndim==1 else data.shape[1],2,round(rate),0,'NONE','not compressed'))
  f.writeframes(np.rint(data).astype('<i2').tobytes())
def readwav(path):
 with wave.open(str(path),'rb')as f:
  x=np.frombuffer(f.readframes(f.getnframes()),'<i2').astype(float).reshape(-1,f.getnchannels())
  return x[:,0]if x.shape[1]==1 else x,f.getframerate()
