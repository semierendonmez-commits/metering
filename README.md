# metering v1.1

an audio analyzer for [norns](https://monome.org/docs/norns/)

turn your norns into a dedicated hardware metering unit. it listens to the physical audio inputs (L/R) and provides real-time visual feedback for mastering, mixing, or live performance monitoring. 

the engine uses a highly optimized supercollider dsp core for the heavy lifting (k-weighting filters, fft) while the lua frontend renders the truth at 15 frames per second.


## requirements

- norns (shield, standard, or fates)
- an active audio signal going into the hardware inputs (`Line In`)

### the tools

**LUFS**: massive short-term and integrated loudness values. dial in your desired target (e.g. -14dB) using E2. the numbers will glow when you hit your target.

**spectrum**: a 32-band logarithmic analyzer. complete with smooth "peak hold" dots that fall with gravity, just like your favorite daw plugins. if the input is quiet, use E3 to pull the ceiling down and zoom in.

**phase**: a simple correlation meter. quickly check if your stereo field is beautifully wide (0), perfectly mono (+1), or dangerously out-of-phase (-1).

---

v2.0.0 — modular layout + goniometer
metering v2 is here. page 1 is now fully configurable. four slots, ten widgets — build the metering layout you need.

what’s new
modular slot system — page 1 is a 2×2 grid. each slot is assigned from the params menu. choose from: ST LUFS, INT LUFS, MOM, PHASE, GONIOMETER, SPECTRUM, PEAK/RMS, BALANCE, CREST, or EMPTY. slot assignments save with presets.

goniometer — proper Lissajous/M-S stereo image display with fading trail. mono signal draws a vertical line, wide stereo scatters, out-of-phase goes horizontal. essential for checking stereo compatibility.

momentary — 400ms window loudness, now available as its own widget alongside short-term and integrated.

ITU-R BS.1770-4 K-weighting — the engine now uses exact biquad coefficients from the standard via SOS.ar. no more approximation. at 48kHz (norns native rate) the filter matches the spec precisely.

crest factor widget — shows peak minus RMS in dB. low crest = compressed, high crest = dynamic. useful for monitoring your mix dynamics in real time.

input offset on E1 — always accessible, always visible on screen. default +10dB. no more digging through menus to calibrate.

updated controls
| control | function |
| E1 | input offset (dB) |

| E2 | target LUFS |

| E3 | spectrum ceiling |

| K1 | page toggle |

| K2 | freeze |

| K3 | reset INT LUFS + peaks |

---

### what's new in v1.1?

**1. hardware calibration trim (E1)**
*why is my norns showing -24 when my daw shows -14?* if you use unbalanced (ts) cables or hit the hardware adc headroom, you lose exact voltage. to fix this, **E1** is now a calibration trim. the script **defaults to +10 db** ( set after my own output calibration tests) out of the box to perfectly match most standard audio interfaces and daw levels, but you can always fine-tune it to your studio by turning E1.


**2. momentary LUFS (MOM)**
the ui now features three LUFS values. alongside the 3-second SHORT and the overall INT, there is now a 400ms MOMENTARY meter. it dances beautifully with your kicks and transients.

**3. Engine rewrite**
the dsp engine has been rewritten to strictly follow itu-r bs.1770-4 / ebu r128 standards. it now features an absolute gate at -70 LUFS. if you stop the music or hit a silent break, the integrated (INT) average holds its place instead of dropping to negative infinity. mathematically identical to your studio plugins.


## controls

| control | function |
|---------|----------|
| **K2** | freeze / unfreeze display |
| **K3** | reset integrated (INT) LUFS calculation |
| **E1** | adjust hardware calibration trim (defaults to +10 dB) |
| **E2** | adjust target LUFS reference line (0 to -40 dB) |
| **E3** | adjust spectrum max dB (zoom in on quiet signals) |


## install
(note: be sure to restart your norns after the first installation so the supercollider engine compiles correctly.)

from maiden:

```text
;install https://github.com/semierendonmez-commits/metering


``` 

# changelog

all notable changes to the `metering` script.

v2.0.0 — modular layout + goniometer
metering v2 is here. page 1 is now fully configurable. four slots, ten widgets — build the metering layout you need.

what’s new
modular slot system — page 1 is a 2×2 grid. each slot is assigned from the params menu. choose from: ST LUFS, INT LUFS, MOM, PHASE, GONIOMETER, SPECTRUM, PEAK/RMS, BALANCE, CREST, or EMPTY. slot assignments save with presets.

goniometer — proper Lissajous/M-S stereo image display with fading trail. mono signal draws a vertical line, wide stereo scatters, out-of-phase goes horizontal. essential for checking stereo compatibility.

momentary — 400ms window loudness, now available as its own widget alongside short-term and integrated.

ITU-R BS.1770-4 K-weighting — the engine now uses exact biquad coefficients from the standard via SOS.ar. no more approximation. at 48kHz (norns native rate) the filter matches the spec precisely.

crest factor widget — shows peak minus RMS in dB. low crest = compressed, high crest = dynamic. useful for monitoring your mix dynamics in real time.

input offset on E1 — always accessible, always visible on screen. default +10dB. no more digging through menus to calibrate.

updated controls
| control | function |
| E1 | input offset (dB) |

| E2 | target LUFS |

| E3 | spectrum ceiling |

| K1 | page toggle |

| K2 | freeze |

| K3 | reset INT LUFS + peaks |



### v1.1.1
- **optimization**: removed global namespace pollution (`_G.screen_dirty`) in favor of local variables based on community feedback. ensures better memory management and zero chance of variable collisions with other scripts.
- **tweak**: set the default hardware calibration trim to +10 db out of the box to better match standard audio interfaces and daw levels.

### v1.1.0
- **feature**: added hardware calibration trim (E1). compensates for unbalanced (ts) cable voltage drops (-6.02 db) and hardware a/d converter headroom. calibrate once to match your daw, trust it forever.

### v1.0.0 **initial release**
- **feature**: added momentary (MOM) lufs meter (400ms window) for tracking fast transients and micro-dynamics.
- **engine**: rewritten dsp core to strictly follow itu-r bs.1770-4 and ebu r128 standards.
- **engine**: implemented exact 1682hz high-shelf and 38.1hz high-pass biquad filters for accurate k-weighting.
- **feature**: added an absolute gate at -70 lufs. silent breaks in tracks no longer drag the integrated (INT) average down to negative infinity.

### v0.9.0
- **ui**: massive visual overhaul. dedicated left half of the screen to giant, easily readable lufs values.
- **feature**: added target lufs reference line (E2). numbers glow when the signal hits or exceeds the target.
- **feature**: added gravity-based "peak hold" dots to the 32-band spectrum analyzer.
- **feature**: added spectrum ceiling / zoom control (E3) to visibly monitor quiet signals.
- **feature**: added freeze display function (K2) to catch and analyze specific audio frames.

### v0.2.0.
- **bugfix**: built a dedicated osc routing bridge (`OSCFunc`) in the supercollider engine to properly forward `/meter_data` out of scsynth and into the norns lua environment via port 10111.

### v0.1.0
- **beta release**: basic framework established with 32-band logarithmic spectrum analyzer, short-term / integrated lufs, and goniometer-style phase correlation meter.

