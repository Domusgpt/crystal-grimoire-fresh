if (typeof gsap !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

document.addEventListener('DOMContentLoaded', () => {
  const reduceMotionMedia = window.matchMedia('(prefers-reduced-motion: reduce)');
  const prefersReducedMotion = reduceMotionMedia.matches;
  if (prefersReducedMotion) {
    document.body.classList.add('reduce-motion');
  }

  const hero = document.getElementById('morphing-hero');
  const heroContent = document.querySelector('.hero-content');
  const layers = gsap.utils.toArray('.hero-bg .layer');
  const heroCopy = document.querySelector('.hero-copy');
  const heroCard = document.getElementById('crystal-card');
  const journeySteps = gsap.utils.toArray('.journey-step');
  const featureCards = gsap.utils.toArray('.feature-card');
  const scrollSpan = () => `+=${Math.round(window.innerHeight * 8)}`;

  if (hero && !prefersReducedMotion) {
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

    heroTl
      .to('.color-wash', { opacity: 0.5, duration: 1.2 }, 0)
      .to('.color-wash', { opacity: 0.9, filter: 'blur(60px)', duration: 1.5 }, 0.33)
      .to('.color-wash', { opacity: 0.6, background: 'radial-gradient(circle at 70% 20%, rgba(255,255,255,0.35), transparent 32%), radial-gradient(circle at 40% 80%, rgba(82,32,255,0.35), transparent 36%)', duration: 1.4 }, 0.66)
      .to(heroContent, { filter: 'brightness(1.05)', duration: 1.6 }, 0)
      .fromTo('.hero-card', { scale: 0.92, y: 30, opacity: 0.7 }, { scale: 1, y: 0, opacity: 1, duration: 1.6 }, 0.1)
      .fromTo('.hero-copy', { y: 20, opacity: 0 }, { y: 0, opacity: 1, duration: 1.2 }, 0.05);

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

  if (heroCopy && !prefersReducedMotion) {
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

  if (!prefersReducedMotion) {
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

  if (!prefersReducedMotion) {
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

  if (heroCard && window.visualizerControl) {
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
