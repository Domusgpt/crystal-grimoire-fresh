import { gsap } from 'https://cdn.skypack.dev/gsap@3.12.2';
import { ScrollTrigger } from 'https://cdn.skypack.dev/gsap@3.12.2/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

const zoneConfigs = [
  {
    id: 'intro-zone',
    name: 'Intro',
    start: 'top top',
    end: '+=120%',
    pin: true,
    direction: 'up',
    accent: '#E0AAFF'
  },
  {
    id: 'ascent-zone',
    name: 'Ascent',
    start: 'top top',
    end: '+=150%',
    pin: true,
    direction: 'up',
    accent: '#7AE0FF'
  },
  {
    id: 'summit-zone',
    name: 'Summit',
    start: 'top top',
    end: '+=100%',
    pin: true,
    direction: 'calm',
    accent: '#FFE28F'
  },
  {
    id: 'descent-zone',
    name: 'Descent',
    start: 'top top',
    end: '+=150%',
    pin: true,
    direction: 'down',
    accent: '#FF9D7E'
  },
  {
    id: 'landing-zone',
    name: 'Landing',
    start: 'top center',
    end: 'bottom top+=10%',
    pin: false,
    direction: 'down',
    accent: '#A7FFB5'
  }
];

const parallaxMap = {
  up: {
    fgFrom: 80,
    fgTo: -120,
    bgFrom: -40,
    bgTo: -180
  },
  down: {
    fgFrom: -120,
    fgTo: 80,
    bgFrom: -30,
    bgTo: 120
  },
  calm: {
    fgFrom: -40,
    fgTo: 40,
    bgFrom: -20,
    bgTo: 20
  }
};

function setCanvasBounds() {
  const canvases = document.querySelectorAll('.parallax-canvas');
  canvases.forEach((canvas) => {
    canvas.width = window.innerWidth * 1.2;
    canvas.height = window.innerHeight * 1.2;
  });
}

function updateActiveChip(activeName) {
  document.querySelectorAll('[data-zone-chip]').forEach((chip) => {
    chip.classList.toggle('is-active', chip.dataset.zoneChip === activeName);
  });
}

function createZoneTimeline(config) {
  const zone = document.getElementById(config.id);
  if (!zone) return;

  const backgroundCanvas = zone.querySelector('.background-canvas');
  const foregroundCanvas = zone.querySelector('.foreground-canvas');
  const copy = zone.querySelector('.zone-copy');

  zone.style.setProperty('--accent', config.accent);

  const directionSet = parallaxMap[config.direction] || parallaxMap.up;

  const timeline = gsap.timeline({
    scrollTrigger: {
      trigger: zone,
      start: config.start,
      end: config.end,
      scrub: true,
      pin: config.pin,
      anticipatePin: 1,
      onToggle: ({ isActive }) => zone.classList.toggle('is-active', isActive),
      onEnter: () => updateActiveChip(config.name),
      onEnterBack: () => updateActiveChip(config.name)
    }
  });

  if (backgroundCanvas) {
    timeline.fromTo(
      backgroundCanvas,
      { y: directionSet.bgFrom },
      { y: directionSet.bgTo, ease: 'none' },
      0
    );
  }

  if (foregroundCanvas) {
    timeline.fromTo(
      foregroundCanvas,
      { y: directionSet.fgFrom },
      { y: directionSet.fgTo, ease: 'none' },
      0
    );
  }

  if (copy) {
    timeline.fromTo(
      copy,
      { autoAlpha: 0, y: 30 },
      { autoAlpha: 1, y: 0, duration: 0.6, ease: 'power1.out' },
      0.1
    );
  }
}

function initJourney() {
  setCanvasBounds();
  zoneConfigs.forEach(createZoneTimeline);
  updateActiveChip(zoneConfigs[0].name);
}

window.addEventListener('load', initJourney);
window.addEventListener('resize', setCanvasBounds);
