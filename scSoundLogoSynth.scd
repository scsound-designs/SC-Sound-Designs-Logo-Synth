//cleanup
Pdef.all.do(_.clear);
Pbindef.all.do(_.clear);
ServerTree.remove(~add_reverb);

//initialization
(
s = Server.local;
s.options.memSize_(65536 * 4);
s.waitForBoot;
s.meter;
s.scope;
FreqScope.new;
s.makeWindow;
)

//recording location
Platform.recordingsDir;

(
SynthDef(\fm, {| out = 0, pan = 0, amp = 0.2,
	freq=500, fScale = 1, buf = 0, detune = 0.2, phase = 0,
	mRatio = 1, cRatio = 1,  index = 1, iScale = 5, bassAmp = 0,
	atk = 0.01, sus = 0, rel = 3, cAtk = 4, cRel = (-4),
	rlpf = 22000, rlpfq = 1, rhpf = 0, rhpfq = 1,
	rout = 0, rsend = (-20) |

	var aEnv = EnvGen.kr(
		Env.new(
			[0, 1, 1, 0],
			[atk, sus, rel],
			[cAtk, cRel],
		), doneAction:2
	);

	var fEnv = EnvGen.kr(
		Env.new(
			[(freq * fScale), freq, freq, (freq * fScale)],
			[atk, sus, rel],
			[cAtk, cRel]
		)
	);

	var iEnv = EnvGen.kr(
		Env.new(
			[index, index * iScale, index],
			[atk, rel],
			[cAtk, cRel]
		)
	);

	var detuneCtrl = LFNoise1.kr(0.1!8).bipolar(detune).midiratio;
	var bassSin = SinOsc.ar(fEnv+rrand(-2,2).midicps) * bassAmp;
	var mod = SinOsc.ar(fEnv * mRatio, mul: freq * mRatio * iEnv);
	var car = SinOsc.ar(
		freq: fEnv * detuneCtrl * cRatio + mod,
		phase: {Rand(0,phase)}!8,
		mul: 0.7) + bassSin * aEnv *amp;

	// compress
	car = Compander.ar(car, car,
		thresh: 0.93,
		slopeBelow: 1.0,
		slopeAbove: 1/3,
		clampTime: 0.3,
		relaxTime: 0.03
	);
	// filter
	car = RLPF.ar(car, rlpf, rlpfq);
	car = RHPF.ar(car, rhpf, rhpfq);

	// pan
	car = Splay.ar(car);
	car = LeakDC.ar(car);
	car = Balance2.ar(car[0], car[1], pan, amp);
	car = car * aEnv * amp; //accidentally scaled twice, sounds ok...


	Out.ar(out, car);
	Out.ar(rout, car * rsend.dbamp);
	// TODO: out control bus
}).add;

SynthDef(\cloud, {| out = 0, amp = 0.2, pan = 0,
	freq=500, rq = 1, index = 1, iScale = 5,
	atk = 0.01, rel = 3, cAtk = 4, cRel = (-4),
	rout = 0, rsend = (-20) |

	var env = EnvGen.kr(
		Env.perc(atk, rel, curve: [cAtk, cRel]),
		doneAction: 2
	);
	var sig = PinkNoise.ar() * env * amp;

	sig = BPF.ar(sig, freq, rq);

	sig = Pan2.ar(sig, pan);

	Out.ar(out, sig);
	Out.ar(rout, sig * rsend.dbamp);
}).add;

SynthDef(\reverb, { | in=0, out=0, mix = 1, amp = 1,
	predelay = 1, revtime = 0.1, lpf=1500 |

	var dry = In.ar(in, 2);
	var wet = JPverb.ar(
		dry,
		\t60.kr(1.618,           0.05),
		\damp.kr(0.3,          0.05),
		\size.kr(1,          0.05),
		\earlydiff.kr(0.709, 0.05),
		\mdepth.kr(0.7,        0.05),
		\mfreq.kr(3,         0.05),
		\lowx.kr(1,          0.05),
		\midx.kr(0.9,          0.05),
		\highx.kr(0.9,         0.05),
		\lowband.kr(420,     0.05),
		\highband.kr(2000,   0.05)
	);

	var sig = XFade2.ar(dry, wet, mix*2-1, amp);

	Out.ar(out, sig);
}).add;
)


