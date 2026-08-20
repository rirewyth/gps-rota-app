import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

export const scrollState = {
  progress: 0
};

export const setupScrollTrigger = () => {
  ScrollTrigger.getAll().forEach(t => t.kill());

  // Global scroll trigger for the 3D scene (from top of the page to the bottom)
  ScrollTrigger.create({
    trigger: document.body,
    start: 'top top',
    end: 'bottom bottom',
    onUpdate: (self) => {
      scrollState.progress = self.progress;
    }
  });
  
  // Premium fade up mask reveal for scroll sections
  gsap.utils.toArray('.scroll-section, #hizmetler, #nasil-calisir').forEach(section => {
    // Select the container inside for staggered children if needed
    const children = section.querySelectorAll('h1, h2, h3, p, .card-animation, .glass-panel');
    
    gsap.fromTo(children, 
      { opacity: 0, y: 40, scale: 0.98 },
      {
        opacity: 1, 
        y: 0,
        scale: 1,
        duration: 1.2,
        stagger: 0.15,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: section,
          start: 'top 85%',
          end: 'top 20%',
          toggleActions: 'play none none reverse'
        }
      }
    );
  });
};
