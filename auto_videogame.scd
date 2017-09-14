//////////////////////////////////////////////////////
//                                                  //
//  CPSC 431 Fall 2016                              //
//  Very Official (Take-Home) Midterm(R) (Project)  //
//  ... Automatic Generation of Videogame Music     //
//                                                  //
//  Prawat (Pong) Trairatvorakul                    //
//                                                  //
//  Submitted October 23, 2016                      //
//                                                  //
//////////////////////////////////////////////////////

// Evaluate all blocks then score can be generated and played on GUI
// Retrograde for "track 2"

// Portions of code built on top of Group Dynamite Home on the Range

//-----GLOBAL VARS-----
(
~beat = 0.25;
~nBeats = 4;
~key = 0;
~scale = \minor;
~sDeg = Scale.at(~scale).degrees;
)

(
//-----INSTRUMENTS-----
// Instrument definitions at bottom.


//-----DEFINE HARMONIC STRUCTURE-----
t  = [0, 9];     // Roots for tonic function chords
f  = [0, 12];    // Final note (only tonic chords)
p  = [5, 2];     // Roots for predominant function chords
d  = [7, 11];    // Roots for dominant function chords
x  = [8, 1];     // Wildcard 1 (because why not)
v  = [3, 10];    // Wildcard 2 (because why not)

//-----CHORD TONE BUILDER-----
// Takes tonic of chord. Gives 3rd & 5th
~chord = {
	arg tonic; // Tonic of chord
	var size = ~sDeg.size;
	var index = ~sDeg.indexOf(tonic); // Determines if tonic in scale
	if (index.isNil)
	{
		// Not in scale. Give major triad
		[tonic, tonic + 4, tonic + 7];
	}
	{
		// In scale. Give diatonic triad
		[tonic, ~sDeg[(index + 2) % size], ~sDeg[(index + 4) % size]];
	};
};

//-----GENERATE HARMONIC STRUCTURE-----
// Form bass line by picking chords given the functions
~makebass = {
	arg funcs;
	// Make bass notes
	// Picks a chord, given harmonic functions
	var bassNotes = {
		arg functions;
		var notes = Array.new(functions.size);
		functions.do({
			arg item, i;
			// Items further in list have lower probability
			var probs = Array.new(item.size);
			item.do({
				arg val, j;
				var prob = 1 / (j + 0.1);
				probs.add(prob);
			});
			probs = probs.normalizeSum;
			// Add chosen note
			notes.insert(i, item.wchoose(probs));
		});
		notes;
	};

	// Make durations. Each bass note lasts whole measure
	var bassDurs = {
		arg functions;
		var durs = Array.new(functions.size);
		durs = Array.fill(functions.size, ~beat * ~nBeats);
	};

	// Return bass notes and durations
	[bassNotes.value(funcs), bassDurs.value(funcs)];
};

//-----FORM MELODIC SKELETON-----
// Given the bass note for each measure, chooses a note for the
// downbeat of each measure from the triad with root on given note
~makeskeleton  = {
	arg bassline; // Takes bassline
	var bassNotes = bassline[0]; // Parses for bass notes
	var bassDurs = bassline[1];  // Parses for bass line durations

	// Declare new array for skeleton
	var skNotes = Array.new(bassNotes.size);
	var skDurs = Array.new(bassDurs.size);

	// Pick notes given chords
	bassNotes.do({
		arg item, i;
		var newNote = ~chord.value(item).choose;

		// Test out different octaves
		var octave;
		var oct = [0, 12];
		var probs = Array.fill(2, 0.5);
		if (i > 0) {
			var prev = skNotes[i - 1];
			// Closer to previous note => more probable
			oct.do({
				arg oc, j;
				var dist = abs((newNote + oc) - prev);
				if (dist == 0) {dist = dist + 1};
				probs.put(j, 1/dist);
			});
		};
		octave = oct.wchoose(probs);

		// Store note and durs
		skNotes.add(newNote + octave);
		skDurs.add(bassDurs[i]);
	});

	// Return skeleton notes and durations
	[skNotes, skDurs];
};

//-----APPROACH NOTES-----
// Given skeleton, flesh them out by approach notes
~approach = {
	arg skeleton;
	var skNotes = skeleton[0];
	var skDurs = skeleton[1];
	i = 0;
	while({skNotes[i + 1] != nil}, // Traverse through all notes except last
		{
			var dur = skDurs[i];      // duration of current note
			var note = skNotes[i];    // current note
			if (dur >= ~beat &&       // to prevent overkill
				0.75.coin,            // Can also not add approach note
				{
					var newNote, newDur, len;
					var up1, down1;

					// Next note and its normalized val (to find in scale)
					var nextNote = skNotes[i + 1];
					var nextNoteQuant = nextNote % Scale.at(~scale).pitchesPerOctave;

					// Difference between next note and current note
					var diff = nextNote - note;

					// Possible octaves. -1, 0, +1.
					var oct = [-12, 0, 12];
					var octave;

					var dist = 48; // Arbitrarily large distance
					var index = ~sDeg.indexOf(nextNoteQuant); // Find in scale
					if (index.isNil || 0.25.coin)
					{
						// Not found. Chromatic above/below.
						up1 = nextNote + 1;
						down1 = nextNote -1;
					} {
						// Found. Diatonic above/below
						var size = ~sDeg.size;
						up1 = ~sDeg[(index + 1) % size];
						down1 = ~sDeg[(index - 1) % size];
					};
					if (note == \rest, {diff = 0});

					// Determine new duration
					len = dur / ~beat;
					newDur = round((len - 1).linrand) * ~beat;
					skDurs = skDurs.put(i, dur - newDur);  // make room
					skDurs = skDurs.insert(i + 1, newDur);  //   ...for approach note

					// Determine newNote
					newNote = case
					{diff <  -1} {up1}
					{diff == -1} {down1}
					{diff ==  0} {[up1, down1].choose}
					{diff ==  1} {up1}
					{diff >   1} {down1};

					// newNote is closest one for pitch class
					oct.do({
						arg oc, j;
						var dist1 = abs((newNote + oc) - nextNote);
						if (dist1 < dist) {
							dist = dist1;
							octave = oc;
						};
					});
					newNote = newNote + octave;

					// Store and skip newly added note
					skNotes = skNotes.insert(i + 1, newNote);
					i = i + 1;
				}
			);
			i = i + 1; // Iterate
		}
	);
	// Return
	[skNotes, skDurs];
};

//-----DRUM PART----
// Generates the drum part, given bassline and skeleton
~makedrum = {
	arg bassline, skeleton, state; // state: 0=>intro,1=>body,2=>outro
	var bdurs = bassline[1]; // parse bass durations
	var len = bdurs.size;
	var dnotes, ddurs;

	// Unit for each measure
	var noteUnit = [];
	var durUnit = [];

	var bar = ~beat * ~nBeats; // length of measure
	var len2 = floor(~nBeats / 2) * ~beat; // length of second note in measure
	case
	{state == 0} {
		// Intro: clap on upbeats
		durUnit = [Rest(bar - len2), len2];
		noteUnit = [\clap, \clap];
	}
	{state == 1} {
		// Body: Steady kick clap
		durUnit = [bar - len2, len2];
		noteUnit = [\kick, \clap];
	}
	{state == 2} {
		// Outro (alternative 1): constant kicks
		var times = floor(~nBeats / 2);
		if (~nBeats%2 == 1) {
			durUnit = [~beat];
			noteUnit = [\kick];
		};
		durUnit = durUnit ++ Array.fill(times, ~beat * 2);
		noteUnit = noteUnit ++ Array.fill(times, \kick);
		len = len - 1;
	};
	dnotes = Array.fill(len,noteUnit).flatten;
	ddurs = Array.fill(len,durUnit).flatten;
	if (state == 2) {
		if (0.5.coin) {
			dnotes = dnotes.add(\kick);
			ddurs = ddurs.add(bar);
		} {
			// Outro (alternative 2): Kick in sync with skeleton
			dnotes = []; ddurs = []; // Clear previous work
			ddurs = skeleton[1];     // Set durs to equal durs of skeleton
			dnotes = Array.fill(skeleton[1].size, \kick); // Fill with kicks
		};
	};

	// Return drum notes and durations
	[dnotes, ddurs];
};

//-----STRUCTURE OF PIECE-----
// The heart of the whole thing
~makestruct = {
	arg nSects, repeats; // Number of sections and repeats of body
	var bnotes, sknotes, bdurs, skdurs, dnotes, ddurs;

	// Make arrays of bass, skeleton, and drum, given harmonic functions
	var makeArr = {
		arg functions, state;
		// Make bassline
		var bass = ~makebass.value(functions);
		// Make skeleton
		var skeleton = ~makeskeleton.value(bass);
		var drum;
		if (state == 2) {
			// For outro, make last note tonic
			var lastNote = skeleton[0][skeleton[0].size - 1];
			if (lastNote%12 != 0) {
				skeleton[0][skeleton[0].size - 1] = [0,12].choose;
			};
		};
		// Add approach notes to skeleton
		3.do({
			skeleton = ~approach.value(skeleton);
		});
		// Make drum part
		drum = ~makedrum.value(bass, skeleton, state);
		// Return values
		[bass, skeleton, drum];
	};

	// Make intro and outro
	var intro = makeArr.value([d,d,d,d], 0);
	var outro = makeArr.value([d,d,f,f], 2);

	// Make body
	var body = {
		var bNotes = Array.new(nSects);
		var bDurs = Array.new(nSects);
		var skNotes = Array.new(nSects);
		var skDurs = Array.new(nSects);
		var dNotes = Array.new(nSects);
		var dDurs = Array.new(nSects);
		// Possible harmonic function patterns
		var bPatterns = [
			[t,t,p,p,t,p,d,t],
			[t,p,d,t,t,p,d,t],
			[t,t,p,p,d,d,t,t],
			[t,d,t,d,p,p,t,t],
			[t,x,v,d,x,v,d,t] // wild one
		];
		// Make a section
		nSects.do({
			arg i;
			var chosen = bPatterns.choose;                     // choose pattern
			var bPattern = ~makebass.value(chosen);            // make bass
			var skPattern = ~makeskeleton.value(bPattern);     // make skeleton
			var dPattern = ~makedrum.value(bPattern, skPattern, 1); // make drums

			// Add approach notes
			3.do({
				skPattern = ~approach.value(skPattern);
			});

			// Store everything
			bNotes.add(bPattern[0]);
			bDurs.add(bPattern[1]);
			skNotes.add(skPattern[0]);
			skDurs.add(skPattern[1]);
			dNotes.add(dPattern[0]);
			dDurs.add(dPattern[1]);
		});
		// Return body section
		[[bNotes, bDurs], [skNotes, skDurs], [dNotes, dDurs]];
	};
	var bd = body.value;

	// Store everything in the most non-elegant way possible
	bnotes = (intro[0][0] ++ (bd[0][0].dup(repeats)).flatten ++ outro[0][0]).flatten;
	bdurs = (intro[0][1] ++ (bd[0][1].dup(repeats)).flatten ++ outro[0][1]).flatten;
	sknotes = (intro[1][0] ++ (bd[1][0].dup(repeats)).flatten ++ outro[1][0]).flatten;
	skdurs = (intro[1][1] ++ (bd[1][1].dup(repeats)).flatten ++ outro[1][1]).flatten;
	dnotes = (intro[2][0] ++ (bd[2][0].dup(repeats)).flatten ++ outro[2][0]).flatten;
	ddurs = (intro[2][1] ++ (bd[2][1].dup(repeats)).flatten ++ outro[2][1]).flatten;

	// Return values
	[bnotes, bdurs, sknotes, skdurs, dnotes, ddurs];
};

//-----DERIVE LINE 2 BASED ON EXISTING SCORE-----
// Same rhythm. Offers some kind of harmony
~derive = {
	arg score;
	var bass = [score[0], score[1]];     // parse bassline
	var skeleton = [score[2], score[3]]; // parse skeleton
	var track2Notes = Array.new(skeleton[0].size); // new line
	var track2Durs  = skeleton[1]; // same durations as track1
	var scaleSize = Scale.at(~scale).pitchesPerOctave;

	var loc = 0.0; // location in measure
	var bassIndex = 0; // index in bassline
	skeleton[0].do({
		arg note1, i;
		var dur = skeleton[1][i] / ~beat;
		var bassNote = bass[0][bassIndex]; // Get bass note
		var chordNotes = ~chord.value(bassNote); // Build chord tones
		var note2Arr = [  // Possible intervals:
			note1 - 4,    // maj 3
			note1 - 3,    // min 3
			note1 - 9,    // maj 6
			note1 - 8,    // min 6
			note1 - 7,    // per 5
			note1 - 5     // per 4
		];
		var probs = Array.fill(note2Arr.size, 1);
		chordNotes = chordNotes % scaleSize; // scale chord tones to be indexable
		// Reassign weights
		note2Arr.do({
			arg note2, j;

			var inChord;
			var index = ~sDeg.indexOf(note2 % scaleSize);
			if (index.isNil) {
				// Note not in scale => 0 probability
				probs.put(j, 0);
			};

			// Test if note is in chord
			inChord = chordNotes.indexOf(note2 %scaleSize);
			if (inChord.isNil) {} {
				// Note in chord => double relative probability
				probs.put(j, probs[j] * 2);
			};
		});

		// Ensure that last note forms tonic chord
		if (i == (skeleton[0].size - 1)) {
			probs[0] = 0;
			probs[1] = 0;
			probs[4] = 0;
		};

		// Normalize probability array
		probs = probs.normalizeSum;

		// Choose note and store
		track2Notes.add(note2Arr.wchoose(probs));

		// Advance bass note
		loc = loc + dur;
		if (loc > ~nBeats) {
			loc = loc - ~nBeats;
			bassIndex = bassIndex + 1;
		};

	});

	"deriving track 2...".postln;

	// return values, appending track 2 noes and durs
	score ++ [track2Notes] ++ [track2Durs];
};

//-----RETROGRADE-----
// Create a retrograde of score
~retrograde = {
	arg score;
	var new = Array.new(score.size);
	score.do({
		arg item, i;
		// Create retrograde for the parts, except for drum line
		if (i != 4 && i != 5) {
			new.add(item.reverse);
			new[i].add(new[i][0]); // End on tonic
		} {
			// Just copy drum line over
			new.add(item);
		};
	});
	"retrograding...".postln;

	// return value
	new;
};

//-----MAKE SCORE-----
~makescore = {
	arg nSects, repeats;
	// Print out super interesting info for some light reading
	var line1 = "Generating Score...";
	var line2 = "Time Signature: " ++ ~nBeats ++ "/" ++ round(1/~beat) ++ "\t ctranspose: " ++ ~key;
	var line3 = "# Body Sections: " ++ nSects ++ "\t # Body Repeats: " ++ repeats;
	"---------------------".postln;
	line1.postln;
	line2.postln;
	line3.postln;

	// Scale
	~scale = [\ionian, \aeolian].choose; // more conservative choices
	//~scale = [\ionian, \dorian, \phrygian, \lydian, \mixolydian, \aeolian, \locrian, \bartok].choose; // out there.
	("Scale: " ++ ~scale).postln;
	~sDeg = Scale.at(~scale).degrees;

	// Return the score
	~makestruct.value(nSects, repeats);
};

~playscore = {
	arg score, amp1, amp2;

	// Leave selection of instruments to fate
	var sounds = [
		[\acid, \mario],
		[\string, \string],
		[\acid, \rhodey_sc]
	];
	var sound = sounds.choose;

	// Load score
	var notes = score;

	// Let the world know
	"Playing...".postln;

	// Load score
	Pbind( // Bass Line
		\instrument, sound[0],
		\dur, Pseq(notes[1]),
		\octave, 3,
		\ctranspose, ~key,
		\note, Pseq(notes[0]),
		\amp, 0.1
	).play;
	Pbind( // Line 1
		\instrument, sound[1],
		\dur, Pseq(notes[3]),
		\octave, 5,
		\ctranspose, ~key,
		\note, Pseq(notes[2]),
		\amp, amp1
	).play;
	Pbind( // Drum Line
		\amp, 0.15,
		\dur, Pseq(notes[5]),
		\instrument, Pseq(notes[4])
	).play;
	// If line2 exists
	if (score.size == 8) {
		Pbind( // Line 2
			\instrument, sound[1],
			\dur, Pseq(notes[7]),
			\octave, 5,
			\ctranspose, ~key,
			\note, Pseq(notes[6]),
			\amp, amp2
		).play;
	};
};
)

