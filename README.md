# metering

a professional-grade audio analyzer for [norns](https://monome.org/docs/norns/)

turn your norns into a dedicated hardware metering unit. it listens to the physical audio inputs (L/R) and provides real-time visual feedback for mastering, mixing, or live performance monitoring. 

the engine uses a highly optimized supercollider dsp core for the heavy lifting (k-weighting filters, fft) while the lua frontend renders the truth at 15 frames per second.


## requirements

- norns (shield, standard, or fates)
- an active audio signal going into the hardware inputs (`Line In`)




## install
(note: be sure to restart your norns after the first installation so the supercollider engine compiles correctly.)

from maiden:

```text
;install [https://github.com/semierendonmez-commits/metering](https://github.com/semierendonmez-commits/metering)


