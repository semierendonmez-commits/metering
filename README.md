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

## what's new in v1.1

- **strict standards**: the engine now strictly follows ITU-R BS.1770-4 and EBU R128 standards. uses exact 1682Hz high-shelf and 38.1Hz high-pass biquad filters.
- **absolute gating**: added a -70 LUFS absolute gate. if your track has a silent break, the integrated (INT) average will hold its place instead of dropping to negative infinity.
- **momentary loudness (MOM)**: added a 400ms momentary window to track fast transients and micro-dynamics.
- **hardware calibration**: added a trim offset to compensate for unbalanced (TS) cables or ADC headroom. defaults to +10 dB out of the box to seamlessly match standard daw levels, but can be fine-tuned using E1.

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


