(() => {
  const canvas = document.getElementById('visualizer');
  if (!canvas) return;

  let ctx;
  let animationFrame;
  let startTime;
  let running = false;

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = canvas.clientWidth * dpr;
    canvas.height = canvas.clientHeight * dpr;
    if (ctx) {
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }
  }

  function draw(t) {
    if (!ctx) return;
    if (!startTime) startTime = t;
    const elapsed = (t - startTime) / 1000;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    const w = canvas.clientWidth;
    const h = canvas.clientHeight;

    const card = canvas.closest('.hero-card');
    const baseHue = card ? Number(getComputedStyle(card).getPropertyValue('--card-hue')) || 240 : 240;

    // Holographic gradient
    const gradient = ctx.createLinearGradient(0, 0, w, h);
    gradient.addColorStop(0, `hsla(${baseHue + Math.sin(elapsed) * 20}, 90%, 70%, 0.45)`);
    gradient.addColorStop(0.5, `hsla(${baseHue - 40 + Math.sin(elapsed * 1.2) * 40}, 90%, 75%, 0.55)`);
    gradient.addColorStop(1, `hsla(${baseHue + 60 + Math.cos(elapsed * 0.8) * 30}, 95%, 80%, 0.4)`);
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, w, h);

    // Evolving texture lines
    const lines = 28;
    for (let i = 0; i < lines; i++) {
      const progress = i / lines;
      const y = h * progress + Math.sin(elapsed * 1.5 + i * 0.4) * 12;
      const alpha = 0.12 + Math.sin(elapsed + i) * 0.06;
      ctx.beginPath();
      ctx.moveTo(-20, y);
      ctx.bezierCurveTo(w * 0.25, y + Math.sin(elapsed * 0.8 + i) * 30, w * 0.65, y - Math.cos(elapsed * 0.6 + i) * 24, w + 20, y + 6);
      ctx.strokeStyle = `hsla(${240 + progress * 80}, 90%, 82%, ${alpha})`;
      ctx.lineWidth = 1.2 + Math.sin(elapsed * 0.7 + i) * 0.3;
      ctx.stroke();
    }

    // Particles
    for (let p = 0; p < 36; p++) {
      const angle = (p / 36) * Math.PI * 2 + elapsed * 0.4;
      const radius = 80 + Math.sin(elapsed * 1.2 + p) * 24;
      const x = w / 2 + Math.cos(angle) * radius;
      const y = h / 2 + Math.sin(angle) * radius * 0.55;
      ctx.beginPath();
      ctx.fillStyle = `hsla(${180 + p * 4}, 95%, 80%, 0.4)`;
      ctx.arc(x, y, 2 + Math.sin(elapsed + p) * 1.5, 0, Math.PI * 2);
      ctx.fill();
    }

    animationFrame = requestAnimationFrame(draw);
  }

  function init() {
    if (prefersReducedMotion || running) return;
    ctx = canvas.getContext('2d');
    running = true;
    startTime = undefined;
    resize();
    animationFrame = requestAnimationFrame(draw);
  }

  function destroy() {
    running = false;
    if (animationFrame) cancelAnimationFrame(animationFrame);
    animationFrame = undefined;
    if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height);
  }

  window.visualizerControl = { init, destroy };

  window.addEventListener('resize', resize);
})();
