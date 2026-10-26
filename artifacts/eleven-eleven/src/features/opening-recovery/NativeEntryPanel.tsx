import { useEffect, useRef, useState } from 'react';
import { GameButton, GlassPanel } from '../../ui/design-system';
import { issueNativeEntryGrant } from '../../infrastructure/player-progression/playerProgressionApi';
import { useAuthStore } from '../auth/authStore';

export function nativeEntryChallenge(): string | null {
  const value=new URLSearchParams(window.location.search).get('native_challenge');
  return value && /^[A-Za-z0-9_-]{43}$/.test(value) ? value : null;
}

export function NativeEntryPanel({challenge,locale,requestGrant=issueNativeEntryGrant}:{challenge:string;locale:'ar'|'en';requestGrant?:typeof issueNativeEntryGrant}) {
  const uid=useAuthStore(state=>state.user?.uid);
  const [code,setCode]=useState('');
  const [status,setStatus]=useState<'idle'|'pending'|'ready'|'error'|'copied'|'manual'>('idle');
  const revision=useRef(0);
  useEffect(()=>{revision.current++;setCode('');setStatus('idle');return()=>{revision.current++;};},[challenge,uid]);
  const request=async()=>{
    const generation=++revision.current;
    setStatus('pending');setCode('');
    try {
      if(!uid)throw new Error('session_required');
      const grant=await requestGrant(challenge,uid);
      if(generation!==revision.current)return;
      setCode(grant.code);setStatus('ready');
    } catch {if(generation===revision.current)setStatus('error');}
  };
  const ar=locale==='ar';
  const copy=async()=>{
    try {await navigator.clipboard.writeText(code);setStatus('copied');}
    catch {setStatus('manual');}
  };
  return <GlassPanel tone="memory" className="opening-recovery__panel">
    <h2>{ar?'تابع مع إيكو في اللعبة':'Continue with Echo in the game'}</h2>
    <p>{ar?'افتح اتصالًا، وانسخ الرمز، ثم عُد إلى اللعبة واضغط «لصق الرمز».':'Open a connection, copy the code, then return to the game and choose “Paste code”.'}</p>
    {code&&<input aria-label={ar?'رمز الربط':'Connection code'} readOnly value={code} dir="ltr" onFocus={event=>event.currentTarget.select()} style={{width:'100%',minHeight:48,fontFamily:'monospace'}}/>}
    <p role="status">{status==='error'?(ar?'تعذر الربط. تحقق من اتصال حسابك؛ ابدأ الرحلة أو أعد المحاولة بعد قليل.':'Connection failed. Check your account connection; start the journey or retry shortly.'):status==='copied'?(ar?'نُسخ الرمز. عُد إلى اللعبة.':'Code copied. Return to the game.'):status==='manual'?(ar?'حدد الرمز وانسخه يدويًا، ثم عُد إلى اللعبة.':'Select the code and copy it manually, then return to the game.'):''}</p>
    {code&&<GameButton onClick={()=>{void copy();}}>{ar?'نسخ الرمز':'Copy code'}</GameButton>}
    <GameButton disabled={status==='pending'} onClick={()=>{void request();}}>{status==='pending'?(ar?'جارٍ الربط…':'Connecting…'):code?(ar?'إنشاء رمز جديد':'Create a new code'):(ar?'فتح الاتصال':'Open connection')}</GameButton>
  </GlassPanel>;
}
