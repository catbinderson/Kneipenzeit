"use client";

import { useEffect, useMemo, useRef, useState } from "react";

type Visit = { id: number; start: string; end: string | null };
type Pub = { name: string; address: string; lat: number | null; lng: number | null; radius: number; delay: number };

const initialPub: Pub = { name: "Gaststätte Heuchelberg", address: "Kelterstraße 6, 74211 Leingarten", lat: 49.1427734, lng: 9.1220517, radius: 60, delay: 5 };
const sampleVisits: Visit[] = [
  { id: 1, start: "2026-08-08T18:42:00", end: "2026-08-08T22:18:00" },
  { id: 2, start: "2026-08-02T19:11:00", end: "2026-08-02T23:04:00" },
  { id: 3, start: "2026-07-25T18:55:00", end: "2026-07-25T22:32:00" },
  { id: 4, start: "2026-07-18T19:08:00", end: "2026-07-18T23:21:00" },
  { id: 5, start: "2026-06-27T18:34:00", end: "2026-06-27T22:47:00" },
];

function duration(v: Visit, now = Date.now()) {
  return Math.max(0, (v.end ? new Date(v.end).getTime() : now) - new Date(v.start).getTime());
}
function fmt(ms: number) {
  const mins = Math.floor(ms / 60000);
  return `${Math.floor(mins / 60)} Std. ${String(mins % 60).padStart(2, "0")} Min.`;
}
function sameDay(a: Date, b: Date) { return a.toDateString() === b.toDateString(); }
function startOfWeek(d: Date) { const x = new Date(d); const day = (x.getDay() + 6) % 7; x.setDate(x.getDate() - day); x.setHours(0,0,0,0); return x; }
function startOfMonth(d: Date) { return new Date(d.getFullYear(), d.getMonth(), 1); }
function startOfYear(d: Date) { return new Date(d.getFullYear(), 0, 1); }
function distance(aLat:number,aLng:number,bLat:number,bLng:number) {
  const r=6371000, p=Math.PI/180; const x=(bLat-aLat)*p; const y=(bLng-aLng)*p;
  const h=Math.sin(x/2)**2+Math.cos(aLat*p)*Math.cos(bLat*p)*Math.sin(y/2)**2;
  return 2*r*Math.atan2(Math.sqrt(h),Math.sqrt(1-h));
}