//----- GUI FUN! -----
(
// Initialize non-melody amplitudes to 0
var nSects = 4;
var repeats = 2;

var b1, b2, b3, b4, b5, b6, b7, b8, n1, n2, n3, n4, t1, s1,t2;
var time = [2, 4, 8];
var beatsArr = [2,3,4,5,6,7,8,9];
w = GUI.window.new( "Videogame Music Maker", Rect( 128, 64, 400, 480 ));

// Generate score button
b1 = Button(w, Rect(20, 20, 360, 40))
.states_([["Generate Score", Color.black]])
.action_({
	~score = ~makescore.value(nSects,repeats);
});
// Derive line 2 from score
b3 = Button(w, Rect(20, 70, 170, 40))
.states_([["Derive Line 2", Color.black]])
.action_({
	~score1 = ~derive.value(~score);
});
// Create retrograde of the score1
b6 = Button(w, Rect(210, 70, 170, 40))
.states_([["Retrograde", Color.black]])
.action_({
	~score2 = ~retrograde.value(~score1);
});

// Play melody, bass, drums
b2 = Button(w, Rect(20, 280, 170, 40))
.states_([["Play Line 1!", Color.black]])
.action_({
	~playscore.value(~score, 0.2, 0);
});
// Play line2, bass, drums!
b4 = Button(w, Rect(210, 280, 170, 40))
.states_([["Play Line 2!", Color.black]])
.action_({
	~playscore.value(~score1, 0, 0.2);
});
// Play all parts (super fun. 10/10 recommend)
b5 = Button(w, Rect(20, 330, 360, 60))
.states_([["Play Both!", Color.black]])
.action_({
	~playscore.value(~score1, 0.2, 0.2);
});
// Play the retrograde version
b7 = Button(w, Rect(20, 400, 360, 60))
.states_([["Play Retrograde!", Color.black]])
.action_({
	~playscore.value(~score2, 0.2, 0.2);
});

// All of the above
b6 = Button(w, Rect(20, 120, 360, 60))
.states_([["All of the above", Color.black, Color.new255(127, 255, 212)]])
.action_({
	~score  = ~makescore.value(nSects,repeats);
	~score1 = ~derive.value(~score);
	~score2 = ~retrograde.value(~score1);
	// Lights up play button
	b5.states_([ ["Play Both!", Color.black, Color.new255(127, 255, 212)] ]);
});

// Number of body sections
n1 = EZNumber(
	w,
	Rect(20, 190, 170, 20),
	label:" # sections ",
	controlSpec:ControlSpec(0,20,\lin,1,4),
	numberWidth:50,
	labelWidth:120
);
n1.action_({
	|val| nSects = val.value;
});

// Number of body repeats
n2 = EZNumber(
	w,
	Rect(20, 220, 170, 20),
	label:" # repeats ",
	controlSpec:ControlSpec(0,20,\lin,1,2),
	numberWidth:50,
	labelWidth:120
);
n2.action_({
	|val| repeats = val.value;
});

// Key slider
t1 = StaticText(w, Rect(20, 250, 70, 20));
t1.string = "Key " ++ ~key;
s1 = Slider(w, Rect(90, 250, 200, 20))
.step_(1/12)
.action_({
	~key = round(s1.value * 11);
	t1.string = "Key " ++ ~key;
});
s1.value_(~key/11);

t2 = StaticText(w, Rect(200, 180, 100, 60));
t2.string = "Time\nSignature";

// Number of beats per measure
n3 = PopUpMenu(w, Rect(310, 190, 50, 20))
.items_(beatsArr)
.action_({
	~nBeats = beatsArr.at(n3.value);
});
n3.valueAction_(2);

// Length of each beat
n4 = PopUpMenu(w, Rect(310, 220, 50, 20))
.items_(time)
.action_({
	~beat = 1 / (time.at(n4.value));
});
n4.valueAction_(1);

w.front;
)


