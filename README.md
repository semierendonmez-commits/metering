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


