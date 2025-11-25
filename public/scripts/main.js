document.addEventListener('DOMContentLoaded', () => {
  const hasGSAP = typeof gsap !== 'undefined' && typeof ScrollTrigger !== 'undefined';
  if (hasGSAP) {
    gsap.registerPlugin(ScrollTrigger);
  }

  const reduceMotionMedia = window.matchMedia('(prefers-reduced-motion: reduce)');
  const prefersReducedMotion = reduceMotionMedia.matches;
  if (prefersReducedMotion) {
    document.body.classList.add('reduce-motion');
  }

  const hero = document.getElementById('morphing-hero');
  const layers = hasGSAP ? gsap.utils.toArray('.hero-bg .layer') : [];
  const heroCopy = document.querySelector('.hero-copy');
  const heroCard = document.getElementById('crystal-card');
  const morphCards = hasGSAP ? gsap.utils.toArray('.morph-card') : [];
  const journeySteps = hasGSAP ? gsap.utils.toArray('.journey-step') : [];
  const featureCards = hasGSAP ? gsap.utils.toArray('.feature-card') : [];
  const scrollSpan = () => `+=${Math.round(window.innerHeight * 8)}`;
  const stateMarkers = hasGSAP ? gsap.utils.toArray('.hero-state') : [];
  const stateBarFill = document.querySelector('.hero-progress .fill');
  const orbitBadges = hasGSAP ? gsap.utils.toArray('.orbit-badge') : [];

  const heroStates = [
    { label: 'seed', hue: 260, alpha: 0.65, rotateY: -10, rotateX: 6, y: 26, glow: '0 30px 140px rgba(82,32,255,0.45)' },
    { label: 'epitaxy', hue: 210, alpha: 0.72, rotateY: 8, rotateX: -6, y: 6, glow: '0 40px 160px rgba(85,255,211,0.45)' },
    { label: 'growth', hue: 300, alpha: 0.7, rotateY: -6, rotateX: 8, y: -12, glow: '0 50px 180px rgba(199,183,255,0.4)' },
    { label: 'radiance', hue: 180, alpha: 0.68, rotateY: 0, rotateX: 0, y: -4, glow: '0 50px 200px rgba(85,255,211,0.5)' },
  ];

  if (hero && !prefersReducedMotion && hasGSAP) {
    const heroTl = gsap.timeline({
      scrollTrigger: {
        trigger: hero,
        start: 'top top',
        end: scrollSpan,
        scrub: true,
        pin: '.pinned-viewport',
        anticipatePin: 1,
      },
      defaults: { ease: 'power2.inOut' },
    });

    heroStates.forEach((state, idx) => {
      heroTl.addLabel(state.label, idx * 1.2);
    });

    heroTl
      .to('.color-wash', { opacity: 0.5, duration: 1.2 }, 'seed')
      .to('.color-wash', { opacity: 0.9, filter: 'blur(60px)', duration: 1.5 }, 'seed+=0.33')
      .to('.color-wash', { opacity: 0.6, background: 'radial-gradient(circle at 70% 20%, rgba(255,255,255,0.35), transparent 32%), radial-gradient(circle at 40% 80%, rgba(82,32,255,0.35), transparent 36%)', duration: 1.4 }, 'seed+=0.66')
      .fromTo('.hero-card', { scale: 0.92, y: 36, opacity: 0.72, rotateY: -12, rotateX: 6 }, { scale: 1, y: 0, opacity: 1, rotateY: -6, rotateX: 4, duration: 1.1 }, 'seed')
      .fromTo('.hero-copy', { y: 20, opacity: 0 }, { y: 0, opacity: 1, duration: 1.2 }, 'seed+=0.05')
      .fromTo(orbitBadges, { opacity: 0, y: 12 }, { opacity: 1, y: 0, duration: 0.8, stagger: 0.08 }, 'seed+=0.25');

    heroStates.forEach((state) => {
      heroTl.to('.hero-card', {
        '--card-hue': state.hue,
        '--card-alpha': state.alpha,
        y: state.y,
        rotateY: state.rotateY,
        rotateX: state.rotateX,
        boxShadow: state.glow,
      }, state.label);

      heroTl.to('.card-glow', { opacity: 0.85, filter: 'blur(70px)', rotate: '+=40deg' }, state.label);

      heroTl.to('.color-wash', {
        background: `radial-gradient(circle at 20% 30%, rgba(${120 + state.hue % 90},255,211,0.22), transparent 32%), radial-gradient(circle at 80% 70%, rgba(${82 + state.hue % 60},32,255,0.28), transparent 35%)`,
        filter: 'blur(70px)',
      }, state.label);
    });

    if (morphCards.length) {
      const morphTl = gsap.timeline({ defaults: { ease: 'power2.inOut' } });
      heroStates.forEach((state, idx) => {
        morphTl.addLabel(state.label, idx * 1.2);
        const card = morphCards[idx % morphCards.length];
        morphTl.to(card, {
          y: -8 - idx * 8,
          rotateY: idx * -6,
          rotateX: idx * 4,
          rotateZ: idx * -1.5,
          opacity: 0.8 + idx * 0.05,
          boxShadow: `0 20px ${80 + idx * 15}px rgba(82,32,255,0.${6 + idx})`,
          scale: 1 + idx * 0.02,
        }, state.label);
      });

      heroTl.add(morphTl, 'seed');
    }

    layers.forEach((layer, index) => {
      gsap.to(layer, {
        yPercent: index === 0 ? -6 : index === 1 ? -12 : -18,
        scale: 1.02 + index * 0.01,
        filter: `blur(${index * 2}px)`,
        scrollTrigger: {
          trigger: hero,
          start: 'top top',
          end: scrollSpan,
          scrub: true,
        },
      });
      gsap.to(layer, {
        opacity: 0.55 + index * 0.1,
        scrollTrigger: {
          trigger: hero,
          start: 'top center',
          end: 'bottom top',
          scrub: true,
        },
      });
    });
  }

  if (hero && prefersReducedMotion) {
    layers.forEach((layer, index) => {
      layer.style.opacity = `${0.55 + index * 0.1}`;
      layer.style.filter = 'blur(0px)';
    });
  }

  if (heroCopy && !prefersReducedMotion && hasGSAP) {
    gsap.fromTo(heroCopy.querySelectorAll('.eyebrow, h1, .lede, .hero-actions, .microcopy'), {
      opacity: 0,
      y: 16,
    }, {
      opacity: 1,
      y: 0,
      stagger: 0.08,
      duration: 0.8,
      ease: 'power3.out',
    });
  }

  if (!prefersReducedMotion && hasGSAP) {
    featureCards.forEach((card, i) => {
      gsap.from(card, {
        opacity: 0,
        y: 22,
        duration: 0.8,
        ease: 'power2.out',
        delay: i * 0.05,
        scrollTrigger: {
          trigger: card,
          start: 'top 85%',
        },
      });
    });
  } else {
    featureCards.forEach((card) => {
      card.style.opacity = '1';
      card.style.transform = 'none';
    });
  }

  if (!prefersReducedMotion && hasGSAP) {
    journeySteps.forEach((step, i) => {
      gsap.from(step, {
        opacity: 0,
        y: 18,
        duration: 0.7,
        delay: i * 0.08,
        scrollTrigger: {
          trigger: step,
          start: 'top 80%',
        },
      });
    });
  }

  if (heroCard && window.visualizerControl && hasGSAP) {
    ScrollTrigger.create({
      trigger: heroCard,
      start: 'top 80%',
      end: 'bottom top',
      onEnter: () => window.visualizerControl.init(),
      onEnterBack: () => window.visualizerControl.init(),
      onLeave: () => window.visualizerControl.destroy(),
      onLeaveBack: () => window.visualizerControl.destroy(),
    });

    gsap.to(heroCard, {
      y: -6,
      boxShadow: '0 30px 140px rgba(82,32,255,0.4)',
      scrollTrigger: {
        trigger: heroCard,
        start: 'top center',
        end: 'bottom center',
        scrub: true,
      },
    });
  }

  if (hero && hasGSAP && stateMarkers.length > 0 && !prefersReducedMotion) {
    ScrollTrigger.create({
      trigger: hero,
      start: 'top top',
      end: scrollSpan,
      scrub: true,
      onUpdate: (self) => {
        const progress = self.progress;
        if (stateBarFill) {
          stateBarFill.style.setProperty('--hero-progress', `${progress * 100}%`);
        }

        stateMarkers.forEach((marker, idx) => {
          const segment = idx / (stateMarkers.length - 1);
          const nextSegment = (idx + 1) / (stateMarkers.length - 1);
          const isActive = progress >= segment - 0.001 && progress < (nextSegment || 1.01);
          marker.classList.toggle('active', isActive);
          marker.setAttribute('aria-current', isActive ? 'step' : 'false');
        });
      },
    });
  }

  const ctaForm = document.querySelector('.cta-form');
  if (ctaForm) {
    const microcopy = ctaForm.querySelector('.microcopy');
    if (microcopy) {
      microcopy.setAttribute('aria-live', 'polite');
    }

    ctaForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const button = ctaForm.querySelector('button');
      button.textContent = 'Request received — check your inbox soon';
      button.disabled = true;
    });
  }
});
