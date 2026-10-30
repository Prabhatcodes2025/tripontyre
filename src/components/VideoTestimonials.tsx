import { useEffect, useMemo, useRef, useState, type CSSProperties, type PointerEvent } from 'react';
import { CircleAlert, Pause, Play, Volume2, VolumeX } from 'lucide-react';
import type { PublicVideoTestimonial } from '../services/content';
import { getTestimonialVideoSignedUrl } from '../services/media';

const SPEED_PX_PER_SECOND = 30;
const VISIBILITY_THRESHOLDS = [0, .2, .4, .6, .8, 1];
type VisualCard = PublicVideoTestimonial & { instanceId: string; canonical: boolean };

export default function VideoTestimonials({ testimonials }: { testimonials: PublicVideoTestimonial[] }) {
  const sectionRef = useRef<HTMLElement>(null);
  const groupRef = useRef<HTMLDivElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const visibilityRatios = useRef(new Map<string, number>());
  const refreshedPaths = useRef(new Set<string>());
  const [sectionVisible, setSectionVisible] = useState(false);
  const [pageVisible, setPageVisible] = useState(!document.hidden);
  const [reducedMotion, setReducedMotion] = useState(false);
  const [manualPause, setManualPause] = useState(false);
  const [hoverPause, setHoverPause] = useState(false);
  const [touchPause, setTouchPause] = useState(false);
  const [activeInstance, setActiveInstance] = useState<string | null>(null);
  const [playing, setPlaying] = useState(false);
  const [muted, setMuted] = useState(true);
  const [playbackError, setPlaybackError] = useState('');
  const [sourceOverrides, setSourceOverrides] = useState<Record<string,string>>({});
  const [groupWidth, setGroupWidth] = useState(0);

  const cardsPerGroup = testimonials.length ? Math.max(testimonials.length, 6) : 0;
  const visualCards = useMemo<VisualCard[]>(() => Array.from({ length: cardsPerGroup }, (_, index) => {
    const testimonial = testimonials[index % testimonials.length];
    return { ...testimonial, instanceId:`card-${index}`, canonical:index < testimonials.length };
  }), [cardsPerGroup, testimonials]);
  const allCards = useMemo(() => [0,1].flatMap(group => visualCards.map((card,index) => ({ ...card, instanceId:`group-${group}-${index}`, canonical:group===0&&card.canonical }))), [visualCards]);
  const activeCard = allCards.find(card=>card.instanceId===activeInstance);
  const trainRunning = sectionVisible && pageVisible && !reducedMotion && !manualPause && !hoverPause && !touchPause;
  const trainStyle = { '--train-distance':`${groupWidth}px`, '--train-duration':`${Math.max(groupWidth / SPEED_PX_PER_SECOND, 1)}s` } as CSSProperties;

  useEffect(() => {
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    const update = () => setReducedMotion(media.matches);
    update(); media.addEventListener('change', update);
    return () => media.removeEventListener('change', update);
  }, []);

  useEffect(() => {
    const onVisibility = () => setPageVisible(!document.hidden);
    document.addEventListener('visibilitychange', onVisibility);
    return () => document.removeEventListener('visibilitychange', onVisibility);
  }, []);

  useEffect(() => {
    const section = sectionRef.current;
    if (!section) return;
    const updateVisibility = () => { const box=section.getBoundingClientRect();setSectionVisible(box.bottom>0&&box.top<window.innerHeight); };
    const observer = new IntersectionObserver(([entry]) => setSectionVisible(entry.isIntersecting), { threshold:[0,.08,.25] });
    observer.observe(section);
    updateVisibility();window.addEventListener('scroll',updateVisibility,{passive:true});window.addEventListener('resize',updateVisibility,{passive:true});
    return () => {observer.disconnect();window.removeEventListener('scroll',updateVisibility);window.removeEventListener('resize',updateVisibility)};
  }, [testimonials.length]);

  useEffect(() => {
    const group = groupRef.current;
    if (!group) return;
    const measure = () => setGroupWidth(group.getBoundingClientRect().width);
    measure(); const observer = new ResizeObserver(measure); observer.observe(group);
    return () => observer.disconnect();
  }, [visualCards.length]);

  useEffect(() => {
    const section = sectionRef.current;
    if (!section) return;
    const cards = Array.from(section.querySelectorAll<HTMLElement>('[data-testimonial-instance]'));
    const observer = new IntersectionObserver(entries => {
      for (const entry of entries) visibilityRatios.current.set((entry.target as HTMLElement).dataset.testimonialInstance || '', entry.intersectionRatio);
      const best = [...visibilityRatios.current.entries()].filter(([,ratio])=>ratio>=.4).sort((a,b)=>b[1]-a[1])[0];
      setActiveInstance(best?.[0] || null);
    }, { threshold:VISIBILITY_THRESHOLDS });
    cards.forEach(card=>observer.observe(card));
    return () => observer.disconnect();
  }, [allCards.length]);

  useEffect(() => {
    if (!sectionVisible || !pageVisible) { setActiveInstance(null); return; }
    let frame=0;let lastSample=0;
    const sample=(time:number)=>{
      if(time-lastSample>240){lastSample=time;const cards=Array.from(sectionRef.current?.querySelectorAll<HTMLElement>('[data-testimonial-instance]')||[]);const center=window.innerWidth/2;const visible=cards.map(card=>{const box=card.getBoundingClientRect();const visibleWidth=Math.max(0,Math.min(box.right,window.innerWidth)-Math.max(box.left,0));return{card,visibleWidth,distance:Math.abs((box.left+box.right)/2-center)}}).filter(item=>item.visibleWidth>=item.card.offsetWidth*.4).sort((a,b)=>b.visibleWidth-a.visibleWidth||a.distance-b.distance)[0];if(visible)setActiveInstance(visible.card.dataset.testimonialInstance||null)}frame=requestAnimationFrame(sample)};
    frame=requestAnimationFrame(sample);
    return()=>cancelAnimationFrame(frame);
  },[pageVisible,sectionVisible]);

  useEffect(() => { setMuted(true); setPlaying(false); setPlaybackError(''); }, [activeInstance]);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    if (!sectionVisible || !pageVisible) { video.pause(); return; }
    video.muted = true; setMuted(true);
    void video.play().catch(() => { setPlaying(false); setPlaybackError('Autoplay was blocked. Select play to watch this traveller film.'); });
  }, [activeInstance, pageVisible, sectionVisible, sourceOverrides]);

  if (!testimonials.length) return null;

  const togglePlayback = () => {
    const video = videoRef.current;
    if (!video) return;
    setPlaybackError('');
    if (video.paused) void video.play().catch(()=>setPlaybackError('This video could not start. Try another browser-compatible MP4 or WebM file.'));
    else video.pause();
  };
  const toggleMute = () => { const video=videoRef.current;if(!video)return;video.muted=!video.muted;setMuted(video.muted); };

  const handleVideoError = async () => {
    if (!activeCard) return;
    const path = activeCard.storagePath;
    if (path && !refreshedPaths.current.has(path)) {
      refreshedPaths.current.add(path);
      try { const refreshed=await getTestimonialVideoSignedUrl(path);setSourceOverrides(current=>({...current,[activeCard.id]:refreshed}));return; } catch { /* Show the actionable error below. */ }
    }
    setPlaying(false);
    setPlaybackError('This video is unavailable or uses an unsupported codec. Upload an MP4 (H.264/AAC) or WebM file.');
  };
  const handlePointerDown = (event:PointerEvent) => { if (event.pointerType==='touch') setTouchPause(true); };
  const handlePointerEnd = (event:PointerEvent) => { if (event.pointerType==='touch') setTouchPause(false); };

  const renderCard = (card:VisualCard, group:number, index:number) => {
    const instanceId=`group-${group}-${index}`;
    const active=instanceId===activeInstance && sectionVisible && pageVisible;
    const source=sourceOverrides[card.id]||card.videoUrl;
    const accessible=card.canonical||active;
    return <article className={`testimonial-card ${active?'is-active':''}`} key={instanceId} data-testimonial-instance={instanceId} aria-hidden={!accessible}>
      <div className="testimonial-media">
        {active?<video ref={videoRef} src={source} poster={card.thumbnailUrl} muted playsInline preload="metadata" loop aria-label={`Video testimonial${card.name?` from ${card.name}`:''}`} onPlay={()=>setPlaying(true)} onPause={()=>setPlaying(false)} onError={()=>void handleVideoError()}/>:card.thumbnailUrl?<img src={card.thumbnailUrl} alt="" loading="lazy" decoding="async"/>:<div className="testimonial-poster-fallback"><Play aria-hidden="true"/><span>Traveller film</span></div>}
        {active&&<div className="testimonial-playback-controls"><button type="button" onClick={togglePlayback} aria-label={playing?'Pause traveller video':'Play traveller video'}>{playing?<Pause/>:<Play/>}</button><button type="button" onClick={toggleMute} aria-label={muted?'Unmute traveller video':'Mute traveller video'}>{muted?<VolumeX/>:<Volume2/>}</button></div>}
        {active&&playbackError&&<div className="testimonial-playback-error" role="status"><CircleAlert/><span>{playbackError}</span></div>}
      </div>
      <div className="testimonial-card-copy">{card.name&&<h3>{card.name}</h3>}{card.destination&&<b>{card.destination}</b>}{card.feedback&&<p>“{card.feedback}”</p>}</div>
    </article>;
  };

  const videoSchema = testimonials.map(item => ({ '@type':'VideoObject', name:item.name?`${item.name}'s My Tripon Travel experience`:'My Tripon Travel traveller experience', description:item.feedback||`A genuine traveller video from ${item.destination||'a My Tripon Travel journey'}.`, thumbnailUrl:item.thumbnailUrl||undefined, contentUrl:item.videoUrl }));

  return <section className="testimonial-showcase" ref={sectionRef} aria-labelledby="traveller-testimonials-title" onMouseEnter={()=>setHoverPause(true)} onMouseLeave={()=>setHoverPause(false)}>
    <script type="application/ld+json">{JSON.stringify({ '@context':'https://schema.org', '@graph':videoSchema })}</script>
    <div className="testimonial-heading"><div><span>STORIES FROM THE ROAD</span><h2 id="traveller-testimonials-title">Real Travellers. <em>Real Experiences.</em></h2><p>Hear directly from travellers who explored with My Tripon Travel.</p></div><button type="button" className="testimonial-train-toggle" onClick={()=>setManualPause(value=>!value)} aria-pressed={manualPause}>{manualPause?<Play/>:<Pause/>}<span>{manualPause?'Resume stories':'Pause stories'}</span></button></div>
    <div className="testimonial-marquee" onPointerDown={handlePointerDown} onPointerUp={handlePointerEnd} onPointerCancel={handlePointerEnd}>
      <div className={`testimonial-train ${trainRunning?'is-running':'is-paused'}`} style={trainStyle}>
        <div className="testimonial-train-group" ref={groupRef}>{visualCards.map((card,index)=>renderCard(card,0,index))}</div>
        <div className="testimonial-train-group">{visualCards.map((card,index)=>renderCard(card,1,index))}</div>
      </div>
    </div>
    {reducedMotion&&<p className="testimonial-motion-note">Automatic movement is off because reduced motion is enabled.</p>}
  </section>;
}
