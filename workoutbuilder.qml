import QtQuick 2.9
import QtQuick.Controls 2.2
import MuseScore 3.0
import QtQuick.Window 2.2
import QtQuick.Dialogs 1.2
import QtQuick.Controls.Styles 1.4
import QtQuick.Layouts 1.1
import FileIO 3.0

import "zparkingb/notehelper.js" as NoteHelper

MuseScore {
	menuPath : "Plugins.Workout builder"
	description : "Description goes here"
	version : "1.0"

	pluginType : "dialog"
	requiresScore : true
	width : 1100
	height : 700

	id : mainWindow
	onRun : {

		console.log("steps: " + patterns.length);
		console.log("degrees: " + _degrees.length);
		console.log("steproots: " + steproots.length);
		console.log("roots: " + _roots.length);
		console.log("ddroots: " + _ddRoots.length);

	}

	property int _Cpitch : 48

	property int _max_patterns : 8
	property int _max_steps : 12
	property int _max_roots : 12
	property var _degrees : ['1', 'b2', '2', 'm3', 'M3', '4', 'b5', '5', 'm6', 'M6', 'm7', 'M7',
		'(8)', 'b9', '9', '#9', 'b11', '11', '#11', '(12)', 'b13', '13', '#13', '(14)']

	property var _loops : [{
			"value" : 0,
			"label" : "No loop"
		}, {
			"value" : 1,
			"label" : "At 2nd step"
		}, {
			"value" : 2,
			"label" : "At 3rd step"
		}, {
			"value" : -1,
			"label" : "Guided"
		},
	]

	property var _chords : [{
			"root" : 'C',
			"major" : true,
			"minor" : false
		}, {
			"root" : 'Db/C#',
			"major" : false,
			"minor" : false
		}, {
			"root" : 'D',
			"major" : true,
			"minor" : false
		}, {
			"root" : 'Eb/D#',
			"major" : false,
			"minor" : false
		}, {
			"root" : 'E',
			"major" : true,
			"minor" : false
		}, {
			"root" : 'F',
			"major" : false,
			"minor" : false
		}, {
			"root" : 'F#/Gb',
			"major" : true,
			"minor" : false
		}, {
			"root" : 'G',
			"major" : true,
			"minor" : false
		}, {
			"root" : 'Ab/G#',
			"major" : false,
			"minor" : false
		}, {
			"root" : 'A',
			"major" : true,
			"minor" : false
		}, {
			"root" : 'Bb/A#',
			"major" : false,
			"minor" : false
		}, {
			"root" : 'B',
			"major" : false,
			"minor" : false
		}
	]

	property var _roots : { {
			var dd = [];
			for (var i = 0; i < _chords.length; i++) {
				dd.push(_chords[i].root);
			}
			return dd;
		}
	}

	property var _ddRoots : { {
			var dd = [''];
			dd = dd.concat(_roots);
			return dd;
		}
	}

	property var _ddNotes : { {
			var dd = [''];
			dd = dd.concat(_degrees);
			return dd;
		}
	}

	property var patterns : { {

			var sn = [];

			for (var i = 0; i < _max_patterns; i++) {
				for (var j = 0; j < _max_steps; j++) {
					var _sn = {
						"pattern" : i,
						"step" : j,
						"note" : '',
					};
					sn.push(_sn);
				}
			}
			return sn;
		}
	}

	property var steproots : { {
			var sr = [];
			for (var j = 0; j < _max_roots; j++) {
				sr.push('');
			}
			return sr;
		}
	}

	function printWorkout() {

		var loopAt = -1;

		var patts = [];

		// Les patterns
		for (var i = 0; i < _max_patterns; i++) {
			var p = [];
			for (var j = 0; j < _max_steps; j++) {
				var sn = patterns[i * _max_steps + j];
				//console.log("S "+i+"/"+j+": "+sn.note);
				if (sn.note !== '') {
					var d = _degrees.indexOf(sn.note);
					if (d > -1)
						p.push(d);
				} else
					break;
			}

			if (p.length > 0) {
				console.log("Pattern " + i + ": " + p);
				patts.push(p);
			} else
				break;
		}

		// Les roots
		var roots = [];
		for (var i = 0; i < _max_roots; i++) {
			var txt = steproots[i];
			console.log("Next Root: " + txt);
			if (txt === '' || txt === undefined)
				continue;
			var r = _roots.indexOf(txt);
			console.log("-- => " + r);
			if (r > -1)
				roots.push(r)
		}

		// Les notes
		var pages = [];
		if (patts.length == 0 || roots.length == 0)
			// TODO Message d'erreur
			return;

		if (chkByPattern.checked) {
			// We sort by patterns. By pattern, repeat over each root

			for (var p = 0; p < patts.length; p++) {
				var basesteps = patts[p];
				var mode = (basesteps.indexOf(3) > -1) ? "minor" : "major"; // if we have the "m3" the we are in minor mode.
				var page = (chkPageBreak.checked) ? p : 0;
				if (pages.length === page)
					pages[page] = [];

				for (var r = 0; r < roots.length; r++) {

					var root = roots[r];
					var notes = [];

					if (!chkInvert.checked || ((r % 2) == 0)) {
						console.log("-- => normal");
						for (var j = 0; j < basesteps.length; j++) {
							notes.push(root + basesteps[j]);
						}
					} else {
						console.log("-- => reverse");
						for (var j = basesteps.length - 1; j >= 0; j--) {
							notes.push(root + basesteps[j]);
						}
					}

					pages[page].push({
						"root" : root,
						"mode" : mode,
						"notes" : notes
					});

				}

			}
		} else {
			// We sort by roots. By root, repeat every pattern
			for (var r = 0; r < roots.length; r++) {
				var page = (chkPageBreak.checked) ? r : 0;
				if (pages.length === page)
					pages[page] = [];

				var root = roots[r];

				for (var p = 0; p < patts.length; p++) {
					var notes = [];
					var basesteps = patts[p];
					var mode = (basesteps.indexOf(3) > -1) ? "minor" : "major"; // if we have the "m3" the we are in minor mode.

					var debug = 0;
					var from = 0; // delta in index of the pattern for the regular loopAt mode
					var shift = 0; // shift in pitch for the guided loopAt mode


					console.log("Initial pattern");
					while (debug < 50) {
						debug++;
						if ((from > 0) && ((from % basesteps.length) == 0))
							break;
						for (var j = 0; j < basesteps.length; j++) {
							var idx = (from + j) % basesteps.length
							var octave = Math.floor((from + j) / basesteps.length);
							notes.push(root + basesteps[idx] + shift + octave * 12);
						}

						if (loopAt > 0 && loopAt < basesteps.length) {
							// /Regular loopAt mode, where we loop from the current pattern, restarting the pattern (and looping)
							// from the next step of it : A-B-C, B-C-A, C-A-B
							from += loopAt;
							console.log("Regular Looping at " + from);

						} else if ((loopAt == -1) && (p < (patts.length - 1))) {
							// Guided loopAt mode, where the next pattern is used to to guide the repetition of this one
							// TODO ce mécanisme ne garantit pas qu'on reste dans la bonne gamme
							var sp = patts[p + 1].indexOf(shift);
							if ((sp == -1) || (sp == (patts[p + 1].length - 1))) {
								// On ne trouve notre point de départ actual, ou on est à la dernière note de la pattern
								// => On a fini d'exploier la séquence suivante, on l'indique comme traitée
								p++;
								console.log("End of guided Looping");
								break;
							} else {
								shift = patts[p + 1][sp + 1];
							}
							console.log("Guided Looping at " + from);

						} else {
							// Mode sans loop
							break;
						}

					}

					pages[page].push({
						"root" : root,
						"mode" : mode,
						"notes" : notes
					});

				}

			}

		}

		// Debug
		for (var i = 0; i < pages.length; i++) {
			for (var j = 0; j < pages[i].length; j++) {
				for (var k = 0; k < pages[i][j].notes.length; k++) {
					console.log(i + ") [" + pages[i][j].root + "/" + pages[i][j].mode + "] " + pages[i][j].notes[k]);
				}
			}
		}

		// To Score


		//var score = newScore("Workout", "saxophone", 20);
		var score = newScore("Workout", "bass-flute", 99); // transposing instruments (a.o. the saxophone) are buggy
		var numerator = 4;
		var denominator = 4;

		score.addText("title", "Workouts");

		score.startCmd();

		var cursor = score.newCursor();
		cursor.track = 0;

		cursor.rewind(0);
		var ts = newElement(Element.TIMESIG);
		ts.timesig = fraction(numerator, denominator);
		cursor.add(ts);

		cursor.rewind(0);
		var cur_time = cursor.segment.tick;

		var counter = 0;
		var prevRoot = '';
		var preferredTpcs = NoteHelper.tpcs;

		for (var i = 0; i < pages.length; i++) {
			for (var j = 0; j < pages[i].length; j++) {
				var root = pages[i][j].root;
				var mode = pages[i][j].mode;
				if (root !== prevRoot) {
					preferredTpcs = filterTpcs(root, mode);
					prevRoot = root;
				}

				for (var k = 0; k < pages[i][j].notes.length; k++, counter++) {
					if (counter > 0) {
						cursor.rewindToTick(cur_time); // be sure to move to the next rest, as now defined
						cursor.next();
					}
					cursor.setDuration(1, 4); // quarter
					var note = cursor.element;

					var delta = pages[i][j].notes[k];
					var pitch = _Cpitch + delta;
					var tpc = 14; // One default value. The one of the C natural.

					for (var t = 0; t < preferredTpcs.length; t++) {
						if (preferredTpcs[t].pitch == (delta % 12)) {
							tpc = preferredTpcs[t].tpc;
							break;
						}
					}

					var target = {
						"pitch" : pitch,
						"tpc1" : tpc,
						"tpc2" : tpc
					};

					note = NoteHelper.restToNote(note, target);

					//cur_time = note.parent.tick; // getting note's segment's tick
					cur_time = cursor.segment.tick;

					debugNote(delta, note);

				}

				// Fill with rests until end of measure
				var fill = pages[i][j].notes.length % 4;
				if (fill > 0) {
					fill = 4 - fill;
					//console.log("Going to fill for :"+fill);
					for (var f = 0; f < fill; f++) {}
					cursor.rewindToTick(cur_time); // be sure to move to the next rest, as now defined
					cursor.next();
					cursor.setDuration(1, 4); // quarter
					cursor.addRest();
					cur_time = cursor.segment.tick;
				}
			}
		}

		score.endCmd();

	}

	function filterTpcs(root, mode) {
		var sharp_mode = true;

		var f = _chords[root][mode];
		if (f !== undefined)
			sharp_mode = f;

		var accidentals = sharp_mode ? ['NONE', 'SHARP', 'SHARP2'] : ['NONE', 'FLAT', 'FLAT2']
			var preferredTpcs;

		// On ne garde que les tpcs correspondant au type d'accord et trié par type d'altération
		var preferredTpcs = NoteHelper.tpcs.filter(function (e) {
				return accidentals.indexOf(e.accidental) >= 0;
			});

		preferredTpcs = preferredTpcs.sort(function (a, b) {
				var acca = accidentals.indexOf(a.accidental);
				var accb = accidentals.indexOf(b.accidental);
				if (acca != accb)
					return acca - accb;
				return a.pitch - b.pitch;
			});

		for (var i = 0; i < preferredTpcs.length; i++) {
			if (preferredTpcs[i].pitch < 0)
				preferredTpcs[i].pitch += 12;
			//console.log(root + " (" + mode + ") => " + sharp_mode + ": " + preferredTpcs[i].name + "/" + preferredTpcs[i].pitch);
		}

		return preferredTpcs;

	}

	function debugNote(delta, n) {
		NoteHelper.enrichNote(n);
		console.log("delta:" + delta + ", pitch:" + n.pitch + ", tpc:" + n.tpc + ", name:" + n.extname.fullname);
	}

	property bool reset : true

	GridLayout {
		anchors.fill : parent
		anchors.margins : 25
		columnSpacing : 10
		rowSpacing : 10
		columns : 2

		GridLayout { // un small element within the fullWidth/fullHeight where we paint the repeater
			//anchors.verticalCenter : parent.verticalCenter
			id : idNoteGrid
			rows : _max_patterns + 1
			columns : _max_steps + 2
			columnSpacing : 0
			rowSpacing : 0

			//Layout.column : 0
			//Layout.row : 0
			Layout.columnSpan : 2

			Layout.alignment : Qt.AlignCenter
			//Layout.preferredWidth : _max_steps * 20
			//Layout.preferredHeight : (_max_patterns + 1) * 20

			Repeater {
				id : idPatternLabels
				model : _max_patterns

				Label {
					Layout.row : index + 1
					Layout.column : 0
					Layout.alignment : Qt.AlignVCenter | Qt.AlignRight
					Layout.rightMargin : 10
					Layout.leftMargin : 2
					text : "Pattern " + (index + 1) +":"
				}
			}

			Label {
				Layout.row : 0
				Layout.column : _max_steps + 2
				Layout.alignment : Qt.AlignVCenter | Qt.AlignHCenter
				Layout.rightMargin : 2
				Layout.leftMargin : 2
				Layout.bottomMargin : 5
				text : "Repeating mode"
			}

			Repeater {
				id : idLoopingMode
				model : _max_patterns

				ComboBox {
					model : _loops
					Layout.row : index + 1
					Layout.column : _max_steps + 2
					Layout.alignment : Qt.AlignVCenter | Qt.AlignLeft
					Layout.rightMargin : 2
					Layout.leftMargin : 2
					//text : "0"
				}
			}

			Repeater {
				id : idNoteLabels
				model : _max_steps

				Label {
					Layout.row : 0
					Layout.column : index + 1
					Layout.alignment : Qt.AlignVCenter | Qt.AlignHCenter
					Layout.rightMargin : 2
					Layout.leftMargin : 2
					Layout.bottomMargin : 5
					text : (index + 1)
				}
			}
			Repeater {
				id : idStepNotes
				model : patterns

				Loader {
					id : loaderNotes
					property int stepIndex : index % _max_steps
					property int patternIndex : Math.floor(index / _max_steps)
					Layout.row : 1 + patternIndex
					Layout.column : 1 + stepIndex
					Binding {
						target : loaderNotes.item
						property : "step"
						value : patterns[patternIndex * _max_steps + stepIndex]
					}
					Binding {
						target : loaderNotes.item
						property : "patternIndex"
						value : patternIndex
					}
					Binding {
						target : loaderNotes.item
						property : "stepIndex"
						value : stepIndex
					}
					sourceComponent : stepComponent
				}

			}
		}

		// Presets
		Label {
			//Layout.column : 0
			//Layout.row : 2
			text : "Presets:"
		}

		ComboBox {
			id : lstPresets
			model : presets

			//Layout.column : 1
			//Layout.row : 2

			contentItem : Text {
				text : lstPresets.displayText
				verticalAlignment : Qt.AlignVCenter
			}

			delegate : ItemDelegate { // requiert QuickControls 2.2
				contentItem : Text {
					text : modelData.name
					verticalAlignment : Text.AlignVCenter
				}
				highlighted : lstPresets.highlightedIndex === index

			}
			onCurrentIndexChanged : {
				var __preset = model[currentIndex];
				var rr = __preset.roots;
				console.log("Preset Changed: " + __preset.name + " -- " + rr);
				for (var i = 0; i < _max_roots; i++) {
					if (i < rr.length) {
						steproots[i] = _roots[rr[i]];
					} else {
						steproots[i] = '';
					}

					console.log("selecting root " + i + ": " + steproots[i]);
				}
				reset = false;
				reset = true;

			}
		}

		// Roots
		Label {
			//Layout.column : 0
			//Layout.row : 3
			text : "Roots:"
		}
		RowLayout {
			spacing : 5
			Layout.alignment : Qt.AlignHCenter
			//Layout.column : 1
			//Layout.row : 3

			Repeater {
				id : idRoot
				model : getRoots(reset)

				Loader {
					id : loaderRoots
					Binding {
						target : loaderRoots.item
						property : "rootIndex"
						value : model.index
					}
					sourceComponent : rootComponent
				}

			}

		}

		Label {
			//Layout.column : 0
			//Layout.row : 1
			text : "Options:"
		}

		RowLayout {
			//Layout.column : 1
			//Layout.row : 1

			CheckBox {
				id : chkByPattern
				text : "Group workouts by patterns"
				checked : true
			}
			CheckBox {
				id : chkInvert
				text : "Invert pattern every two roots"
				checked : false
				enabled : chkByPattern.checked
			}
			CheckBox {
				id : chkPageBreak
				checked : false
				text : "Page break after each group"
			}

		}

		Item {
			Layout.fillHeight : true
			//Layout.column : 0
			//Layout.row : 4
			Layout.columnSpan : 2
		}

		RowLayout {
			Layout.fillHeight : true
			//Layout.column : 0
			//Layout.row : 5
			Layout.columnSpan : 2
			Item {
				Layout.fillWidth : true
			}
			DialogButtonBox {
				standardButtons : DialogButtonBox.Close
				id : buttonBox

				background.opacity : 0 // hide default white background

				Button {
					text : "Apply"
					DialogButtonBox.buttonRole : DialogButtonBox.AcceptRole
				}

				onAccepted : {
					printWorkout();
					// Qt.quit();

				}
				onRejected : Qt.quit()

			}
		}
	}

	Component {
		id : stepComponent

		ComboBox {
			id : lstStep
			property var step : {
				"step" : 0,
				"pattern" : 0,
				"note" : ''
			}
			property int stepIndex : 0
			property int patternIndex : 0
			property int indexInPatterns : patternIndex * _max_steps + stepIndex
			Layout.alignment : Qt.AlignLeft | Qt.QtAlignBottom
			editable : false
			model : _ddNotes
			//currentIndex : find(patterns[patternIndex * _max_steps + stepIndex].note, Qt.MatchExactly)
			Layout.preferredHeight : 30
			implicitWidth : 75
			onCurrentIndexChanged : {
				//patterns[patternIndex * _max_steps + stepIndex].note = model[currentIndex]
				step.note = model[currentIndex];
				console.log("Step " + patternIndex + "/" + stepIndex + ": " + patterns[indexInPatterns].note);
			}
		}
	}

	Component {
		id : rootComponent

		ComboBox {
			id : lstRoot
			property var rootIndex
			Layout.alignment : Qt.AlignLeft | Qt.QtAlignBottom
			editable : false
			model : _ddRoots
			currentIndex : find(steproots[rootIndex], Qt.MatchExactly)
			Layout.preferredHeight : 30
			implicitWidth : 80
			onCurrentIndexChanged : {
				steproots[rootIndex] = model[currentIndex]
					console.log("Root " + rootIndex + ": " + steproots[rootIndex]);
			}
		}
	}

	function getRoots(uglyHack) {
		return steproots;
	}

	property var presets : [{
			"name" : '',
			"root" : 0,
			"roots" : []
		},
		new presetClass("chromatic", 0, function (r) {
			return r + 1;
		}),
		new presetClass("seconds", 0, function (r) {
			return r + 2;
		}),
		new presetClass("quarts", 0, function (r) {
			return r + 5;
		}),
	]

	function presetClass(name, root, funcNext) {
		this.name = name;
		this.root = root;
		this.getNext = funcNext;
		Object.defineProperty(this, "roots", {
			get : function () {
				console.log("getting roots for " + this.name);
				var roots = [this.root];
				var r = this.root;
				console.log("r: " + r + " (starting at)");
				while (true) {
					r = this.getNext(r);
					console.log("r: " + r);
					r = r % 12;
					console.log("\t==>r: " + r);
					if (r == root) {
						break;
					}
					roots.push(r);
				}

				return roots;
			},

			enumerable : true
		});

	}

}
