import { gsap } from 'gsap';
import ScrollTrigger from 'gsap/ScrollTrigger';
import { createVisualizerControl } from './visualizer';

gsap.registerPlugin(ScrollTrigger);

const reduceMotionMedia = window.matchMedia('(prefers-reduced-motion: reduce)');
const prefersReducedMotion = reduceMotionMedia.matches;
if (prefersReducedMotion) {
  document.body.classList.add('reduce-motion');
}

const hero = document.getElementById('morphing-hero');
const layers = gsap.utils.toArray('.hero-bg .layer');
const heroCopy = document.querySelector('.hero-copy');
const heroCard = document.getElementById('crystal-card');
const morphCards = gsap.utils.toArray('.morph-card');
const journeySteps = gsap.utils.toArray('.journey-step');
const featureCards = gsap.utils.toArray('.feature-card');
const stateMarkers = gsap.utils.toArray('.hero-state');
const stateBarFill = document.querySelector('.hero-progress .fill');
const orbitBadges = gsap.utils.toArray('.orbit-badge');
const galleryCards = gsap.utils.toArray('.gallery-card');
const parallaxZones = gsap.utils.toArray('[data-zone]');
const scrollSpan = () => `+=${Math.round(window.innerHeight * 8)}`;

const visualizerControl = heroCard ? createVisualizerControl(document.getElementById('visualizer')) : null;

const heroStates = [
  { label: 'seed', hue: 260, alpha: 0.65, rotateY: -10, rotateX: 6, y: 26, glow: '0 30px 140px rgba(82,32,255,0.45)', shimmer: 0.8, warp: 0.35 },
  { label: 'epitaxy', hue: 210, alpha: 0.72, rotateY: 8, rotateX: -6, y: 6, glow: '0 40px 160px rgba(85,255,211,0.45)', shimmer: 1.2, warp: 0.55 },
  { label: 'growth', hue: 300, alpha: 0.7, rotateY: -6, rotateX: 8, y: -12, glow: '0 50px 180px rgba(199,183,255,0.4)', shimmer: 1.4, warp: 0.7 },
  { label: 'radiance', hue: 180, alpha: 0.68, rotateY: 0, rotateX: 0, y: -4, glow: '0 50px 200px rgba(85,255,211,0.5)', shimmer: 1.6, warp: 0.9 },
];

