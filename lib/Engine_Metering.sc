// lib/Engine_Metering.sc
// Gerçek zamanlı LUFS, Spectrum ve Phase Correlation analizörü

Engine_Metering : CroneEngine {
    var <synth;
    var <oscFunc; // Lua'ya köprü vazifesi görecek değişken

    alloc {
        // Norns'un Lua katmanının dinlediği yerel IP ve Port
        var lua = NetAddr("127.0.0.1", 10111);

        Server.default.bind {
            
            SynthDef(\analyzer, { |t_reset = 0|
                var in, kweight, pow, stPow, intPow, lufsST, lufsInt;
                var corrNum, corrDen, corr;
                var freqs, bands, amps;
                var imp;

                // Norns donanım ses girişlerini (Audio In L/R) dinliyoruz
                in = SoundIn.ar([0, 1]);

                // 1. LUFS HESAPLAMASI
                kweight = BHiShelf.ar(in, 1500, 1, 4);
                kweight = HPF.ar(kweight, 38);
                pow = kweight[0].squared + kweight[1].squared;

                stPow = Lag.ar(pow, 3.0);
                lufsST = -0.691 + (10 * stPow.max(0.0000001).log10);

                intPow = Sweep.ar(t_reset, pow) / Sweep.ar(t_reset, 1).max(0.001);
                lufsInt = -0.691 + (10 * intPow.max(0.0000001).log10);

                // 2. PHASE CORRELATION
                corrNum = LPF.ar(in[0] * in[1], 2.0);
                corrDen = sqrt(LPF.ar(in[0].squared, 2.0) * LPF.ar(in[1].squared, 2.0)).max(0.00001);
                corr = (corrNum / corrDen).clip(-1.0, 1.0);

                // 3. SPECTRUM ANALYZER
                freqs = Array.geom(32, 40, 1.215); 
                bands = BPF.ar(in[0] + in[1], freqs, 0.3); 
                amps = Amplitude.kr(bands, 0.05, 0.1); 
                amps = 20 * amps.max(0.00001).log10; 

                // Veriyi SC katmanına at (15 fps)
                imp = Impulse.kr(15);
                SendReply.kr(imp, '/meter_data', [
                    A2K.kr(lufsST), 
                    A2K.kr(lufsInt), 
                    A2K.kr(corr)
                ] ++ amps);

            }).add;
        };

        Server.default.sync;
        synth = Synth(\analyzer, [], target: Server.default.defaultGroup);

        // KÖPRÜ: SC'den gelen veriyi al ve Lua portuna (10111) yönlendir
        oscFunc = OSCFunc({ |msg|
            // msg formatı: [ '/meter_data', nodeID, replyID, lufsST, lufsInt, corr, amp1...amp32 ]
            // msg[3..] kullanarak ilk üç gereksiz kimlik verisini kesip salt değerleri Lua'ya atıyoruz
            lua.sendMsg('/meter_data', *msg[3..]);
        }, '/meter_data', Server.default.addr);

        this.addCommand(\reset_int, "", { 
            synth.set(\t_reset, 1); 
        });
    }

    free {
        synth.free;
        oscFunc.free; // Çıkarken dinleyiciyi temizle
    }
}
