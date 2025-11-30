const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

export function createVisualizerControl(canvas) {
  if (!canvas) return null;

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const state = {
    ctx: null,
    animationFrame: null,
    startTime: null,
    running: false,
    baseHue: 240,
    shimmer: 1,
    warp: 0.5,
    pointer: { x: 0.5, y: 0.5 },
  };

  const resize = () => {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = canvas.clientWidth * dpr;
    canvas.height = canvas.clientHeight * dpr;
    if (state.ctx) {
      state.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }
  };

  const draw = (timestamp) => {
    if (!state.ctx) return;
    if (!state.startTime) state.startTime = timestamp;
    const elapsed = (timestamp - state.startTime) / 1000;

    state.ctx.clearRect(0, 0, canvas.width, canvas.height);

    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    const hueDrift = state.baseHue + Math.sin(elapsed * 0.6) * 30;
    const shimmer = state.shimmer;
    const warp = state.warp;

    const gradient = state.ctx.createLinearGradient(0, 0, w, h);
    gradient.addColorStop(0, `hsla(${hueDrift}, 90%, 70%, ${0.35 + shimmer * 0.1})`);
    gradient.addColorStop(0.5, `hsla(${hueDrift - 40 + Math.sin(elapsed * 1.2) * 40}, 90%, 75%, ${0.45 + shimmer * 0.15})`);
    gradient.addColorStop(1, `hsla(${hueDrift + 60 + Math.cos(elapsed * 0.8) * 30}, 95%, 80%, ${0.4 + shimmer * 0.12})`);
    state.ctx.fillStyle = gradient;
    state.ctx.fillRect(0, 0, w, h);

    const lines = 30;
    for (let i = 0; i < lines; i++) {
      const progress = i / lines;
      const y = h * progress + Math.sin(elapsed * (1.2 + warp * 0.6) + i * 0.4) * (12 + warp * 6);
      const alpha = 0.1 + Math.sin(elapsed + i) * 0.05 + shimmer * 0.04;
      state.ctx.beginPath();
      state.ctx.moveTo(-20, y);
      state.ctx.bezierCurveTo(
        w * 0.25,
        y + Math.sin(elapsed * 0.8 + i) * (30 + warp * 20),
        w * 0.65,
        y - Math.cos(elapsed * 0.6 + i) * (24 + warp * 12),
        w + 20,
        y + 6,
      );
      state.ctx.strokeStyle = `hsla(${hueDrift + progress * 80}, 90%, 82%, ${alpha})`;
      state.ctx.lineWidth = 1.2 + Math.sin(elapsed * 0.7 + i) * 0.3 + shimmer * 0.3;
      state.ctx.stroke();
    }

    const particles = 38;
    for (let p = 0; p < particles; p++) {
      const angle = (p / particles) * Math.PI * 2 + elapsed * (0.4 + warp * 0.15);
      const radius = 70 + Math.sin(elapsed * (1.2 + warp * 0.2) + p) * 22;
      const x = w * state.pointer.x + Math.cos(angle) * radius;
      const y = h * state.pointer.y + Math.sin(angle) * radius * 0.55;
      state.ctx.beginPath();
      state.ctx.fillStyle = `hsla(${180 + p * 4}, 95%, 80%, ${0.3 + shimmer * 0.1})`;
      state.ctx.arc(x, y, 2 + Math.sin(elapsed + p) * 1.5 + shimmer * 0.8, 0, Math.PI * 2);
      state.ctx.fill();
    }

    state.animationFrame = requestAnimationFrame(draw);
  };

  const tune = (config) => {
    if (!config) return;
    if (typeof config.baseHue === 'number') state.baseHue = config.baseHue;
    if (typeof config.shimmer === 'number') state.shimmer = clamp(config.shimmer, 0.4, 2);
    if (typeof config.warp === 'number') state.warp = clamp(config.warp, 0.2, 1.4);
  };

  const setPointer = (x, y) => {
    state.pointer.x = clamp(x, 0, 1);
    state.pointer.y = clamp(y, 0, 1);
  };

  const init = () => {
    if (prefersReducedMotion || state.running) return;
    state.ctx = canvas.getContext('2d');
    state.running = true;
    state.startTime = null;
    resize();
    state.animationFrame = requestAnimationFrame(draw);
  };

  const destroy = () => {
    state.running = false;
    if (state.animationFrame) cancelAnimationFrame(state.animationFrame);
    state.animationFrame = null;
    if (state.ctx) state.ctx.clearRect(0, 0, canvas.width, canvas.height);
  };

  window.addEventListener('resize', resize);

  return { init, destroy, tune, setPointer };
}
