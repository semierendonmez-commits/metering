// lib/Engine_Metering.sc
// ITU-R BS.1770-4 Standardında LUFS, Spectrum ve Phase Analizörü

Engine_Metering : CroneEngine {
    var <synth;
    var <oscFunc;

    alloc {
        var lua = NetAddr("127.0.0.1", 10111);

        Server.default.bind {
            
            SynthDef(\analyzer, { |t_reset = 0|
                var in, kweight, pow;
                var momPow, stPow, intPow, timeAccum;
                var lufsMom, lufsST, lufsInt;
                var corrNum, corrDen, corr;
                var freqs, bands, amps, imp, absGate;

                in = SoundIn.ar([0, 1]);

                // 1. K-WEIGHTING (İnsan Kulağı Simülasyonu)
                kweight = BHiShelf.ar(in, 1682.0, 1.0, 4.0);
                kweight = BHiPass.ar(kweight, 38.1, 2.0);
                
                // Mean Square (Kanal Güçlerinin Toplamı)
                pow = kweight[0].squared + kweight[1].squared;

                // 2. LUFS ÖLÇÜM PENCERELERİ (BS.1770-4)
                
                // Momentary (M) - ~400ms hızlı tepki penceresi
                momPow = Lag.ar(pow, 0.4);
                lufsMom = -0.691 + (10 * momPow.max(1e-10).log10);

                // Short-Term (S) - 3 saniyelik pencere
                stPow = Lag.ar(pow, 3.0);
                lufsST = -0.691 + (10 * stPow.max(1e-10).log10);

                // Integrated (I) - Gated genel ortalama (-70 LUFS Absolute Gate)
                absGate = pow > 1e-7; 
                intPow = Sweep.ar(t_reset, pow * absGate);
                timeAccum = Sweep.ar(t_reset, K2A.ar(1.0) * absGate).max(0.001);
                lufsInt = -0.691 + (10 * (intPow / timeAccum).max(1e-10).log10);

                // 3. PHASE CORRELATION & SPECTRUM
                corrNum = LPF.ar(in[0] * in[1], 2.0);
                corrDen = sqrt(LPF.ar(in[0].squared, 2.0) * LPF.ar(in[1].squared, 2.0)).max(0.00001);
                corr = (corrNum / corrDen).clip(-1.0, 1.0);

                freqs = Array.geom(32, 40, 1.215); 
                bands = BPF.ar(in[0] + in[1], freqs, 0.3); 
                amps = Amplitude.kr(bands, 0.05, 0.1); 
                amps = 20 * amps.max(0.00001).log10; 

                // Lua'ya 15 fps hızında gönderim
                imp = Impulse.kr(15);
                SendReply.kr(imp, '/meter_data', [
                    A2K.kr(lufsMom),
                    A2K.kr(lufsST), 
                    A2K.kr(lufsInt), 
                    A2K.kr(corr)
                ] ++ amps);

            }).add;
        };

        Server.default.sync;
        synth = Synth(\analyzer, [], target: Server.default.defaultGroup);

        // Veriyi yakalayıp Norns portuna ilet
        oscFunc = OSCFunc({ |msg|
            lua.sendMsg('/meter_data', *msg[3..]);
        }, '/meter_data', Server.default.addr);

        this.addCommand(\reset_int, "", { 
            synth.set(\t_reset, 1); 
        });
    }

    free {
        synth.free;
        oscFunc.free;
    }
}
