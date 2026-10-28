$ErrorActionPreference = 'Stop'
$outputRoot = Join-Path (Get-Location) 'assets\audio'
$source = @'
using System;
using System.IO;
using System.Text;

public static class FarmAudioSynth {
  const int Rate = 22050;
  static Random rng = new Random(4062026);
  static double Clamp(double x) { return Math.Max(-1.0, Math.Min(1.0, x)); }
  static void Write(string path, float[] data) {
    Directory.CreateDirectory(Path.GetDirectoryName(path));
    using (var w = new BinaryWriter(File.Create(path))) {
      w.Write(Encoding.ASCII.GetBytes("RIFF")); w.Write(36 + data.Length * 2); w.Write(Encoding.ASCII.GetBytes("WAVE"));
      w.Write(Encoding.ASCII.GetBytes("fmt ")); w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(Rate); w.Write(Rate * 2); w.Write((short)2); w.Write((short)16);
      w.Write(Encoding.ASCII.GetBytes("data")); w.Write(data.Length * 2);
      foreach (float v in data) w.Write((short)(Clamp(v) * 32767));
    }
  }
  static float[] Generate(double seconds, Func<double,double> f) {
    int n=(int)(seconds*Rate); float[] a=new float[n];
    for(int i=0;i<n;i++) a[i]=(float)f((double)i/Rate);
    return a;
  }
  static float[] BlendLoop(float[] data) {
    int count=Math.Min(Rate/4,data.Length/8); float start=data[0];
    for(int i=0;i<count;i++) { double u=(double)i/(count-1); int index=data.Length-count+i; data[index]=(float)(data[index]*(1-u)+start*u); }
    return data;
  }
  static double Env(double t,double d,double attack,double release) {
    if(t<0||t>d)return 0; return Math.Min(1,t/Math.Max(.0001,attack))*Math.Min(1,(d-t)/Math.Max(.0001,release));
  }
  static double Tone(double t,double f,double d,double amp,double attack,double release,double bend) {
    double e=Env(t,d,attack,release); return Math.Sin(2*Math.PI*(f*t+bend*t*t/2))*amp*e;
  }
  static double Tone(double t,double f,double d,double amp,double attack,double release) {
    return Tone(t,f,d,amp,attack,release,0);
  }
  static float[] Sfx(string id,int variation=0) {
    double d=.3;
    if(id.Contains("break")||id.Contains("hit")) d=.42;
    if(id=="ui_success"||id=="upgrade_success"||id=="fish_caught"||id=="dig_find"||id=="treasure_found") d=.72;
    if(id.Contains("moo")||id.Contains("baa")||id.Contains("oink")||id.Contains("cluck")) d=.75;
    if(id=="production_ready") d=.8;
    return Generate(d,(t)=>{
      double n=(rng.NextDouble()*2-1);
      double v=0;
      switch(id) {
        case "axe_hit_wood": v=.36*Math.Sin(2*Math.PI*(86+variation*9)*t)*Math.Exp(-15*t)+.17*n*Math.Exp(-25*t)+Tone(t,.0+530+variation*35,.028,.16,.001,.025); break;
        case "hammer_hit_rock": v=.33*Math.Sin(2*Math.PI*(230+variation*24)*t)*Math.Exp(-20*t)+.19*n*Math.Exp(-19*t)+Tone(t,900+variation*60,.022,.09,.001,.02); break;
        case "tree_break": v=.27*n*Math.Exp(-5*t)+.24*Math.Sin(2*Math.PI*72*t)*Math.Exp(-9*t)+Tone(t,210,.10,.1,.002,.09); break;
        case "rock_break": v=.20*n*Math.Exp(-8*t)+.21*Math.Sin(2*Math.PI*180*t)*Math.Exp(-13*t); break;
        case "dig_hit": case "plant_seed": v=.18*n*Math.Exp(-28*t)+Tone(t,110,.12,.16,.003,.11)+Tone(t,380,.035,.04,.001,.03); break;
        case "harvest_crop": v=Tone(t,720+variation*45,.18,.15,.004,.16)+Tone(t,1080+variation*33,.12,.08,.008,.10)+.05*n*Math.Exp(-14*t); break;
        case "ui_click": v=Tone(t,680+variation*65,.055,.14,.001,.05)+.035*n*Math.Exp(-60*t); break;
        case "ui_error": v=Tone(t,185,.16,.14,.006,.14)+Tone(t,130,.11,.08,.01,.1); break;
        case "coin": v=Tone(t,1320+variation*90,.16,.12,.001,.15)+Tone(t,1980+variation*50,.10,.08,.003,.09); break;
        case "ui_success": case "production_ready": case "upgrade_success": case "fish_caught": case "dig_find": case "treasure_found":
          v=Tone(t,740,.28,.10,.008,.2)+Tone(t,988,.30,.10,.06,.23)+Tone(t,1480,.22,.07,.12,.18); if(id=="treasure_found") v+=Tone(t,1760,.38,.06,.18,.2); break;
        case "axe_swing": case "hammer_swing": case "fishing_cast":
          v=.20*n*Math.Exp(-4*t)*(1-Math.Exp(-55*t)); v+=Tone(t,id=="fishing_cast"?360:260,.18,.08,.008,.15, id=="fishing_cast"?120:-95); break;
        case "fishing_splash": v=.27*n*Math.Exp(-10*t)+Tone(t,420,.16,.10,.001,.15,-600); break;
        case "fishing_bite": v=.17*n*Math.Exp(-13*t)+Tone(t,900,.11,.13,.001,.1)+Tone(t,1350,.095,.1,.018,.09); break;
        case "fishing_reel_tick": v=Tone(t,500,.07,.055,.001,.06)+.025*n*Math.Exp(-30*t); break;
        case "fishing_fail": v=Tone(t,330,.12,.10,.002,.11,-270); break;
        case "animal_feed": case "collect_egg": case "collect_milk": case "collect_wool": case "item_collect": case "product_collect":
          v=.12*n*Math.Exp(-14*t)+Tone(t,id=="collect_milk"?380:620,.16,.10,.004,.14); if(id=="collect_egg") v+=Tone(t,880,.09,.05,.003,.08); break;
        case "production_start": v=Tone(t,320,.12,.09,.01,.1)+Tone(t,480,.12,.05,.07,.1); break;
        case "building_place": v=.20*n*Math.Exp(-25*t)+Tone(t,105,.19,.15,.001,.16); break;
        case "footstep_soft": v=.10*n*Math.Exp(-22*t)+Tone(t,95,.08,.07,.001,.07); break;
        case "chicken_cluck": v=Tone(t,540,.18,.08,.012,.15, 500)+Tone(t,720,.16,.055,.14,.1,-550); break;
        case "cow_moo": v=Tone(t,130,.68,.16,.07,.48, -20)+Tone(t,260,.6,.035,.1,.4,-25); break;
        case "pig_oink": v=Tone(t,230,.33,.12,.03,.24, -220)+.05*n*Math.Exp(-7*t); break;
        case "sheep_baa": v=Tone(t,280,.62,.13,.06,.45, -35)+Tone(t,560,.54,.04,.09,.42,-45); break;
        default: v=Tone(t,440,.10,.08,.003,.08); break;
      }
      return v*.72;
    });
  }
  static float[] Music() {
    double beat=60.0/82.0, bar=beat*4, duration=bar*32;
    int[] scale={0,2,4,7,9}; int[] roots={0,5,3,4};
    return BlendLoop(Generate(duration,(t)=>{
      int beatIndex=(int)(t/beat); double local=t%beat; int barIndex=(int)(t/bar); int chord=roots[(barIndex/2)%4];
      int degree=scale[(beatIndex*3+(beatIndex/8))%scale.Length]; int semitone=chord+degree;
      double f=220*Math.Pow(2,semitone/12.0); double e=Env(local,beat*.78,.012,.42);
      double pluck=(Math.Sin(2*Math.PI*f*local)+.24*Math.Sin(4*Math.PI*f*local))*Math.Exp(-4.4*local)*.085;
      double bass=Tone(local,110*Math.Pow(2,chord/12.0),beat*.88,.045,.02,.5);
      double pad=.018*(Math.Sin(2*Math.PI*110*Math.Pow(2,chord/12.0)*t)+Math.Sin(2*Math.PI*164.81*Math.Pow(2,chord/12.0)*t));
      double bell=0; if(beatIndex%4==2 && local<beat*.68) bell=Tone(local,f*2,beat*.68,.035,.003,.55);
      double percussion=0; if(beatIndex%4==0) percussion=.017*Math.Sin(2*Math.PI*65*local)*Math.Exp(-26*local);
      return (pluck*e+bass+pad+bell+percussion)*.78;
    }));
  }
  static float[] Ambience(bool rain) {
    double duration=rain?8.0:16.0;
    return BlendLoop(Generate(duration,(t)=>{
      if(rain){ double n=(rng.NextDouble()*2-1); double rainWind=.06*Math.Sin(2*Math.PI*.19*t)+.026*Math.Sin(2*Math.PI*.43*t); return (n*.055+rainWind)*.6; }
      double farmWind=.022*Math.Sin(2*Math.PI*.11*t)+.012*Math.Sin(2*Math.PI*.17*t);
      double chirp=0;
      foreach(double start in new double[]{1.3,5.8,10.6,14.2}) { double u=t-start; if(u>=0&&u<.24) chirp+=Tone(u,2100,.24,.018,.012,.18,1600); }
      return farmWind+chirp;
    }));
  }
  public static void Run(string root) {
    string s=Path.Combine(root,"sfx");
    string[][] groups={
      new[]{"ui_click_01","ui_click_02","ui_success","ui_error","coin_01","coin_02"},
      new[]{"plant_seed","harvest_crop_01","harvest_crop_02","harvest_crop_03"},
      new[]{"axe_swing","axe_hit_wood_01","axe_hit_wood_02","axe_hit_wood_03","tree_break","hammer_swing","hammer_hit_rock_01","hammer_hit_rock_02","hammer_hit_rock_03","rock_break","dig_hit","dig_find"},
      new[]{"fishing_cast","fishing_splash","fishing_bite","fishing_reel_tick","fish_caught","fishing_fail","treasure_found"},
      new[]{"chicken_cluck","cow_moo","pig_oink","sheep_baa","animal_feed","collect_egg","collect_milk","collect_wool","item_collect"},
      new[]{"production_start","production_ready","product_collect","building_place","upgrade_success"},
      new[]{"footstep_soft_01","footstep_soft_02","footstep_soft_03"}
    };
    string[] folders={"ui","farming","tools","fishing","animals","production","world"};
    foreach(int g in new int[]{0,1,2,3,4,5,6}) foreach(string name in groups[g]) {
      string id=name; int variation=0;
      string[] parts=name.Split('_'); if(parts.Length>2 && int.TryParse(parts[parts.Length-1],out variation)) { id=String.Join("_",parts,0,parts.Length-1); variation--; }
      Write(Path.Combine(s,folders[g],name+".wav"),Sfx(id,variation));
    }
    Directory.CreateDirectory(Path.Combine(root,"music")); Directory.CreateDirectory(Path.Combine(root,"ambience"));
    Write(Path.Combine(root,"music","farm_day.wav"),BlendLoop(Music()));
    Write(Path.Combine(root,"ambience","farm_ambience.wav"),Ambience(false));
    Write(Path.Combine(root,"ambience","rain_loop.wav"),Ambience(true));
  }
}
'@
Add-Type -TypeDefinition $source -Language CSharp
[FarmAudioSynth]::Run($outputRoot)
Write-Output "Generated original audio under $outputRoot"
