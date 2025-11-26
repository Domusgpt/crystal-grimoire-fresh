# Crystal Grimoire Launch Site — Creative Brief

## Brand voice
- **Tone**: Neo-spiritual technomystic, welcoming, invitational; gentle confidence from a solo craftsperson (Paul Phillips / Clear Seas Solutions).
- **Personality**: Glassy calm, aurora glow, future-alchemy. Keeps language grounded in ritual and guidance without feeling commercialized.
- **Beta messaging**: Pre-release, invite-only beta with gratitude to early seekers and an emphasis on co-creating the experience.

## Visual system
- **Palette**: Deep iris (#120c26), ultraviolet (#5220ff), aurora mint (#55ffd3), soft lavender (#c7b7ff), holo white (#e8f0ff). Gradient overlays mix violet→cobalt→mint with noise grain.
- **Typography**: Headlines in "Space Grotesk" for geometric futurism; body/CTA in "Inter" for clarity.
- **Glass/holographic**: Blur + subtle border highlights (hsla(280,80%,80%,0.35)) + inner glows. Cards feature refracted multi-stop gradients and animated iridescent lines.
- **Imagery**: Epitaxial lattice patterns, faceted shards, and nebula haze. SVG layers support parallax depth.
- **Motion principles**:
  1. **Continuous morphing**: State-based morph journey across an 800vh pinned hero with GSAP ScrollTrigger.
  2. **Layered parallax**: Foreground shards drift faster than lattice/nebula layers; subtle z-translation cues.
  3. **Bidirectional zones**: Ascent zones drift upward, gallery zones drift downward; pins alternate with free-flow stretches to echo Facetad-style switchbacks.
  4. **Holographic reveals**: Cards fade/scale in with prism glows; holographic canvas visualizer initializes on entry, tears down on exit.
  5. **Breathing rhythm**: Easing via `power3.inOut` and `sine.inOut`; micro hover transforms.
  6. **Resource aware**: Visualizer pauses for reduced-motion or when scrolled away.

## Asset map
- `public/assets/epitaxy/nebula-back.svg` — aurora gradient haze for the far background.
- `public/assets/epitaxy/lattice-mid.svg` — epitaxial lattice lines and orbs for mid-layer parallax.
- `public/assets/epitaxy/shards-front.svg` — crystalline shards for foreground parallax.
- `public/assets/app-shots/` — SVG preview placeholders for oracle home, lunar ritual, collection vault, and sound bath (used in gallery parallax).

## Scroll + animation architecture
- Pinned hero (`#morphing-hero`) runs a GSAP timeline (`heroTl`) over ~8000px (~800vh) with 3 color states and SVG morph opacity/blur shifts.
- ScrollTrigger drives parallax transforms on each SVG layer and text opacity.
- Central holographic card (`#crystal-card`) controls a canvas visualizer lifecycle with ScrollTrigger callbacks to init/destroy, ensuring graceful cleanup.

## Narrative structure
1. **Hero**: Beta invite, morphing epitaxy backdrop, holographic card/visualizer.
2. **Highlights**: AI crystal identification, rituals, sound bath, dream journal, lunar intelligence.
3. **Journey**: Scroll vignette describing epitaxial growth metaphor for the product roadmap.
4. **Founder note**: Paul Phillips / Clear Seas Solutions personal invite with CTA.
