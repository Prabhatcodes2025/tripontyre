import { useEffect, useRef, useState, type TouchEvent } from 'react';
import { ChevronLeft, ChevronRight, Pause, Play, Volume2, VolumeX } from 'lucide-react';
import type { PublicVideoTestimonial } from '../services/content';

const prefersReducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

export default function VideoTestimonials({ testimonials, interval = 8000 }: { testimonials: PublicVideoTestimonial[]; interval?: number }) {
  const [active, setActive] = useState(0);
  const [muted, setMuted] = useState(true);
  const [playing, setPlaying] = useState(false);
  const [inView, setInView] = useState(false);
  const [rotationPaused, setRotationPaused] = useState(false);
  const [touchStart, setTouchStart] = useState<number | null>(null);
  const sectionRef = useRef<HTMLElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const current = testimonials[active % testimonials.length];

  useEffect(() => {
    const section = sectionRef.current;
    if (!section) return;
    const observer = new IntersectionObserver(([entry]) => setInView(entry.isIntersecting && entry.intersectionRatio >= 0.35), { threshold: [0, 0.35, 0.75] });
    observer.observe(section);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    if (!inView) {
      video.pause();
      return;
    }
    if (!prefersReducedMotion() && !rotationPaused) void video.play().catch(() => setPlaying(false));
  }, [active, inView, rotationPaused]);

  useEffect(() => {
    if (!inView || playing || rotationPaused || prefersReducedMotion() || testimonials.length < 2) return;
    const timer = window.setTimeout(() => setActive(value => (value + 1) % testimonials.length), interval);
    return () => window.clearTimeout(timer);
  }, [active, inView, interval, playing, rotationPaused, testimonials.length]);

  if (!testimonials.length) return null;

  const move = (direction: number, userInitiated = true) => {
    if (userInitiated) setRotationPaused(true);
    setActive(value => (value + direction + testimonials.length) % testimonials.length);
  };

  const togglePlayback = () => {
    const video = videoRef.current;
    if (!video) return;
    setRotationPaused(true);
    if (video.paused) void video.play();
    else video.pause();
  };

  const handleTouchEnd = (event: TouchEvent) => {
    if (touchStart === null) return;
    const distance = event.changedTouches[0].clientX - touchStart;
    if (Math.abs(distance) > 45) move(distance < 0 ? 1 : -1);
    setTouchStart(null);
  };

  const videoSchema = testimonials.map(item => ({
    '@type': 'VideoObject',
    name: item.name ? `${item.name}'s My Tripon Travel experience` : 'My Tripon Travel traveller experience',
    description: item.feedback || `A genuine traveller video from ${item.destination || 'a My Tripon Travel journey'}.`,
    thumbnailUrl: item.thumbnailUrl || undefined,
    contentUrl: item.videoUrl,
  }));

  return <section className="testimonial-showcase" ref={sectionRef} aria-labelledby="traveller-testimonials-title">
    <script type="application/ld+json">{JSON.stringify({ '@context':'https://schema.org', '@graph':videoSchema })}</script>
    <div className="testimonial-heading">
      <span>STORIES FROM THE ROAD</span>
      <h2 id="traveller-testimonials-title">Real Travellers. <em>Real Experiences.</em></h2>
      <p>Hear directly from travellers who explored with My Tripon Travel.</p>
    </div>
    <div className="testimonial-stage" onTouchStart={event=>setTouchStart(event.touches[0].clientX)} onTouchEnd={handleTouchEnd}>
      <div className="testimonial-video-shell">
        <video
          key={current.id}
          ref={videoRef}
          src={inView ? current.videoUrl : undefined}
          poster={current.thumbnailUrl}
          muted={muted}
          playsInline
          preload="metadata"
          aria-label={`Video testimonial${current.name ? ` from ${current.name}` : ''}${current.destination ? ` about ${current.destination}` : ''}`}
          onPlay={()=>setPlaying(true)}
          onPause={()=>setPlaying(false)}
          onEnded={()=>move(1, false)}
        />
        <div className="testimonial-video-shade" aria-hidden="true"/>
        <div className="testimonial-video-controls">
          <button type="button" onClick={togglePlayback} aria-label={playing?'Pause testimonial video':'Play testimonial video'}>{playing?<Pause size={18}/>:<Play size={18}/>}<span>{playing?'Pause':'Play'}</span></button>
          <button type="button" onClick={()=>{setRotationPaused(true);setMuted(value=>!value)}} aria-label={muted?'Unmute testimonial video':'Mute testimonial video'}>{muted?<VolumeX size={18}/>:<Volume2 size={18}/>}<span>{muted?'Unmute':'Mute'}</span></button>
        </div>
        <span className="testimonial-count">{String(active+1).padStart(2,'0')} / {String(testimonials.length).padStart(2,'0')}</span>
      </div>
      <div className="testimonial-copy">
        <span>TRAVELLER FILM</span>
        {current.name&&<h3>{current.name}</h3>}
        {current.destination&&<b>{current.destination}</b>}
        {current.feedback&&<p>“{current.feedback}”</p>}
        <div className="testimonial-navigation">
          <button type="button" onClick={()=>move(-1)} disabled={testimonials.length<2} aria-label="Previous traveller video"><ChevronLeft/></button>
          <div role="group" aria-label="Choose a traveller video">{testimonials.map((item,index)=><button type="button" key={item.id} className={index===active?'active':''} onClick={()=>{setRotationPaused(true);setActive(index)}} aria-label={`Show video ${index+1}${item.name?` from ${item.name}`:''}`} aria-current={index===active?'true':undefined}><i/></button>)}</div>
          <button type="button" onClick={()=>move(1)} disabled={testimonials.length<2} aria-label="Next traveller video"><ChevronRight/></button>
        </div>
        {rotationPaused&&<button type="button" className="testimonial-resume" onClick={()=>setRotationPaused(false)}>Resume automatic rotation</button>}
      </div>
    </div>
  </section>;
}