//instantiate reverb and re-instantiate when cmd-period is pressed
(
s.newBusAllocators;
~rbus = Bus.audio(s,2);
~add_reverb = {Synth(\reverb, [\in, ~rbus, \out, ~sbus])};
ServerTree.add(~add_reverb);
s.freeAll;
)

//---------------------------------------------
// fm
//---------------------------------------------

// TODO: expansion, lf xover to mono
( // glow
Pbindef(\glow,
	\instrument, \fm,
	\amp, 0.7,
	\bassAmp, 0.3,
	\freq, 30.midicps,
	\detune, 0,
	\phase, 0,
	\atk, 1,
	\sus, 0,
	\rel, 0.01,
	\index, 2,
	\iScale, 4,
	\mRatio, 4,
	\cRatio, 3.333,
	\cAtk, 3,
	\cRel, -9,
	\rlpf, 1200,
	\rlpfq, 1.5,
	\rout, ~rbus,
	\rsend, -30,
	\dur, Pseq([1], 1)
).play;
)

( // lowzap
Pbindef(\lowzap,
	\instrument, \fm,
	\amp, 0.5,
	\bassAmp, 0,
	\freq, [30, 66].midicps,
	\fScale, 1.1,
	\detune, 3,
	\phase, 2pi,
	\atk, 0.01,
	\sus, 0.1,
	\rel, 0.4,
	\index, 3,
	\iScale, 1.1,
	\mRatio, 11.333,
	\cRatio, 1,
	\cAtk, 3,
	\cRel, -7,
	\rlpf, 1400,
	\rlpfq, 1.3,
	\rhpf, 400,
	\rhpfq, 1.5,
	\rout, ~rbus,
	\rsend, -10,
	\dur, Pseq([1], 1)
).play;
)

( // bell
Pbindef(\lowbuzz,
	\instrument, \fm,
	\amp, 0.8,
	\bassAmp, 0.5,
	\freq, [43, 55].midicps,
	\fScale, 0.99,
	\detune, 0.1,
	\phase, 2pi,
	\atk, 0.006,
	\sus, 0,
	\rel, 3,
	\index, 4,
	\iScale, 0.3,
	\mRatio, 3.3,
	\cRatio, 1,
	\cAtk, -3,
	\cRel, 1,
	\rlpf, 2300,
	\rlpfq, 0.9,
	\rhpf, 120,
	\rhpfq, 1.3,
	\out, 0,
	\rout, ~rbus,
	\rsend, -10,
	\dur, Pseq([1], 1)
).play;
)

( // zap
Pbindef(\zap,
	\instrument, \fm,
	\amp, 0.7,
	\bassAmp, 0.0,
	\freq, [30].midicps,
	\fScale, 1,
	\detune, 0,
	\phase, 0,
	\atk, 0.01,
	\sus, 0.1,
	\rel, 1,
	\index, 1,
	\iScale, 1,
	\mRatio, 1,
	\cRatio, 1,
	\cAtk, 1,
	\cRel, 1,
	\rlpf, 1200,
	\rlpfq, 0.9,
	\rhpf, 18,
	\rhpfq, 0.9,
	\out, 0,
	\rout, ~rbus,
	\rsend, -0,
	\dur, Pseq([1], 1)
).play;
)

( // static_low
Pbindef(\static_low,
	\instrument, \fm,
	\amp, 0.3,
	\bassAmp, 0,
	\freq, [30].midicps,
	\fScale, 1,
	\detune, 0.9,
	\phase, 2pi,
	\atk, 0.7,
	\sus, 0.1,
	\rel, 3,
	\index, 3,
	\iScale, 1,
	\mRatio, 4.3,
	\cRatio, 1,
	\cAtk, 1,
	\cRel, -1,
	\rlpf, 1700,
	\rlpfq, 1.3,
	\rhpf, 180,
	\rhpfq, 1.5,
	\rout, ~rbus,
	\rsend, -10,
	\dur, Pseq([1], 1)
).play;
)