export default function Home() {
  const [pub, setPub] = useState<Pub>(initialPub);
  const [visits, setVisits] = useState<Visit[]>(sampleVisits);
  const [ready, setReady] = useState(false);
  const [tracking, setTracking] = useState(false);
  const [distanceAway, setDistanceAway] = useState<number | null>(null);
  const [message, setMessage] = useState("GPS-Erkennung ist noch nicht aktiv");
  const [tab, setTab] = useState<"overview"|"visits"|"settings">("overview");
  const [now, setNow] = useState(Date.now());
  const watch = useRef<number | null>(null);
  const insideSince = useRef<number | null>(null);

  useEffect(() => {
    const p=localStorage.getItem("kneipenzeit-pub"), v=localStorage.getItem("kneipenzeit-visits");
    if(p) {
      const saved = JSON.parse(p) as Partial<Pub>;
      setPub(saved.name === "Meine Stammkneipe" ? initialPub : { ...initialPub, ...saved });
    }
    if(v) setVisits(JSON.parse(v)); setReady(true);
    const timer=setInterval(()=>setNow(Date.now()),1000); return()=>clearInterval(timer);
  },[]);
  useEffect(()=>{ if(ready){ localStorage.setItem("kneipenzeit-pub",JSON.stringify(pub)); localStorage.setItem("kneipenzeit-visits",JSON.stringify(visits)); }},[pub,visits,ready]);

  const active=visits.find(v=>!v.end);
  const totals=useMemo(()=>{
    const n=new Date(now); const sum=(from:Date)=>visits.filter(v=>new Date(v.start)>=from).reduce((s,v)=>s+duration(v,now),0);
    return [
      ["Heute",visits.filter(v=>sameDay(new Date(v.start),n)).reduce((s,v)=>s+duration(v,now),0),"today"],
      ["Diese Woche",sum(startOfWeek(n)),"week"],
      ["Dieser Monat",sum(startOfMonth(n)),"month"],
      ["Dieses Jahr",sum(startOfYear(n)),"year"],
    ] as [string,number,string][];
  },[visits,now]);

  function checkPosition(pos: GeolocationPosition) {
    if(pub.lat===null||pub.lng===null){ setMessage("Lege zuerst den Kneipenstandort fest"); return; }
    const d=distance(pos.coords.latitude,pos.coords.longitude,pub.lat,pub.lng); setDistanceAway(d);
    if(d<=pub.radius){
      if(!insideSince.current) insideSince.current=Date.now();
      const wait=pub.delay*60000-(Date.now()-insideSince.current);
      if(!active && wait<=0) startVisit(); else if(!active) setMessage(`In der Kneipe · Check-in in ${Math.max(1,Math.ceil(wait/60000))} Min.`);
      else setMessage("Du bist in der Kneipe");
    } else { insideSince.current=null; if(active) endVisit(); setMessage(`Außerhalb · ${Math.round(d)} m entfernt`); }
  }
  function toggleTracking(){
    if(tracking){ if(watch.current!==null) navigator.geolocation.clearWatch(watch.current); watch.current=null; setTracking(false); setMessage("GPS-Erkennung pausiert"); return; }
    if(!navigator.geolocation){ setMessage("GPS wird von diesem Gerät nicht unterstützt"); return; }
    watch.current=navigator.geolocation.watchPosition(checkPosition,()=>setMessage("Standortzugriff wurde nicht erlaubt"),{enableHighAccuracy:true,maximumAge:30000,timeout:20000});
    setTracking(true); setMessage("Standort wird ermittelt …");
  }
  function useCurrentLocation(){ navigator.geolocation?.getCurrentPosition(p=>{setPub({...pub,lat:p.coords.latitude,lng:p.coords.longitude});setMessage("Kneipenstandort gespeichert");},()=>setMessage("Standort konnte nicht gelesen werden"),{enableHighAccuracy:true}); }
  function startVisit(){ if(active) return; setVisits([{id:Date.now(),start:new Date().toISOString(),end:null},...visits]); setMessage("Besuch läuft"); }
  function endVisit(){ setVisits(visits.map(v=>v.end||v!==active?v:{...v,end:new Date().toISOString()})); setMessage("Besuch beendet und gespeichert"); }
  function removeVisit(id:number){setVisits(visits.filter(v=>v.id!==id));}

  return <main>
    <header className="topbar"><div className="brand"><span className="logo">K</span><div><strong>Kneipenzeit</strong><small>Deine Zeit. Deine Kneipe.</small></div></div><span className={`gps ${tracking?"on":""}`}>● {tracking?"GPS aktiv":"GPS aus"}</span></header>
    <div className="shell">
      <nav className="tabs">
        <button className={tab==="overview"?"active":""} onClick={()=>setTab("overview")}>Übersicht</button>
        <button className={tab==="visits"?"active":""} onClick={()=>setTab("visits")}>Besuche</button>
        <button className={tab==="settings"?"active":""} onClick={()=>setTab("settings")}>Kneipe & GPS</button>
      </nav>

      {tab==="overview"&&<>
        <section className={`hero ${active?"inside":""}`}>
          <div><p className="eyebrow">{active?"JETZT EINGECHECKT":"DEINE STAMMKNEIPE"}</p><h1>{pub.name}</h1><p className="pubAddress">{pub.address}</p><p className="status">{message}</p></div>
          <div className="heroRight"><div className="clock">{active?fmt(duration(active,now)):"0 Std. 00 Min."}</div><small>{active?`Seit ${new Date(active.start).toLocaleTimeString("de-DE",{hour:"2-digit",minute:"2-digit"})} Uhr`:distanceAway!==null?`${Math.round(distanceAway)} m entfernt`:"Heute"}</small></div>
          <div className="actions"><button className="primary" onClick={active?endVisit:startVisit}>{active?"Besuch beenden":"Manuell einchecken"}</button><button className="secondary" onClick={toggleTracking}>{tracking?"GPS pausieren":"GPS-Erkennung starten"}</button></div>
        </section>
        <section><div className="sectionTitle"><div><p className="eyebrow">ANWESENHEITSZEIT</p><h2>Deine Bilanz</h2></div><span>Stand: jetzt</span></div>
          <div className="stats">{totals.map(([label,value,key])=><article key={key}><span className={`statIcon ${key}`}>{key==="today"?"◷":key==="week"?"7":key==="month"?"30":"365"}</span><p>{label}</p><strong>{fmt(value)}</strong><small>{visits.filter(v=>new Date(v.start)>=(key==="today"?new Date(new Date().setHours(0,0,0,0)):key==="week"?startOfWeek(new Date()):key==="month"?startOfMonth(new Date()):startOfYear(new Date()))).length} Besuche</small></article>)}</div>
        </section>
        <section className="recent"><div className="sectionTitle"><div><p className="eyebrow">VERLAUF</p><h2>Letzte Besuche</h2></div><button className="textButton" onClick={()=>setTab("visits")}>Alle anzeigen →</button></div><VisitList visits={visits.slice(0,3)} now={now}/></section>
      </>}

      {tab==="visits"&&<section className="panel"><div className="sectionTitle"><div><p className="eyebrow">CHRONIK</p><h1>Alle Besuche</h1></div><button className="primary compact" onClick={startVisit}>+ Besuch starten</button></div><VisitList visits={visits} now={now} remove={removeVisit}/></section>}

      {tab==="settings"&&<section className="settingsGrid"><div className="panel"><p className="eyebrow">STANDORT</p><h1>Deine Kneipe</h1><label>Name<input value={pub.name} readOnly/></label><label>Adresse<input value={pub.address} readOnly/></label><div className="coords"><label>Breitengrad<input type="number" value={pub.lat??""} readOnly/></label><label>Längengrad<input type="number" value={pub.lng??""} readOnly/></label></div><button className="primary full" onClick={useCurrentLocation}>Standort vor Ort genauer festlegen</button></div><div className="panel"><p className="eyebrow">AUTOMATIK</p><h1>GPS-Erkennung</h1><label>Erkennungsradius <b>{pub.radius} m</b><input type="range" min="25" max="200" step="5" value={pub.radius} onChange={e=>setPub({...pub,radius:+e.target.value})}/></label><label>Mindestaufenthalt <b>{pub.delay} Min.</b><input type="range" min="0" max="20" value={pub.delay} onChange={e=>setPub({...pub,delay:+e.target.value})}/></label><div className="notice">Kurzes Vorbeifahren wird erst nach dem Mindestaufenthalt als Besuch gewertet. Auf dem iPhone muss die App geöffnet sein, damit eine Web-App den Standort zuverlässig aktualisieren kann.</div><button className="secondary full" onClick={toggleTracking}>{tracking?"GPS-Erkennung pausieren":"GPS-Erkennung starten"}</button></div></section>}
    </div>
    <footer>Alle Daten werden nur auf diesem Gerät gespeichert. · Kneipenzeit v1.0.1</footer>
  </main>;
}

function VisitList({visits,now,remove}:{visits:Visit[];now:number;remove?:(id:number)=>void}){
  if(!visits.length)return <div className="empty">Noch keine Besuche gespeichert.</div>;
  return <div className="visitList">{visits.map(v=><div className="visit" key={v.id}><div className="dateBox"><strong>{new Date(v.start).getDate()}</strong><span>{new Date(v.start).toLocaleDateString("de-DE",{month:"short"})}</span></div><div className="visitInfo"><strong>{new Date(v.start).toLocaleDateString("de-DE",{weekday:"long"})}</strong><span>{new Date(v.start).toLocaleTimeString("de-DE",{hour:"2-digit",minute:"2-digit"})} – {v.end?new Date(v.end).toLocaleTimeString("de-DE",{hour:"2-digit",minute:"2-digit"}):"läuft"}</span></div><strong className="visitDuration">{fmt(duration(v,now))}</strong>{remove&&<button className="delete" aria-label="Besuch löschen" onClick={()=>remove(v.id)}>×</button>}</div>)}</div>;
}
