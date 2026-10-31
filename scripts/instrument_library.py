"""Select a song note for each sample of the score: its root and its highest pitch.

The selected note gives the patch registers of the song context. The
isolated capture (scripts/instrument_isolated.py) plays that patch alone.
"""
from instruments import note_windows

def select(score):
 windows=[]
 for c in range(32,51):windows.extend(dict(w,command=c)for w in note_windows(c))
 wanted=[]
 for plan in score['samples']:
  for kind,word in [('root',plan['root_fnum']),('high',plan['played_fnums'][-1])]:
   choices=[w for w in windows if w['patch']==plan['patch']and w['fnum']==word and w['off']is not None]
   if not choices:choices=[w for w in windows if w['patch']==plan['patch']and w['fnum']==word]
   assert choices,(plan['sample'],kind,hex(word))
   # Prefer real fresh attacks. Keep the complete longest held note and tail,
   # not a synthetic held note produced outside the song's register context.
   best=max(choices,key=lambda w:(w['fresh'],(w['off']or w['end'])-w['start']))
   wanted.append(dict(best,sample=plan['sample'],kind=kind,plan=plan))
 return sorted(wanted,key=lambda r:r['command'])