//-----INSTRUMENTS-----

(
// Drums from http://sccode.org/1-523
//      electro drum kit by snappizz
SynthDef(\kick, {
    |out = 0, pan = 0, amp = 0.3|
    var body, bodyFreq, bodyAmp;
    var pop, popFreq, popAmp;
    var click, clickAmp;
    var snd;

    // body starts midrange, quickly drops down to low freqs, and trails off
    bodyFreq = EnvGen.ar(Env([261, 120, 51], [0.035, 0.08], curve: \exp));
    bodyAmp = EnvGen.ar(Env.linen(0.005, 0.1, 0.3), doneAction: 2);
    body = SinOsc.ar(bodyFreq) * bodyAmp;
    // pop sweeps over the midrange
    popFreq = XLine.kr(750, 261, 0.02);
    popAmp = EnvGen.ar(Env.linen(0.001, 0.02, 0.001)) * 0.15;
    pop = SinOsc.ar(popFreq) * popAmp;
    // click is spectrally rich, covering the high-freq range
    // you can use Formant, FM, noise, whatever
    clickAmp = EnvGen.ar(Env.perc(0.001, 0.01)) * 0.15;
    click = LPF.ar(Formant.ar(910, 4760, 2110), 3140) * clickAmp;

    snd = body + pop + click;
    snd = snd.tanh;

    Out.ar(out, Pan2.ar(snd, pan, amp));
}).add;

SynthDef(\snare, {
    |out = 0, pan = 0, amp = 0.3|
    var pop, popAmp, popFreq;
    var noise, noiseAmp;
    var snd;

    // pop makes a click coming from very high frequencies
    // slowing down a little and stopping in mid-to-low
    popFreq = EnvGen.ar(Env([3261, 410, 160], [0.005, 0.01], curve: \exp));
    popAmp = EnvGen.ar(Env.perc(0.001, 0.11)) * 0.7;
    pop = SinOsc.ar(popFreq) * popAmp;
    // bandpass-filtered white noise
    noiseAmp = EnvGen.ar(Env.perc(0.001, 0.15), doneAction: 2);
    noise = BPF.ar(WhiteNoise.ar, 810, 1.6) * noiseAmp;

    snd = (pop + noise) * 1.3;

    Out.ar(out, Pan2.ar(snd, pan, amp));
}).add;

SynthDef(\hihat, {
    |out = 0, pan = 0, amp = 0.3|
    var click, clickAmp;
    var noise, noiseAmp;
    var snd;

    // noise -> resonance -> expodec envelope
    noiseAmp = EnvGen.ar(Env.perc(0.001, 0.3, curve: -8), doneAction: 2);
    noise = Mix(BPF.ar(ClipNoise.ar, [4010, 4151], [0.15, 0.56], [1.0, 0.6])) * 0.7 * noiseAmp;

    snd = noise;

    Out.ar(out, Pan2.ar(snd, pan, amp));
}).add;

// adapted from a post by Neil Cosgrove (other three are original)
SynthDef(\clap, {
    |out = 0, amp = 0.5, pan = 0, dur = 1|
    var env1, env2, snd, noise1, noise2;

    // noise 1 - 4 short repeats
    env1 = EnvGen.ar(
        Env.new(
            [0, 1, 0, 0.9, 0, 0.7, 0, 0.5, 0],
            [0.001, 0.009, 0, 0.008, 0, 0.01, 0, 0.03],
            [0, -3, 0, -3, 0, -3, 0, -4]
        )
    );

    noise1 = WhiteNoise.ar(env1);
    noise1 = HPF.ar(noise1, 600);
    noise1 = LPF.ar(noise1, XLine.kr(7200, 4000, 0.03));
    noise1 = BPF.ar(noise1, 1620, 3);

    // noise 2 - 1 longer single
    env2 = EnvGen.ar(Env.new([0, 1, 0], [0.02, 0.18], [0, -4]), doneAction:2);

    noise2 = WhiteNoise.ar(env2);
    noise2 = HPF.ar(noise2, 1000);
    noise2 = LPF.ar(noise2, 7600);
    noise2 = BPF.ar(noise2, 1230, 0.7, 0.7);

    snd = noise1 + noise2;
    snd = snd * 2;
    snd = snd.softclip;

    Out.ar(out, Pan2.ar(snd,pan,amp));
}).add;

// Bass
//     from http://sccode.org/1-4VI
SynthDef(\wobble, { arg out=0, amp=0.1, gate=1, pan=0, spread=0.8, freq=200, doneAction=2;
	var sig, sig1, sig2, sig3;
	sig1 = LFSaw.ar(freq * 1 + (0.04 * [1,-1]));
	sig2 = LFSaw.ar(freq * 0.99 );
	sig3 = LFSaw.ar(freq * 1 );
	sig = sig1 + sig2 + sig3;
	sig = (sig*50).tanh;
	sig = sig * EnvGen.ar(\adsr.kr(Env.adsr(0.01,0.1,0.8,0.1)),gate,doneAction:doneAction);
	sig = Splay.ar(sig, spread, amp, pan);
	Out.ar(out, sig);
}).add;

// Bass
//   from http://sccode.org/1-52Z
SynthDef(\acid, {
    var snd;
    snd = Pulse.ar(\freq.kr(440), 0.45);
    snd = RLPF.ar(snd, EnvGen.ar(Env([\ffreq.kr(3000), 1000, 100], [0.08, 0.4], \exp)), 0.21);
    snd = snd + (snd + 0.2 * 3).atan * 0.5;
    snd = snd * Env.adsr(0.001, 0.01, 0.7, 0.05).kr(2, \gate.kr(1));
    snd = Pan2.ar(snd, \pan.kr(0), \amp.kr(0.1));
    Out.ar(\out.kr, snd);
}).add;

// Kalimba
//     from http://sccode.org/1-51l
SynthDef(\kalimba, {
    |out = 0, freq = 440, amp = 0.1, mix = 0.1|
    var snd;
    // Basic tone is a SinOsc
    snd = SinOsc.ar(freq) * EnvGen.ar(Env.perc(0.005, Rand(2.5, 3.5), 1, -8), doneAction: 2);
    // The "clicking" sounds are modeled with a bank of resonators excited by enveloped pink noise
    snd = (snd * (1 - mix)) + (DynKlank.ar(`[
        // the resonant frequencies are randomized a little to add variation
        // there are two high resonant freqs and one quiet "bass" freq to give it some depth
        [240*ExpRand(0.9, 1.1), 2020*ExpRand(0.9, 1.1), 3151*ExpRand(0.9, 1.1)],
        [-7, 0, 3].dbamp,
        [0.8, 0.05, 0.07]
    ], PinkNoise.ar * EnvGen.ar(Env.perc(0.001, 0.01))) * mix);
    Out.ar(out, Pan2.ar(snd, 0, amp));
}).add;

// String synth from:
// "http://new-supercollider-mailing-lists-forums-use-these.2681727
//   .n2.nabble.com/guitar-synthdef-td7598199.html"
SynthDef(\string, {arg out=0, freq=440, pan=0, sustain=0.5, amp=0.3;
	var pluck, period, string;
	pluck = PinkNoise.ar(Decay.kr(Impulse.kr(0.005), 0.05));
	period = freq.reciprocal;
	string = CombL.ar(pluck, period, period, sustain*6);
	string = LeakDC.ar(LPF.ar(Pan2.ar(string, pan), 12000)) * amp;
	DetectSilence.ar(string, doneAction:2);
	Out.ar(out, string)
}).add;

// Mario
//     from http://sccode.org/1-11N
SynthDef(\mario, { |out, amp=0.3, freq=440, dur=0.1|
	var snd;
	snd = VarSaw.ar(freq)!2;
	snd = snd * EnvGen.ar(Env.linen(0.001, dur/2, 0.03), doneAction:2);
	OffsetOut.ar(out, snd*amp);
}).add;

// Rhodes Synth
//     from http://sccode.org/1-522
SynthDef(\rhodey_sc, {
    |
    // standard meanings
    out = 0, freq = 440, gate = 1, pan = 0, amp = 0.1,
    // all of these range from 0 to 1
    vel = 0.8, modIndex = 0.2, mix = 0.2, lfoSpeed = 0.4, lfoDepth = 0.1
    |
    var env1, env2, env3, env4;
    var osc1, osc2, osc3, osc4, snd;

    lfoSpeed = lfoSpeed * 12;

    freq = freq * 2;

    env1 = EnvGen.ar(Env.adsr(0.001, 1.25, 0.0, 0.04, curve: \lin));
    env2 = EnvGen.ar(Env.adsr(0.001, 1.00, 0.0, 0.04, curve: \lin));
    env3 = EnvGen.ar(Env.adsr(0.001, 1.50, 0.0, 0.04, curve: \lin));
    env4 = EnvGen.ar(Env.adsr(0.001, 1.50, 0.0, 0.04, curve: \lin));

    osc4 = SinOsc.ar(freq * 0.5) * 2pi * 2 * 0.535887 * modIndex * env4 * vel;
    osc3 = SinOsc.ar(freq, osc4) * env3 * vel;
    osc2 = SinOsc.ar(freq * 15) * 2pi * 0.108819 * env2 * vel;
    osc1 = SinOsc.ar(freq, osc2) * env1 * vel;
    snd = Mix((osc3 * (1 - mix)) + (osc1 * mix));
    snd = snd * (SinOsc.ar(lfoSpeed) * lfoDepth + 1);

    // using the doneAction: 2 on the other envs can create clicks (bc of the linear curve maybe?)
    snd = snd * EnvGen.ar(Env.asr(0, 1, 0.1), gate, doneAction: 2);
    snd = Pan2.ar(snd, pan, amp);

    Out.ar(out, snd);
}).add;
)