( // static_high
Pbindef(\static_high,
	\instrument, \fm,
	\amp, 0.7,
	\bassAmp, 0.1,
	\freq, [30].midicps,
	\fScale, 1,
	\detune, 0.9,
	\phase, 2pi,
	\atk, 0.7,
	\sus, 0.2,
	\rel, 1,
	\index, 4,
	\iScale, 1,
	\mRatio, 4.3,
	\cRatio, 1,
	\cAtk, 1,
	\cRel, -1,
	\rlpf, 1700,
	\rlpfq, 1,
	\rhpf, 180,
	\rhpfq, 1,
	\rout, ~rbus,
	\rsend, -10,
	\dur, Pseq([1], 1)
).play;
)

( // particle cloud
Pbindef(\digicloud,
	\instrument, \fm,
	\amp, Pexprand(0.1, 0.3)*Pgeom(3, 0.99, inf),
	\freq, Pexprand(90, 96).midicps,
	\detune, Pexprand(0.01, 0.5),
	\phase, Pexprand(0.001pi,2pi),
	\atk, Pexprand(0.02, 0.03),
	\sus, 0.01,
	\rel, Pexprand(0.01, 0.03),
	\index, Prand([1, 5], inf),
	\iScale, Prand([1.7, 3.0], inf),
	\mRatio, Pexprand(1.0,3.3),
	\cRatio, 2,
	\cAtk, 3,
	\cRel, -7,
	\rlpf, 18000,
	\rlpfq, 1,
	\rhpf, 7000,
	\rhpfq, 1,
	\pan, Pxrand([-0.618, -0.31, 0, 0.31, 0.618,], inf),
	\out, 0,
	\rout, ~rbus,
	\rsend, -00,
	\dur, Pseq([1/64], 64*4)
).play;
)

//---------------------------------------------
// cloud
//---------------------------------------------

(
Pbindef(\cloud_long,
	\instrument, \cloud,//FREQ SHOULD NOT BE BELOW 20Hz
	\amp, 0.1,
	\freq, [30, 72].midicps,
	\rq, 2,
	\atk, 0.7,
	\sus, 0,
	\rel, 4 ,
	\cAtk, -1,
	\cRel, -4,
	\out, 0,
	\rout, ~rbus,
	\rsend, 0,
	\dur, Pseq([1], 1);
).play;
)

(
Pbindef(\cloud_low,
	\instrument, \cloud,//FREQ SHOULD NOT BE BELOW 20Hz
	\amp, 1,
	\freq, [18, 30, 32, 42, 44, 72].midicps,
	\rq, 0.5,
	\atk, 0.9,
	\sus, 0,
	\rel, 3 ,
	\cAtk, 1,
	\cRel, -5,
	\out, 0,
	\rout, ~rbus,
	\rsend, 0,
	\dur, Pseq([1], 1);
).play;
)

(
Pbindef(\cloud_high,
	\instrument, \cloud,//FREQ SHOULD NOT BE BELOW 20Hz
	\amp, 0.1,
	\freq, [120, 122, 130, 134, 144].midicps,
	\rq, 0.3,
	\atk, 1.3,
	\rel, 5,
	\cAtk, -1,
	\cRel, -3,
	\out, 0,
	\rout, ~rbus,
	\rsend, -0,
	\rsend, 0,
	\dur, Pseq([1], 1)
).play;
)


(
Pbindef(\cloud_particle,
	\instrument, \cloud,//FREQ SHOULD NOT BE BELOW 20Hz
	\amp, Pexprand(0.1, 0.3)*Pgeom(5, 0.97, inf),
	\freq, Pexprand(3000, 3900)*3,
	\rq, 0.3,
	\atk, Pexprand(0.01, 0.03),
	\sus, 0.0,
	\rel, Pexprand(0.01, 0.03),
	\cAtk, -1,
	\cRel, 1,
	\out, 0,
	\rout, ~rbus,
	\rsend, 0,
	\pan, Prand([-1.0,-0.618, 0.618, 1.0], inf),
	\dur, Pseq([1/64], 64*4)
).play;
)

//---------------------------------------------
// Testing
//---------------------------------------------

Pbindef(\static).play;
Pbindef(\glow).play;
Pbindef(\lowbuzz).play;
Pbindef(\digicloud).play;
Pbindef(\cloud_particle).play;
Pbindef(\cloud_high).play;
Pbindef(\cloud_low).play;


( // particle effect
Ppar([
	Pbindef(\lowbuzz), Pbindef(\digicloud),
	Pbindef(\cloud_low), Pbindef(\cloud_particle), Pbindef(\cloud_high)]).play;
)
