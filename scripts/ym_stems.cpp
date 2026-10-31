// Build-only YM2203 renderer on the BSD-3-Clause ymfm library (third_party/ymfm).
// Register writes come from the sound program port (scripts/sound_logs.py). No idealized
// oscillator substitutes: solos keep operators, envelopes, detune and feedback.
#include "ymfm_opn.h"
#include "ymfm_opn.cpp"
#include <array>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <vector>
#include <stdexcept>
struct Host:ymfm::ymfm_interface {};
class Chip:public ymfm::ym2203 {
public:
 explicit Chip(Host& h):ym2203(h){set_fidelity(ymfm::OPN_FIDELITY_MED);reset();}
 std::array<int16_t,7> frame(){
  output_data o;generate(&o);std::array<int16_t,7> r{};
  for(unsigned c=0;c<3;c++){
   fm_engine::output_data one; m_fm.output(one.clear(),0,32767,1u<<c);one.roundtrip_fp();r[c]=one.data[0];
   r[c+3]=o.data[c+1];
  }
  r[6]=o.data[0];return r;
 }
 std::array<float,3> envelopes(){
  std::array<float,3> result{};
  static const unsigned carriers[8]={8,8,8,8,10,14,14,15};
  for(unsigned ch=0;ch<3;ch++){
   unsigned mask=carriers[m_fm.regs().ch_algorithm(ch)];double power=0;
   for(unsigned op=0;op<4;op++)if(mask&(1u<<op)){
    // Probe the existing operator at the sine peak. This reads its actual
    // EG, TL and SSG-EG state; it does not clock or alter the sound core.
    double gain=m_fm.debug_channel(ch)->debug_operator(op)->compute_volume(256,0);
    power+=gain*gain;
   }
   result[ch]=float(std::sqrt(power));
  }
  return result;
 }
 void snapshot(unsigned ch,unsigned count,std::ofstream& out){
  // The ordinary capture continues unchanged after this local snapshot.
  // Public YMFM channel clock: env_counter low bits 01 skip EG advancement
  // while phase, detune, feedback and the original FM algorithm still run.
  std::vector<uint8_t> state;
  ymfm::ymfm_saved_state save(state,true);save_restore(save);
  uint32_t rate=m_fm.sample_rate(1500000);
  out.write((char*)&rate,4);
  for(unsigned n=0;n<count;n++){
   m_fm.debug_channel(ch)->clock(1,0);
   fm_engine::output_data one;
   m_fm.output(one.clear(),0,32767,1u<<ch);one.roundtrip_fp();
   int16_t sample=one.data[0];out.write((char*)&sample,2);
  }
  ymfm::ymfm_saved_state restore(state,false);save_restore(restore);
 }
};
struct Write {double t;uint8_t cmd;uint32_t tick;uint8_t chip,reg,data;};
struct Snapshot {double t;uint8_t channel;uint32_t count;};
int main(int argc,char**argv){
 if(argc<5){fprintf(stderr,"ym_stems LOG COMMAND OUTPUT.raw|- SECONDS [START_SECONDS [FREEZE_WRITES_SECONDS [ENVELOPES.raw|- [REQUESTS]]]]\n");return 1;}
 std::ifstream f(argv[1],std::ios::binary);std::vector<Write>w;unsigned char b[16];
 while(f.read((char*)b,16)){Write e;memcpy(&e.t,b,8);e.cmd=b[8];memcpy(&e.tick,b+9,4);e.chip=b[13];e.reg=b[14];e.data=b[15];w.push_back(e);}
 unsigned command=strtoul(argv[2],nullptr,0);double first=-1,last=-1;
 for(auto&e:w)if(e.cmd==command){if(first<0)first=e.t;last=e.t;}
 if(first<0)throw std::runtime_error("command missing");
 double start=first+(argc>5?atof(argv[5]):0),end=start+atof(argv[4]);
 double freeze=argc>6?first+atof(argv[6]):end;
 constexpr double rate=125000.;Host h0,h1;Chip a(h0),c(h1);Chip*chips[]={&a,&c};
 // Replay the complete clocked register history. Applying the preceding
 // writes instantaneously loses the free-running SSG noise/tone counters and
 // FM release state, and therefore does not reproduce the captured arcade.
 size_t at=0;
 std::ofstream out;if(strcmp(argv[3],"-"))out.open(argv[3],std::ios::binary);uint64_t n=0;
 std::ofstream env;if(argc>7&&strcmp(argv[7],"-"))env.open(argv[7],std::ios::binary);
 std::vector<Snapshot> requests;std::ofstream snapshots;size_t request=0;
 if(argc>8){
  std::ifstream input(argv[8],std::ios::binary);unsigned char row[13];
  while(input.read((char*)row,13)){Snapshot r;memcpy(&r.t,row,8);r.channel=row[8];memcpy(&r.count,row+9,4);requests.push_back(r);}
  snapshots.open(std::string(argv[8])+".raw",std::ios::binary);
 }
 for(uint64_t s=0;s/rate<end;s++){
  double t=s/rate;
  while(at<w.size()&&w[at].t<=t&&w[at].t<=freeze){auto&e=w[at++];chips[e.chip]->write_address(e.reg);chips[e.chip]->write_data(e.data);}
  auto x=a.frame(),y=c.frame();
  while(request<requests.size()&&requests[request].t<=t){auto&r=requests[request++];chips[r.channel/3]->snapshot(r.channel%3,r.count,snapshots);}
  if(t>=start){std::array<int16_t,14>r{};for(int i=0;i<7;i++){r[i]=x[i];r[i+7]=y[i];}if(out.is_open())out.write((char*)r.data(),sizeof(r));n++;
   if(env.is_open()){auto u=a.envelopes(),v=c.envelopes();env.write((char*)u.data(),sizeof(u));env.write((char*)v.data(),sizeof(v));}
  }
 }
 printf("{\"rate\":125000,\"channels\":14,\"first_write_seconds\":%.12f,\"start_seconds\":%.12f,\"frames\":%llu}\n",first,start,(unsigned long long)n);
}
