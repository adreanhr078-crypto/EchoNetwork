import { useEffect, useRef, useState, type ReactNode } from 'react';
import { Pause, Play, VolumeX, Volume2 } from 'lucide-react';
import { useUiPreferencesStore } from '../../app/shell/shellStore';
import './title-entry.css';

export function TitleEntry({onStart,busy=false,status='',children}:{onStart:()=>void;busy?:boolean;status?:string;children?:ReactNode}) {
  const preferences=useUiPreferencesStore();
  const ar=preferences.locale==='ar';
  const video=useRef<HTMLVideoElement>(null);
  const water=useRef<HTMLAudioElement>(null);
  const [playing,setPlaying]=useState(preferences.motion!=='reduced');
  const [audible,setAudible]=useState(false);
  const [ready,setReady]=useState(false);
  useEffect(()=>{setPlaying(preferences.motion!=='reduced');},[preferences.motion]);
  useEffect(()=>{
    const element=video.current;if(!element)return;
    if(playing)void element.play().catch(()=>setReady(false));else element.pause();
  },[playing]);
  useEffect(()=>{if(video.current)video.current.volume=preferences.sfxVolume;},[preferences.sfxVolume]);
  useEffect(()=>{
    const element=water.current;if(!element)return;
    element.volume=preferences.sfxVolume;
    if(audible&&preferences.audioEnabled&&playing)void element.play().catch(()=>setAudible(false));
    else element.pause();
    return()=>element.pause();
  },[audible,playing,preferences.audioEnabled,preferences.sfxVolume]);
  return <main className="title-entry" dir={ar?'rtl':'ltr'} aria-label={ar?'بداية رحلة إيكو':'Echo’s journey'}>
    <img className="title-entry__media" src="/assets/cinematics/title-entry/echo-moon-v1.webp" alt="" />
    <video ref={video} className="title-entry__media" src="/assets/cinematics/title-entry/echo-moon-v1.mp4" poster="/assets/cinematics/title-entry/echo-moon-v1.webp"
      aria-hidden="true" autoPlay={playing} loop muted playsInline preload="auto"
      style={{opacity:ready&&playing?1:0}} onPlaying={()=>setReady(true)} onError={()=>setReady(false)} />
    <audio ref={water} src="/assets/cinematics/title-entry/water-sfx-v1.ogg" loop preload="none"/>
    <nav className="title-entry__tools" aria-label={ar?'إعدادات العرض':'Presentation settings'}>
      <button aria-label={ar?(playing?'إيقاف الحركة':'تشغيل الفيديو'):(playing?'Pause motion':'Play video')} aria-pressed={!playing} onClick={()=>preferences.setMotion(playing?'reduced':'balanced')}>{playing?<Pause/>:<Play/>}</button>
      <button aria-label={ar?(audible?'كتم الصوت':'تشغيل الصوت'):(audible?'Mute':'Enable sound')} aria-pressed={audible} onClick={()=>{preferences.setAudioEnabled(true);setAudible(value=>!value);}}>{audible?<Volume2/>:<VolumeX/>}</button>
      <button onClick={()=>preferences.setLocale(ar?'en':'ar')}>{ar?'English':'العربية'}</button>
    </nav>
    <div className="title-entry__action">
      {children||<button className="title-entry__start" disabled={busy} onClick={onStart}>{busy?(ar?'جارٍ الاتصال…':'Connecting…'):ar?'اضغط للبدء · Tap to Start':'Tap to Start'}</button>}
      {status&&<p role="status">{status}</p>}
    </div>
  </main>;
}