function setupHero() {
  if (!hero || prefersReducedMotion) {
    layers.forEach((layer, index) => {
      layer.style.opacity = `${0.55 + index * 0.1}`;
      layer.style.filter = 'blur(0px)';
    });
    return;
  }

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
    .to(
      '.color-wash',
      {
        opacity: 0.6,
        background:
          'radial-gradient(circle at 70% 20%, rgba(255,255,255,0.35), transparent 32%), radial-gradient(circle at 40% 80%, rgba(82,32,255,0.35), transparent 36%)',
        duration: 1.4,
      },
      'seed+=0.66',
    )
    .fromTo(
      '.hero-card',
      { scale: 0.92, y: 36, opacity: 0.72, rotateY: -12, rotateX: 6 },
      { scale: 1, y: 0, opacity: 1, rotateY: -6, rotateX: 4, duration: 1.1 },
      'seed',
    )
    .fromTo('.hero-copy', { y: 20, opacity: 0 }, { y: 0, opacity: 1, duration: 1.2 }, 'seed+=0.05')
    .fromTo(orbitBadges, { opacity: 0, y: 12 }, { opacity: 1, y: 0, duration: 0.8, stagger: 0.08 }, 'seed+=0.25');

  heroStates.forEach((state) => {
    heroTl.to(
      '.hero-card',
      {
        '--card-hue': state.hue,
        '--card-alpha': state.alpha,
        y: state.y,
        rotateY: state.rotateY,
        rotateX: state.rotateX,
        boxShadow: state.glow,
      },
      state.label,
    );

    heroTl.to('.card-glow', { opacity: 0.85, filter: 'blur(70px)', rotate: '+=40deg' }, state.label);

    heroTl.to(
      '.color-wash',
      {
        background: `radial-gradient(circle at 20% 30%, rgba(${120 + (state.hue % 90)},255,211,0.22), transparent 32%), radial-gradient(circle at 80% 70%, rgba(${82 + (state.hue % 60)},32,255,0.28), transparent 35%)`,
        filter: 'blur(70px)',
      },
      state.label,
    );

    heroTl.call(
      () => {
        if (visualizerControl) {
          visualizerControl.tune({ baseHue: state.hue, shimmer: state.shimmer, warp: state.warp });
        }
        heroCard?.setAttribute('data-state', state.label);
      },
      null,
      state.label,
    );
  });

  if (morphCards.length) {
    const morphTl = gsap.timeline({ defaults: { ease: 'power2.inOut' } });
    heroStates.forEach((state, idx) => {
      morphTl.addLabel(state.label, idx * 1.2);
      const card = morphCards[idx % morphCards.length];
      morphTl.to(
        card,
        {
          y: -8 - idx * 8,
          rotateY: idx * -6,
          rotateX: idx * 4,
          rotateZ: idx * -1.5,
          opacity: 0.8 + idx * 0.05,
          boxShadow: `0 20px ${80 + idx * 15}px rgba(82,32,255,0.${6 + idx})`,
          scale: 1 + idx * 0.02,
        },
        state.label,
      );
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

function setupParallaxZones() {
  if (prefersReducedMotion) return;
  parallaxZones.forEach((zone) => {
    if (zone.id === 'morphing-hero') return;
    const direction = zone.dataset.direction === 'descend' ? -1 : 1;
    const scale = parseFloat(zone.dataset.scale || '1.2');
    const depthNodes = gsap.utils.toArray(zone.querySelectorAll('[data-depth]'));

    depthNodes.forEach((layer) => {
      const depth = parseFloat(layer.dataset.depth || '14');
      gsap.fromTo(
        layer,
        { yPercent: direction * depth },
        {
          yPercent: direction * depth * -1,
          ease: 'none',
          scrollTrigger: {
            trigger: zone,
            start: 'top bottom',
            end: 'bottom top',
            scrub: true,
          },
        },
      );
    });

    if (zone.dataset.pin === 'true') {
      ScrollTrigger.create({
        trigger: zone,
        start: 'top top',
        end: () => `+=${Math.round(window.innerHeight * (scale + 0.3))}`,
        pin: true,
        scrub: true,
        anticipatePin: 1,
      });
    }
  });
}

function setupScrollStates() {
  if (!hero || stateMarkers.length === 0 || prefersReducedMotion) return;

  ScrollTrigger.create({
    trigger: hero,
    start: 'top top',
    end: scrollSpan,
    scrub: true,
    onUpdate: (self) => {
      const progress = self.progress;
      if (visualizerControl) {
        visualizerControl.tune({ shimmer: 0.8 + progress * 0.7 });
      }
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

function setupReducedMotionFallbacks() {
  if (prefersReducedMotion) {
    featureCards.forEach((card) => {
      card.style.opacity = '1';
      card.style.transform = 'none';
    });
    journeySteps.forEach((step) => {
      step.style.opacity = '1';
      step.style.transform = 'none';
    });
  }
}

function setupFeatureAndJourneyAnimations() {
  if (prefersReducedMotion) return;

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

function setupGalleryReactions() {
  if (prefersReducedMotion) return;
  galleryCards.forEach((card, i) => {
    gsap.from(card, {
      opacity: 0,
      y: 28,
      duration: 0.9,
      delay: i * 0.08,
      ease: 'power3.out',
      scrollTrigger: {
        trigger: card,
        start: 'top 85%',
      },
    });

    const media = card.querySelector('img');
    const quickTilt = gsap.quickTo(card, 'rotateX', { duration: 0.6, ease: 'power2.out' });
    const quickTiltY = gsap.quickTo(card, 'rotateY', { duration: 0.6, ease: 'power2.out' });

    card.addEventListener('pointermove', (event) => {
      const rect = card.getBoundingClientRect();
      const xr = (event.clientX - rect.left) / rect.width - 0.5;
      const yr = (event.clientY - rect.top) / rect.height - 0.5;
      quickTilt(yr * -6);
      quickTiltY(xr * 6);
      if (media) media.style.transform = `translateZ(0) scale(1.01) translate(${xr * 6}px, ${yr * 6}px)`;
    });

    card.addEventListener('pointerleave', () => {
      quickTilt(0);
      quickTiltY(0);
      if (media) media.style.transform = 'translateZ(0) scale(1) translate(0, 0)';
    });
  });
}

function setupHeroCopyEntrance() {
  if (!heroCopy || prefersReducedMotion) return;
  gsap.fromTo(
    heroCopy.querySelectorAll('.eyebrow, h1, .lede, .hero-actions, .microcopy'),
    {
      opacity: 0,
      y: 16,
    },
    {
      opacity: 1,
      y: 0,
      stagger: 0.08,
      duration: 0.8,
      ease: 'power3.out',
    },
  );
}

function setupVisualizerScrollLifecycle() {
  if (!heroCard || !visualizerControl || prefersReducedMotion) return;

  ScrollTrigger.create({
    trigger: heroCard,
    start: 'top 80%',
    end: 'bottom top',
    onEnter: () => visualizerControl.init(),
    onEnterBack: () => visualizerControl.init(),
    onLeave: () => visualizerControl.destroy(),
    onLeaveBack: () => visualizerControl.destroy(),
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

function setupHeroMicroReactions() {
  if (!heroCard || prefersReducedMotion) return;

  const glow = heroCard.querySelector('.card-glow');
  const quickGlowX = glow ? gsap.quickTo(glow, 'xPercent', { duration: 0.6, ease: 'power2.out' }) : null;
  const quickGlowY = glow ? gsap.quickTo(glow, 'yPercent', { duration: 0.6, ease: 'power2.out' }) : null;

  const handleMove = (event) => {
    const rect = heroCard.getBoundingClientRect();
    const xRatio = (event.clientX - rect.left) / rect.width;
    const yRatio = (event.clientY - rect.top) / rect.height;
    heroCard.style.setProperty('--pointer-x', `${(xRatio * 100).toFixed(2)}%`);
    heroCard.style.setProperty('--pointer-y', `${(yRatio * 100).toFixed(2)}%`);

    if (quickGlowX && quickGlowY) {
      quickGlowX((xRatio - 0.5) * 30);
      quickGlowY((yRatio - 0.5) * 30);
    }

    visualizerControl?.setPointer(xRatio, yRatio);
    visualizerControl?.tune({ shimmer: 1 + Math.abs(xRatio - 0.5) * 1.1, warp: 0.5 + Math.abs(yRatio - 0.5) * 0.7 });
  };

  const handleLeave = () => {
    heroCard.style.setProperty('--pointer-x', '50%');
    heroCard.style.setProperty('--pointer-y', '50%');
    if (quickGlowX && quickGlowY) {
      quickGlowX(0);
      quickGlowY(0);
    }
    visualizerControl?.tune({ shimmer: 1, warp: 0.5 });
  };

  heroCard.addEventListener('pointermove', handleMove);
  heroCard.addEventListener('pointerleave', handleLeave);
}

function setupCTAForm() {
  const ctaForm = document.querySelector('.cta-form');
  if (!ctaForm) return;
  const microcopy = ctaForm.querySelector('.microcopy');
  if (microcopy) microcopy.setAttribute('aria-live', 'polite');

  ctaForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const button = ctaForm.querySelector('button');
    button.textContent = 'Request received — check your inbox soon';
    button.disabled = true;
  });
}

setupHero();
setupParallaxZones();
setupHeroCopyEntrance();
setupFeatureAndJourneyAnimations();
setupReducedMotionFallbacks();
setupVisualizerScrollLifecycle();
setupScrollStates();
setupHeroMicroReactions();
setupCTAForm();
setupGalleryReactions();
