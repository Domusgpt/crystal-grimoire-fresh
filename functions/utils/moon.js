export function calculateMoonPhase() {
  const now = new Date();
  const knownNewMoon = new Date('2024-01-11T11:57:00Z');
  const lunarCycle = 29.530589; // days

  const daysSince = (now.getTime() - knownNewMoon.getTime()) / (1000 * 60 * 60 * 24);
  const currentCycle = (daysSince % lunarCycle) / lunarCycle;

  let phase, emoji, illumination;

  if (currentCycle < 0.0625) {
    phase = 'New Moon';
    emoji = '🌑';
    illumination = 0;
  } else if (currentCycle < 0.1875) {
    phase = 'Waxing Crescent';
    emoji = '🌒';
    illumination = 0.25;
  } else if (currentCycle < 0.3125) {
    phase = 'First Quarter';
    emoji = '🌓';
    illumination = 0.5;
  } else if (currentCycle < 0.4375) {
    phase = 'Waxing Gibbous';
    emoji = '🌔';
    illumination = 0.75;
  } else if (currentCycle < 0.5625) {
    phase = 'Full Moon';
    emoji = '🌕';
    illumination = 1.0;
  } else if (currentCycle < 0.6875) {
    phase = 'Waning Gibbous';
    emoji = '🌖';
    illumination = 0.75;
  } else if (currentCycle < 0.8125) {
    phase = 'Last Quarter';
    emoji = '🌗';
    illumination = 0.5;
  } else {
    phase = 'Waning Crescent';
    emoji = '🌘';
    illumination = 0.25;
  }

  return {
    phase,
    emoji,
    illumination,
    timestamp: now.toISOString(),
    nextFullMoon: calculateNextPhase(0.5, currentCycle, now, lunarCycle),
    nextNewMoon: calculateNextPhase(0.0, currentCycle, now, lunarCycle),
  };
}

export function calculateNextPhase(targetPhase, currentPhase, now, lunarCycle) {
  let daysUntil;
  if (targetPhase >= currentPhase) {
    daysUntil = (targetPhase - currentPhase) * lunarCycle;
  } else {
    daysUntil = (1 - currentPhase + targetPhase) * lunarCycle;
  }

  const nextPhaseDate = new Date(now.getTime() + daysUntil * 24 * 60 * 60 * 1000);
  return nextPhaseDate.toISOString();
}
