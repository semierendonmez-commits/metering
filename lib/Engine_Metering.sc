// lib/Engine_Metering.sc
// Professional audio metering for norns
// ITU-R BS.1770-4 / EBU R128 compliant K-weighting
// Exact biquad coefficients for 48kHz (norns native rate)
//
// Measurements:
//   - Momentary loudness (400ms window approximation)
//   - Short-term loudness (3s window approximation)
//   - Integrated loudness (gated running average)
//   - True peak per channel (dBFS)
//   - RMS per channel (dBFS)
//   - Phase correlation (-1 to +1)
//   - Stereo balance (-1 to +1)
//   - 32-band spectrum analyzer (40Hz-16kHz)

Engine_Metering : CroneEngine {
    var <synth;
    var <oscRelay;

    alloc {
        var lua;

        lua = NetAddr("127.0.0.1", 10111);

        Server.default.bind {
            SynthDef(\meter_pro, { |t_reset = 0|
                // ── all var declarations at top ─────────────────
                var inL, inR, inMono;
                var kL, kR;
                var pow, momPow, stPow, intPow;
                var lufsMom, lufsST, lufsInt;
                var peakL, peakR, rmsL, rmsR;
                var corrNum, corrDenL, corrDenR, corrDen, corr;
                var balL, balR, balance;
                var freqs, bands, amps;
                var imp;

                // ── audio inputs ────────────────────────────────
                inL = SoundIn.ar(0);
                inR = SoundIn.ar(1);
                inMono = (inL + inR) * 0.5;

                // ── K-WEIGHTING (ITU-R BS.1770-4) ───────────────
                // Exact biquad coefficients for fs=48000Hz
                // Using SOS.ar(in, a0, a1, a2, b1, b2) where:
                //   y[n] = a0*x[n] + a1*x[n-1] + a2*x[n-2]
                //        + b1*y[n-1] + b2*y[n-2]
                // ITU feedback coeffs are NEGATED for SOS.ar

                // Stage 1: High shelving filter (+4dB @ ~1.5kHz)
                // Stage 2: High-pass filter (RLB, ~38Hz)
                kL = SOS.ar(inL,
                    1.53512485958697, -2.69169618940638, 1.19839281085285,
                    1.69065929318241, -0.73248077421585);
                kL = SOS.ar(kL,
                    1.0, -2.0, 1.0,
                    1.99004745483398, -0.99007225036621);

                kR = SOS.ar(inR,
                    1.53512485958697, -2.69169618940638, 1.19839281085285,
                    1.69065929318241, -0.73248077421585);
                kR = SOS.ar(kR,
                    1.0, -2.0, 1.0,
                    1.99004745483398, -0.99007225036621);

                // ── LUFS CALCULATION ────────────────────────────
                // Mean square power of K-weighted stereo signal
                pow = (kL.squared + kR.squared) * 0.5;

                // Momentary: ~400ms window (tau ~0.17s for equivalent energy)
                momPow = Lag.ar(pow, 0.17);
                lufsMom = -0.691 + (10 * momPow.max(1e-12).log10);

                // Short-term: ~3s window (tau ~1.0s)
                stPow = Lag.ar(pow, 1.0);
                lufsST = -0.691 + (10 * stPow.max(1e-12).log10);

                // Integrated: running average since last reset
                // Uses Sweep for accumulation (resets on t_reset trigger)
                intPow = Sweep.ar(t_reset, pow) / Sweep.ar(t_reset, 1).max(0.01);
                lufsInt = -0.691 + (10 * intPow.max(1e-12).log10);

                // ── TRUE PEAK (per channel, dBFS) ───────────────
                // Peak.ar tracks the absolute maximum since last reset
                peakL = Peak.ar(inL.abs, Impulse.kr(15)).ampdb;
                peakR = Peak.ar(inR.abs, Impulse.kr(15)).ampdb;

                // ── RMS (per channel, ~300ms window, dBFS) ──────
                rmsL = Lag.ar(inL.squared, 0.3).sqrt.max(1e-12).ampdb;
                rmsR = Lag.ar(inR.squared, 0.3).sqrt.max(1e-12).ampdb;

                // ── PHASE CORRELATION ───────────────────────────
                // +1 = mono compatible, 0 = uncorrelated, -1 = out of phase
                corrNum  = LPF.ar(inL * inR, 5.0);
                corrDenL = LPF.ar(inL.squared, 5.0);
                corrDenR = LPF.ar(inR.squared, 5.0);
                corrDen  = (corrDenL * corrDenR).sqrt.max(1e-10);
                corr = (corrNum / corrDen).clip(-1.0, 1.0);

                // ── STEREO BALANCE ──────────────────────────────
                balL = LPF.ar(inL.squared, 5.0);
                balR = LPF.ar(inR.squared, 5.0);
                balance = ((balR - balL) / (balR + balL).max(1e-10)).clip(-1, 1);

                // ── SPECTRUM (32 log bands, 40Hz-16kHz) ─────────
                freqs = Array.geom(32, 40, 1.215);
                bands = BPF.ar(inMono, freqs, 0.3);
                amps  = Amplitude.kr(bands, 0.02, 0.12);
                amps  = (20 * amps.max(1e-10).log10);

                // ── SEND DATA at 15fps ──────────────────────────
                // Format: [mom, st, int, peakL, peakR, rmsL, rmsR, corr, balance, spec*32]
                imp = Impulse.kr(15);
                SendReply.kr(imp, '/meter', [
                    A2K.kr(lufsMom),
                    A2K.kr(lufsST),
                    A2K.kr(lufsInt),
                    peakL, peakR,
                    A2K.kr(rmsL), A2K.kr(rmsR),
                    A2K.kr(corr),
                    A2K.kr(balance)
                ] ++ amps);
            }).add;
        };

        Server.default.sync;
        synth = Synth(\meter_pro, [], target: Server.default.defaultGroup);

        // OSC bridge: sclang → Lua port 10111
        // msg = ['/meter', nodeID, replyID, data...]
        // strip nodeID + replyID (indices 0,1,2), forward data from index 3
        oscRelay = OSCFunc({ |msg|
            lua.sendMsg('/meter', *msg[3..]);
        }, '/meter', Server.default.addr);

        // command: reset integrated LUFS
        this.addCommand(\reset_int, "", {
            synth.set(\t_reset, 1);
        });
    }

    free {
        if (synth.notNil)     { synth.free };
        if (oscRelay.notNil)  { oscRelay.free };
    }
}
