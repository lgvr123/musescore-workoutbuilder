import QtQuick 2.9
import QtQuick.Controls 2.2
import MuseScore 3.0
import QtQuick.Window 2.2
import QtQuick.Dialogs 1.2
import QtQuick.Controls.Styles 1.4
import QtQuick.Layouts 1.3
import FileIO 3.0
import Qt.labs.settings 1.0

import "workoutbuilder/notehelper.js" as NoteHelper
import "workoutbuilder/chordanalyser.js" as ChordHelper
import "workoutbuilder/selectionhelper.js" as SelHelper
import "workoutbuilder"

/**********************
/* Parking B - MuseScore - Scale Workout builder plugin
/* v2.4.0
/* ChangeLog:
/* 	- 0.0.0: Initial release
/*  - 1.0.0: Tools and library of patterns and workouts
/*  - 1.1.0: Transposing instruments, New options for measure management, order in the workouts list, ...
/*  - 1.2.0: Pattern name
/*  - 1.2.1: Bugfix on cycling mode
/*  - 2.0.0: Grid workout
/*  - 2.1.0: Custom chords in Grid workout
/*  - 2.1.1: Better workout name management
/*  - 2.2.0: Textual description of grids
/*  - 2.2.1 (ongoing): Allow "|" et "(###)" in the textual description of grids
/*  - 2.2.2 Bug in chordanalyzer.js
/*  - 2.3.0 New ChordUp and ChordDown options in grid mode
/*  - 2.3.0 Refactoring of patterns to ListModel
/*  - 2.3.0 Moved *.js libraries to own folder
/*  - 2.3.0 Store settings (checkboxes, instrument)
/*  - 2.3.0 Add new "Bass" instrument (should a require a F-clef, but the clef is not available from the API)
/*  - 2.4.0 alpha 1: Add step durations
/*  - 2.4.0 alpha 2: Limit to standard Harmony types
/*  - 2.4.0 alpha 2: Improved chord naming
/*  - 2.4.0 alpha 3: Pushing grid patterns was not working
/**********************************************/
MuseScore {
    menuPath: "Plugins." + pluginName
    description: "This plugin builds chordscale workouts based on patterns defined by the user."
    version: "2.4.0 alpha3"

    pluginType: "dialog"
    requiresScore: false
    width: 1375
    height: 820

    id: mainWindow

    readonly property var pluginName: "Scale Workout Builder"
    readonly property var noteHelperVersion: "1.0.3"
    readonly property var chordHelperVersion: "1.2.8"
    readonly property var selHelperVersion: "1.2.0"

    readonly property var librarypath: { {
            var f = Qt.resolvedUrl("workoutbuilder/workoutbuilder.library");
            f = f.slice(8); // remove the "file:" added by Qt.resolveUrl and not understood by the FileIO API
            return f;
        }
    }

    readonly property var keyRegexp: /^(\((b*?|#*?)\))?\s*(.*?)(\|?)$/m
    readonly property var endRegexp: /\|\s*;?/g

    onRun: {

        console.log("==========================================================");

        // Versionning
        if ((typeof(SelHelper.checktVersion) !== 'function') || !SelHelper.checktVersion(selHelperVersion) ||
            (typeof(NoteHelper.checktVersion) !== 'function') || !NoteHelper.checktVersion(noteHelperVersion) ||
            (typeof(ChordHelper.checkVersion) !== 'function') || !ChordHelper.checkVersion(chordHelperVersion)) {
            console.log("Invalid selectionhelper.js, notehelper.js or chordanalyser.js versions. Expecting "
                 + selHelperVersion + " and " + noteHelperVersion + " and " + chordHelperVersion + ".");
            invalidLibraryDialog.open();
            return;
        }

        // Misc. tweaks
        String.prototype.hashCode = function () {
            var hash = 0;
            for (var i = 0; i < this.length; i++) {
                var character = this.charCodeAt(i);
                hash = ((hash << 5) - hash) + character;
                hash = hash & hash; // Convert to 32bit integer
            }
            return hash;
        }

        // Processing
        console.log(librarypath);
        console.log(libraryFile.source);

        loadLibrary();

    }
	
	Settings {
        id: settings
        category: "WorkoutBuilder"
		property alias invertOdds: chkInvert.checked
		property alias orderByPattern: chkByPattern.checked
		property alias adaptativeMeasure: chkAdaptativeMeasure.checked
		property alias strictLayout: chkStrictLayout.checked
		property alias instrument: lstTransposition.currentIndex
    }


    readonly property var _SCALE_MODE: "scale"
    readonly property var _GRID_MODE: "grid"

    property int _max_patterns: 10
    property int _max_steps: 12 
	
    property int _max_roots: 12
    property var _degrees: ['1', 'b2', '2', 'm3', 'M3', '4', 'b5', '5', 'm6', 'M6', 'm7', 'M7',
        '(8)', 'b9', '9', '#9', 'b11', '11', '#11', '(12)', 'b13', '13', '#13', '(14)']

    // v2.1.0
    // property var _griddegrees: ['1', '3', '5', '7', '8', '9', '11'];
    property var _griddegrees: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '11'];

    property var _instruments: [{
            "label": "C Instruments (default)",
            "instrument": "flute",
            "cpitch": 60,
			"clef": "C"
        }, {
            "label": "B♭ instruments",
            "instrument": "soprano-saxophone",
            "cpitch": 48,
			"clef": "C"
        }, {
            "label": "E♭ instruments",
            "instrument": "eb-clarinet",
            "cpitch": 60,
			"clef": "C"
        }, {
            "label": "D instruments",
            "instrument": "d-trumpet",
            "cpitch": 60,
			"clef": "C"
        }, {
            "label": "E instruments",
            "instrument": "e-trumpet",
            "cpitch": 60,
			"clef": "C"
        }, {
            "label": "F instruments",
            "instrument": "horn",
            "cpitch": 48,
			"clef": "C"
        }, {
            "label": "G instruments",
            "instrument": "alto-flute",
            "cpitch": 48,
			"clef": "C"
        }, {
            "label": "A instruments",
            "instrument": "a-cornet",
            "cpitch": 48,
			"clef": "C"
        }, {
            "label": "Bass instruments",
            "instrument": "double-bass",
            "cpitch": 36,
			"clef": "F"
        },
    ]

    property var _gridTypes: [{
            "type": "grid",
            "label": "Grid",
            "image": "grid.png",
        }, {
            "type": "chordup",
            "label": "Notes of chord - ascending",
            "image": "chordup.png",
        }, {
            "type": "chorddown",
            "label": "Notes of chord - descending",
            "image": "chorddown.png",
        }]

    property var _loops: [{
            "type": 0,
            "label": "No repetition",
            "image": "none.png",
            "id": "--"
        }, {
            "type": 2,
            "label": "Reverse pattern",
            "short": "Reversed",
            "image": "reverse.png",
            //"shift": 1,
            "id": "R"
        }, {
            "type": 1,
            "label": "Cycle pattern",
            "short": "Cycled",
            "image": "loopat1.png",
            "shift": 1,
            "id": "P+"
        }, {
            "type": 1,
            "label": "Reverse cycle pattern",
            "short": "Reverse Cycled",
            "image": "loopat-1.png",
            "shift": -1,
            "id": "P-"
        }, {
            "type": -1,
            "label": "Repeat at every Triad (ascending)",
            "short": "Triad up",
            "image": "Triadeup.png",
            "shift": 2,
            "id": "S3+"

        }, {
            "type": -1,
            "label": "Repeat at every Triad (descending)",
            "short": "Triad down",
            "image": "Triadedown.png",
            "shift": -2,
            "id": "S3-"
        }, {
            "type": -1,
            "label": "Repeat at every degree (ascending)",
            "short": "Diatonic up",
            "image": "up.png",
            "shift": 1,
            "id": "S+"
        }, {
            "type": -1,
            "label": "Repeat at every degree (descending)",
            "short": "Diatonic down",
            "image": "down.png",
            "shift": -1,
            "id": "S-"
        },
    ]

    property var _chordTypes: {

        "M": {
            "symb": "",
            "scale": [0, 2, 4, 5, 7, 9, 11, 12],
            "mode": "major"
        },
        "m": {
            "symb": "m",
            "scale": [0, 2, 3, 5, 7, 8, 10, 12],
            "mode": "minor"
        },
        "△7": {
            "symb": "t7",
            "scale": [0, 2, 4, 5, 7, 9, 11, 12],
            "mode": "major"
        },
        "7": {
            "symb": "7",
            "scale": [0, 2, 4, 5, 7, 9, 10, 12],
            "mode": "major"
        },
        "m7": {
            "symb": "m7",
            "scale": [0, 2, 3, 5, 7, 8, 10, 12],
            "mode": "minor"
        },
        "ø": {
            "symb": "0",
            "scale": [0, 2, 3, 5, 6, 8, 10, 12],
            "mode": "minor"
        },
        "dim": {
            "symb": "o",
            "scale": [0, 1, 3, 4, 6, 7, 9, 12],
            "mode": "minor"
        },
        "Bepop": {
            "symb": "-7",
            "scale": [0, 2, 4, 5, 7, 9, 10, 11, 12]
        },
    }

    property var _ddChordTypes: { {
            var keys = Object.keys(_chordTypes);
            // keep this order
            var dd = ['M', 'm', '△7', '7', 'm7', 'ø', 'dim', 'extra'];
            dd = dd.filter(function (s) {
                return keys.indexOf(s) > -1;
            });
            // and the new ones, one could have forgotten in the previous list
            keys = keys.filter(function (s) {
                return dd.indexOf(s) == -1;
            });
            dd = [''].concat(dd).concat(keys);
            //dd = [' '].concat(dd);
            return dd;
        }
    }

    property var _chords: [{
            "root": 'C',
            "major": false, // we consider C as a flat scale, sothat a m7 is displayed as B♭ instead of A♯
            "minor": false
        }, {
            "root": 'D♭/C♯',
            "major": false,
            "minor": true
        }, {
            "root": 'D',
            "major": true,
            "minor": false
        }, {
            "root": 'E♭/D♯',
            "major": false,
            "minor": true
        }, {
            "root": 'E',
            "major": true,
            "minor": true
        }, {
            "root": 'F',
            "major": false,
            "minor": false
        }, {
            "root": 'F♯/G♭',
            "major": true,
            "minor": true
        }, {
            "root": 'G',
            "major": true,
            "minor": false
        }, {
            "root": 'A♭/G♯',
            "major": false,
            "minor": true
        }, {
            "root": 'A',
            "major": true,
            "minor": true
        }, {
            "root": 'B♭/A♯',
            "major": false,
            "minor": false
        }, {
            "root": 'B',
            "major": true,
            "minor": true
        }
    ]

    property var _roots: { {
            var dd = [];
            for (var i = 0; i < _chords.length; i++) {
                dd.push(_chords[i].root);
            }
            return dd;
        }
    }

    property var _ddRoots: { {
            var dd = [''];
            dd = dd.concat(_roots);
            return dd;
        }
    }

    property var _ddNotes: { {
			var dd=_degrees.map(function (e) { return {text: e, step: e}});
			// dd.unshift({text: '<html><span style="font-family:\'MScore Text\'; font-size: 20px; text-align: center; vertical-align: middle">\uE4E5</span></html>', step: 'R'});
			// dd.unshift({text: String.fromCharCode(7694), step: 'R'});
			dd.unshift({text: '(R)', step: 'R'});
			dd.unshift({text: '', step: ''});
            return dd;
        }
    }

    property var _ddGridNotes: { {
			var dd=_griddegrees.map(function (e) { return {text: e, step: e}});
			dd.unshift({text: '(R)', step: 'R'});
			dd.unshift({text: '', step: ''});
            return dd;
        }
    }
	
		property var durations : [
		//mult is a tempo-multiplier compared to a crotchet      
		{text: '\uECA2',               duration: 4     ,  fraction: fraction( 1, 1)  },
		{text: '\uECA3 \uECB7',        duration: 3     ,  fraction: fraction( 3, 4)  },
		{text: '\uECA3',               duration: 2     ,  fraction: fraction( 1, 2)  },
		// {text: '\uECA5 \uECB7 \uECB7', duration: 1.75  ,  fraction: fraction( 7,16)  },
		{text: '\uECA5 \uECB7',        duration: 1.5   ,  fraction: fraction( 3, 8)  },
		{text: '\uECA5',               duration: 1     ,  fraction: fraction( 1, 4)  },
		// {text: '\uECA7 \uECB7 \uECB7', duration: 0.875 ,  fraction: fraction( 7,32)  },
		{text: '\uECA7 \uECB7',        duration: 0.75  ,  fraction: fraction( 3,16)  },
		{text: '\uECA7',               duration: 0.5   ,  fraction: fraction( 1, 8)  },
		// {text: '\uECA9 \uECB7 \uECB7', duration: 0.4375,  fraction: fraction( 7,64)  },
		// {text: '\uECA9 \uECB7',        duration: 0.375 ,  fraction: fraction( 3,32)  },
		{text: '\uECA9',               duration: 0.25  ,  fraction: fraction( 1,16)  },
		]
	

	ListModel {
		id: mpatterns

		Component.onCompleted: {
			for (var p = 0; p < _max_patterns; p++) {
				var steps = [];
				for (var s = 0; s < _max_steps; s++) {
					steps.push({
                        "note": '', // scale mode
                        "degree": '',// grid mode 
						"duration": 1, // all modes
					});
				}
				mpatterns.append({
					"gridType": 'grid',
					"loopMode": '--', 
					"steps": steps, // will be converted to ListElement
					"chordType" : '', 
					"pattName":'', 
				});
			}
		}

	}


    property var library: []
    property var workouts: []
    property var phrases: []

    readonly property int tooltipShow: 500
    readonly property int tooltipHide: 5000

    property var clipboard: undefined

    property var rootSchemeName: undefined
    property var workoutName: undefined
    property var lastLoadedWorkoutName: undefined
    property var lastLoadedGridWorkoutName: undefined
    property var lastLoadedPhraseName: undefined

    function printWorkout() {
        var scaleMode = (modeIndex() == 0);

        var pages = (scaleMode) ? printWorkout_forScale() : printWorkout_forGrid();

        if (pages.length == 0) {
            missingStuffDialog.open();
            return;
        }

        // Debug
        for (var i = 0; i < pages.length; i++) {
            console.log("[" + i + "]" + pages[i]);
            //if (pages[i]===undefined) continue; // ne devrait plus arriver
            for (var j = 0; j < pages[i].length; j++) {
				debugO("for print, pattern "+j+"/"+i, pages[i][j],["scale"]);
                // for (var k = 0; k < pages[i][j].notes.length; k++) {
                    // console.log(i + ") [" + pages[i][j].root + "/" + pages[i][j].mode + "/" + pages[i][j].chord.name + "] " + k + ": " + pages[i][j].notes[k]);
                // }
            }
        }

        printWorkout_pushToScore(pages);

    }
	
    function printWorkout_forGrid() {
        // 1) Collecting the roots
        var chords = getPhrase().chords;

        var patts = [];

        // 2) Collect the patterns and their definition
        for (var i = 0; i < _max_patterns; i++) {
            // 1.1) Collecting the basesteps
			var raw=mpatterns.get(i);

            var p = null;
			if (raw.gridType==='grid') {
				p = [];
				// for (var j = 0; j < _max_steps; j++) {
					// var sn = raw.steps.get(j);
					// if (sn.degree !== '') {
						// var d = _griddegrees.indexOf(sn.degree);
						// if (d > -1)
							// p.push(sn.degree); // we keep the degree !!!
					// } else
						// break;
				// }
			// 2.4.0 adding in reverse order
            for (var j = (_max_steps-1); j >=0 ; j--) {
                var sn = raw.steps.get(j);
                if (sn.degree === 'R') {
                    p.unshift({"note": null, "duration": sn.duration}); 
				}
                else if (sn.degree !== '') {
						var d = _griddegrees.indexOf(sn.degree);
						if (d > -1)
                        p.unshift({"note": sn.degree, "duration": sn.duration}); // we keep the degree !!!
                } else if (p.length===0) {
					continue;
                } 
				// else
                    // p.unshift({"note": null, "duration": sn.duration}); 
            }

				if (p.length == 0) {
					break;
				}
				
				
				
			
			// 1.2) Completing the pattern to have a round duration
			if (chkAdaptativeMeasure.checked && chkStrictLayout.checked) {
			    var total = p.map(function (e) {
			        return e.duration
			    }).reduce(function (t, n) {
			        return t + n;
			    });
			    if (total < Math.ceil(total)) {
			        var inc = Math.ceil(total) - total;
			        console.log("adding a rest of " + inc);
			        p.push({
			            "note": null,
			            "duration": inc
			        });
			    } else
			        console.log("!! Measure is complete. Don't need to add some rests");
			} else
			    console.log("!! Don't need to check for measure completness");


			debugO("after cleaning", p);
			}

            // 1.3) Retrieving loop mode
            var mode = raw.loopMode;
			mode = _loops.filter(function(e) {return e.id===mode})[0];
            console.log("looping mode : " + mode.label);

            // Retrieving Chord type
            // Build final pattern
            var pattern = {
                "notes": p,
                "loopAt": mode,
                "name": (raw.gridType!=="grid")?"Chord notes":raw.pattName,
				"gridType": raw.gridType,
            };
            patts.push(pattern);
			debugO("ready",pattern.notes); // debug

        }

        // Must have at least 1 pattern and 1 root
        var pages = [];
        if (patts.length == 0 || chords.length == 0) {
            return [];
        }

        var pages = [];
        var page = -1;

        // We sort by patterns. By pattern, repeat over each root
        for (var p = 0; p < patts.length; p++) {
            var pp = patts[p];
            // On change de "page" entre chaque pattern
            console.log("page++ (SP)");
            page = pages.length; // i.e. Go 1 index further (so if the array is empty, the first index will be 0)
            console.log(">>page for pattern " + p + ": " + page);

            for (var r = 0; r < chords.length; r++) {
                console.log("By P, patterns: " + p + "/" + (patts.length - 1) + "; chords:" + r + "/" + (chords.length - 1) + " => " + page);

                var chord = chords[r];
                var root = chord.root;
                var chordtype = chord.type;
                // var scale = _chordTypes[chordtype].scale;
                // v2.1.0
                var effective_chord;
                var scale;
                console.log(Object.keys(_chordTypes));

                if (Object.keys(_chordTypes).indexOf(chordtype) >= 0) {
                    // known scale
                    effective_chord = JSON.parse(JSON.stringify(_chordTypes[chordtype])); // taking a copy
                    // scale = _chordTypes[chordtype].scale;
                    scale = effective_chord.scale;

                } else {
                    //unknown scale
                    var s = ChordHelper.scaleFromText(chordtype);
                    effective_chord = {
                        "symb": chordtype,
                        // "scale": s.scale,
                        "scale": s.keys,  // ChordHelper.scaleFromText exports "keys", not "scale"
                        "mode": s.mode
                    };
                    scale = s.keys;

                }

                // pushing other properties from the chord to the chord to be used
                if (chord.sharp !== undefined)
                    effective_chord.sharp = chord.sharp;
                if (chord.name !== undefined)
                    effective_chord.name = chord.name;
                if (chord.end !== undefined)
                    effective_chord.end = chord.end;
                if (chord.key !== undefined)
                    effective_chord.key = chord.key;

                // debugO("effective_chord", effective_chord, ["scale"]);

                var steps = [];
				// if (pp.notes.length==1 && pp.notes[0]==null) {
				if (pp.gridType!=="grid") {
					// Chord mode: take only the notes of the chord
					var nns=chord.chordnotes.map(function(e) { return parseInt(e.note); }).sort(function(a,b) { return a-b;});
					
					console.log("~~~~Dealing with the ChordNotes~~~~~"+pp.gridType)
					if (chord.bass!=null) {
						console.log("~~~~Dealing with the bass~~~~~")
						console.log("nns before: "+nns);
						var bass=chord.bass.key;
						var idx=nns.indexOf(bass);
						nns.pop(); // retirer le "12"
						console.log("nns without 12: "+nns);
						nns=nns.concat(nns.splice(0,idx).map(function(e){ return e+12}));
						console.log("nns rotated: "+nns);
						nns=nns.concat(12+bass);
						console.log("nns with bass+12: "+nns);

					}
					
					steps=nns.map(function(e) { return { note: e, duration: 1 }});
					
					if(pp.gridType=="chorddown") steps=reversePattern(steps);
					
				} else {
					// Traditional mode: pattern based
					for (var n = 0; n < pp.notes.length; n++) {
						var degree=pp.notes[n];
						var inScale =null;
						if (degree.note !== null) {
						var ip = parseInt(degree.note) - 1; // TODO: This is not clean: using a label "1" and trying to deduce the valid array index

						console.log(ip + "--" + (ip % 7) + "--" + Math.floor(ip / 7) + "--" + (Math.floor(ip / 7) * 12) + "**" + scale[ip % 7] + "**" + (scale[ip % 7] + (Math.floor(ip / 7) * 12)));

						inScale = (scale[ip % 7]) + (Math.floor(ip / 7) * 12);
						}
						console.log(n + ": " + pp.notes[n].note + " --> " + ip + " --> " + inScale);
						var step={note: inScale, duration: degree.duration}; 
						steps.push(step);
					}
				}

                var pattern = {
                    "notes": steps,
                    "loopAt": pp.loopAt,
                    "chord": effective_chord,
                    "name": pp.name,
					"gridType": pp.gridType
                };

                var local = extendPattern(pattern);
                // tweak the representation
                local.representation = (pattern.name && pattern.name !== "") ? pattern.name : pp.notes.map(function(e) { e.note }).filter(function(e) { e!==null }) .join("/");
                var subpatterns = local["subpatterns"];

                //console.log("# subpatterns: "+subpatterns.length);
                //debugO("Orig",pattern);
                //debugO("Extended",local);

                // Looping through the "loopAt" subpatterns (keeping them as a whole)
                for (var s = 0; s < subpatterns.length; s++) {
                    var placeAt = page + ((chkByPattern.checked) ? 0 : s);

                    console.log(">> Looking at pattern " + p + ", subpattern " + s + " => will be placed at page " + placeAt + " (page=" + page + ")");
                    if (pages[placeAt] === undefined)
                        pages[placeAt] = [];

                    var basesteps = subpatterns[s];

                    var notes = [];

					var p=(!chkInvert.checked || ((r % 2) == 0))?basesteps:reversePattern(basesteps);
					
                        for (var j = 0; j < p.length; j++) {
                            console.log(">>> Looking at note " + j + ": " + p[j].note);
                            //notes.push(root + p[j]);
								var _n=(p[j].note!==null)?(root + p[j].note):null;
								// var _n=(p[j].note!==null)?root + p[j].note:0;
                                notes.push({"note" : _n, "duration": p[j].duration });
                        }


                    debugO("pushing to pages (effective_chord): ", effective_chord, ["scale"]);

                    pages[placeAt].push({
                        "root": root,
                        "chord": effective_chord,
                        "mode": effective_chord.mode,
                        "notes": notes,
                        "representation": local.representation,
						"gridType": local.gridType
                    });

                }

            }
        }

        return pages;
        //return [];

    }
    function printWorkout_forScale() {

        var patts = [];

        // 1) Collect the patterns and their definition
        for (var i = 0; i < _max_patterns; i++) {
			var raw=mpatterns.get(i);
			// if (raw.isEmpty(_SCALE_MODE)) continue;
			
            // 1.1) Collecting the basesteps
            var p = [];
			// 2.4.0 adding in reverse order
            for (var j = (_max_steps-1); j >=0 ; j--) {
                var sn = raw.steps.get(j);
                if (sn.note === 'R') {
                    p.unshift({"note": null, "duration": sn.duration}); 
				}
                else if (sn.note !== '') {
                    var d = _degrees.indexOf(sn.note);
                    if (d > -1)
                        p.unshift({"note": d, "duration": sn.duration});
                } else if (p.length===0) {
					continue;
                } 
				// else
                    // p.unshift({"note": null, "duration": sn.duration}); 
            }
			

            if (p.length == 0) {
                break;
            }
			
			// 1.2) Completing the pattern to have a round duration
			if (chkAdaptativeMeasure.checked && chkStrictLayout.checked) {
			    var total = p.map(function (e) {
			        return e.duration
			    }).reduce(function (t, n) {
			        return t + n;
			    });
			    if (total < Math.ceil(total)) {
			        var inc = Math.ceil(total) - total;
			        console.log("adding a rest of " + inc);
			        p.push({
			            "note": null,
			            "duration": inc
			        });
			    } else
			        console.log("!! Measure is complete. Don't need to add some rests");
			} else
			    console.log("!! Don't need to check for measure completness");

			debugO("after cleaning", p);

            // 1.3) Retrieving loop mode
            var mode = raw.loopMode;
			mode = _loops.filter(function(e) {return e.id===mode})[0];
            console.log("looping mode : " + mode.label);

            // Retrieving Chord type
            var cText = raw.chordType // editable
            if (cText === '') {
				var nn=p.map(function(e) { return e.note });
                var m3 = (nn.indexOf(3) > -1); // if we have the "m3" the we are in minor mode.
                if (nn.indexOf(10) > -1) { //m7
                    cText = m3 ? "m7" : "7";
                } else if (nn.indexOf(11) > -1) { //M7
                    cText = m3 ? "m7" : "t7";
                } else {
                    cText = m3 ? "m" : "Maj";
                }

            }
            var cSymb = _chordTypes[cText];
            if (cSymb === undefined) {
                cSymb = {}+cText.includes("-") ? _chordTypes['m'] : _chordTypes['M']; //clone it // For user-specific chord type, we take a Major scale, or the Min scale of we found a "-"
                cSymb.symb = cText;

            }

            console.log("Pattern " + i + ": " + cText + " > " + cSymb.symb);

            // Build final pattern
            var pattern = {
                "notes": p,
                "loopAt": mode,
                "chord": cSymb,
                "name": raw.pattName,
            };
            patts.push(pattern);
			
			debugO("ready",pattern.notes); // debug

        }

        // Collecting the roots
        var roots = [];
        for (var i = 0; i < _max_roots; i++) {
            var txt = idRoot.itemAt(i).currentText;
            // console.log("Next Root: " + txt);
            if (txt === '' || txt === undefined)
                continue;
            var r = _roots.indexOf(txt);
            // console.log("-- => " + r);
            if (r > -1)
                roots.push(r)
        }

        // Must have at least 1 pattern and 1 root
        var pages = [];
        if (patts.length == 0 || roots.length == 0) {
            return [];
        }

        // Extending the patterns with their subpatterns
        var extpatts = [];
        for (var p = 0; p < patts.length; p++) {
            var pp = extendPattern(patts[p]);
            extpatts.push(pp);
        }

        // Building the notes and their order
        var page = -1;
        if (chkByPattern.checked) {
            // We sort by patterns. By pattern, repeat over each root
            for (var p = 0; p < extpatts.length; p++) {
                var pp = extpatts[p];
                var mode = (pp.notes.map(function(e) { return e.note }).indexOf(3) > -1) ? "minor" : "major"; // if we have the "m3" the we are in minor mode.
                //var page = p; //0; //(chkPageBreak.checked) ? p : 0;
                if ((p == 0) || ((patts.length > 1) && (roots.length > 1))) {
                    console.log("page++");
                    page++;
                }
                for (var r = 0; r < roots.length; r++) {
                    console.log("By P, patterns: " + p + "/" + (patts.length - 1) + "; roots:" + r + "/" + (roots.length - 1) + " => " + page);

                    var root = roots[r];

                    // Looping through the "loopAt" subpatterns (keeping them as a whole)
                    for (var s = 0; s < pp["subpatterns"].length; s++) {
                        if (pages[page] === undefined)
                            pages[page] = [];

                        var basesteps = pp["subpatterns"][s];

                        var notes = [];

						var _base=(!chkInvert.checked || ((r % 2) == 0))?basesteps:reversePattern(basesteps);

						for (var j = 0; j < _base.length; j++) {
							console.log(">>> Looking at note " + j + ": " + _base[j].note);
							//notes.push(root + _base[j]);
								var _n=(_base[j].note!==null)?(root + _base[j].note):null;
								// var _n=(_base[j].note!==null)?root + _base[j].note:0;
								notes.push({"note" : _n, "duration": _base[j].duration });
						}


                        pages[page].push({
                            "root": root,
                            "chord": pp.chord,
                            "mode": mode,
                            "notes": notes,
                            "representation": pp.representation
                        });

                    }
                    // On ne change pas de "page" entre root sauf si
                    // a) la pattern coutante est "loopée", dans quel cas on change à chaque root (sauf à la dernière).
                    // b) la pattern suivante est "loopée", dans quel cas on change à chaque root (sauf à la dernière).

                    if (
                        (
                            (pp["subpatterns"].length > 1) ||
                            ((p < (extpatts.length - 1)) && (extpatts[p + 1]["subpatterns"].length > 1) && (r == (roots.length - 1))))
                         &&
                        ((roots.length == 1) || (r < (roots.length - 1)))) {
                        console.log("page++ (SP)");
                        page++;
                    } {
                        console.log("no page++ (SP) : " + (pp["subpatterns"].length) + "//" + r + "/" + (patts.length - 1));

                    }
                }

            }
        } else {
            // We sort by roots. By root, repeat every pattern
            for (var r = 0; r < roots.length; r++) {
                //var page = r; //0; //(chkPageBreak.checked) ? r : 0;

                var root = roots[r];

                if ((r == 0) || ((patts.length > 1) && (roots.length > 1))) {
                    console.log("page++");
                    page++;
                }
                for (var p = 0; p < extpatts.length; p++) {
                    console.log("By R, patterns: " + p + "/" + (patts.length - 1) + "; roots:" + r + "/" + (roots.length - 1) + " => " + page);

                    var pp = extpatts[p];
                    var mode = (pp.notes.map(function(e) { return e.note }).indexOf(3) > -1) ? "minor" : "major"; // if we have the "m3" the we are in minor mode.


                    // Looping through the "loopAt" subpatterns
                    for (var s = 0; s < pp["subpatterns"].length; s++) {
                        if (pages[page] === undefined)
                            pages[page] = [];

                        var basesteps = pp["subpatterns"][s];

                        var notes = [];

                        for (var j = 0; j < basesteps.length; j++) {
								var _n=(basesteps[j].note!==null)?(root + basesteps[j].note):null;
								// var _n=(basesteps[j].note!==null)?root + basesteps[j].note:0;
                                notes.push({"note" : _n, "duration": basesteps[j].duration });
                        }

                        pages[page].push({
                            "root": root,
                            "chord": pp.chord,
                            "mode": mode,
                            "notes": notes,
                            "representation": pp.representation
                        });
                    }

                    // On ne change pas de "page" entre pattern sauf si la pattern est "loopée" ou que la suivante est loopée dans quel cas on change à chaque pattern.
                    if (
                        //(pp["subpatterns"].length > 1)
                        (
                            (pp["subpatterns"].length > 1)
                             || ((p < (extpatts.length - 1)) && (extpatts[p + 1]["subpatterns"].length > 1)))

                         && ((patts.length == 1) || (p < (patts.length - 1)))) {
                        console.log("page++ (SP)");
                        page++;
                    } else {
                        console.log("no page++ (SP) : " + (pp["subpatterns"].length) + "//" + p + "/" + (patts.length - 1));

                    }

                }

            }

        }

        return pages;

    }

    function printWorkout_pushToScore(pages) {



        var instru = _instruments[lstTransposition.currentIndex];
        console.log("Instrument is " + instru.label);

        // Push all this to the score
        var score = newScore("Workout", instru.instrument, 1);



        var title = (workoutName !== undefined) ? workoutName : "Scale workout";
        title += " - ";
        if (rootSchemeName !== undefined && rootSchemeName.trim() !== "") {
            title += rootSchemeName;
        } else if ((modeIndex() == 0)) {
            // scale mode
            for (var i = 0; i < _max_roots; i++) {
                var txt = idRoot.itemAt(i).currentText;
                // console.log("Next Root: " + txt);
                if (txt === '' || txt === undefined)
                    break;
                if (i > 0)
                    title += ", ";
                title += txt;
            }
        } else {
            // grid mode
            var names = txtPhrase.text.replace(endRegexp, '|;').split(";")
                .map(function (c) {
					var name=(c ? c.match(keyRegexp)[3] : ""); // --> ["(bbb)Abadd9|" ,"(bbb)" ,"bbb" ,"Abadd9" ,"|"]
					name=name.replace('^7','△7').replace('t7','△7').replace('0','ø');
					return name;
            })
                .filter(function (c) {
                return (c && c.trim() !== "")
            });
            if (names.length > 5) {
                names = names.slice(0, 4);
                names.push("...");
            }
            title += names.join(", ");

        }

        // Styling
        score.addText("title", title);
        if (lstTransposition.currentIndex != 0) {
            score.addText("subtitle", instru.label);
        }
        /*score.addText("source","https://github.com/lgvr123/musescore-workoutbuilder");
        score.addText("url","https://www.parkingb.be/");*/

        //Setting chordStyle is buggy. It requires those 3 actions.
        score.style.setValue("chordDescriptionFile", "chords_jazz.xml");
        score.style.setValue("chordStyle", "std");
        score.style.setValue("chordDescriptionFile", "chords_std.xml");

        score.style.setValue("minNoteDistance", "2.00");
        score.style.setValue("enableIndentationOnFirstSystem", "false");

        score.style.setValue("showFooter", "true");
        score.style.setValue("footerFirstPage", "true");
        score.style.setValue("footerOddEven", "false");
        score.style.setValue("evenFooterL", "");
        score.style.setValue("oddFooterC", "More scores on https://musescore.com/parkingb\nhttps://www.parkingb.be/");
        score.style.setValue("evenFooterR", "");

        // end of styling

        var adaptativeMeasure = chkAdaptativeMeasure.checked && chkStrictLayout.checked;
        var beatsByMeasure;


        score.startCmd();

        var cursor = score.newCursor();
        cursor.track = 0;

        cursor.rewind(0);

        // first measure sign
        if (adaptativeMeasure) {
            beatsByMeasure = signatureForPattern(pages[0][0].notes);
			console.log("recomputing beatsByMeasure to "+beatsByMeasure);
			console.log("--> "+typeof(beatsByMeasure));
			
        } else {
            beatsByMeasure = 4;
			console.log("forcing beatsByMeasure to "+beatsByMeasure);
        }
        console.log("Adapting measure to " + beatsByMeasure + "/4 (#1)");
        var ts = newElement(Element.TIMESIG);
        ts.timesig = fraction(beatsByMeasure, 4);

        console.log("New time signature is " + ts.timesig.str);
		
        cursor.add(ts);

        cursor.rewind(0);
        var cur_time = cursor.segment.tick;
		
		// Adding a clef
		// TODO: finalize
		// var clef = newElement(Element.CLEF);
		// debugO("Clef",clef);
		// //clef.xxx=yyy;
		// cursor.add(clef);


        var counter = 0;
        var preferredTpcs = NoteHelper.tpcs;
        var prevPage = -1;
        var prevBeatsByM = beatsByMeasure;
        var newLine = false;
		

        for (var i = 0; i < pages.length; i++) {

            if (i > 0) {
                // New Page ==> double bar + section break;
                cursor.rewindToTick(cur_time); // rewing to the last note

                // ... add a double line
                var measure = cursor.measure;
                if (measure.nextMeasure != null) {

                    addDoubleLineBar(measure, score);
                } else {
                    console.log("Changing the bar line is delayed after the next measure is added");
                }

                // ... add a  linebreak
                var lbreak = newElement(Element.LAYOUT_BREAK);
                lbreak.layoutBreakType = 2; //section break
                cursor.add(lbreak);
                newLine = true;
            } else {
                console.log("NO <BR>");

            }

            var prevRoot = '';
            var prevMode = 'xxxxxxxxxxxxxxx';
            var prevChord = {
                "symb": 'xxxxxxxxxxxxxxx',
                "name": 'xxxxxxxxxxxxxxx'
            };
            for (var j = 0; j < pages[i].length; j++) {
                var root = pages[i][j].root;
                var chord = pages[i][j].chord;
                var mode = pages[i][j].mode;
                if (root !== prevRoot || mode !== prevMode) {
                    preferredTpcs = filterTpcs(root, mode);
                }

                if (adaptativeMeasure) {
                    // beatsByMeasure = (pages[i][j].gridType!=="grid")?pages[i][j].notes.length:signatureForPattern(pages[i][j].notes.length);
                    // beatsByMeasure = (pages[i][j].gridType!==undefined && pages[i][j].gridType!=="grid")?pages[i][j].notes.length:signatureForPattern(pages[i][j].notes);
                    beatsByMeasure = signatureForPattern(pages[i][j].notes);
					console.log("recomputing beatsByMeasure to "+beatsByMeasure+" (#2) / gridType: "+pages[i][j].gridType);
                } else {
                    beatsByMeasure = 4;
					console.log("forcing beatsByMeasure to "+beatsByMeasure+" (#2) / gridType: "+pages[i][j].gridType);
                }
					debugO("before print",pages[i][j].notes);

                for (var k = 0; k < pages[i][j].notes.length; k++, counter++) {

                    var duration = pages[i][j].notes[k].duration;
                    var fduration = durations.find(function(e) {return e.duration===duration;});
					console.log("duration = "+duration+" => fduration = "+((fduration!==undefined)?fduration.fraction.str:"undefined"));
					fduration=(fduration!==undefined)?fduration.fraction:fraction(1,4);

					console.log("--["+k+"] NEXT 0");

                    if (counter > 0) { // the first time (ie counter===0, we don't need to move to the next one)
                        cursor.rewindToTick(cur_time); // be sure to move to the next rest, as now defined

						
						// looking for a next rest
						var success = cursor.next();
						while(success && (cursor.element.type!==Element.REST)) {
							 console.log("--["+k+"] NEXT 1: next: "+cursor.element.userName()+" at "+cursor.segment.tick);
							 success = cursor.next();
						 }
						

						
						if(success) {
							// if we have found a next rest, we check if 
							// - either this rest is enough for the duration of what we have to write
							// - there is a measure following
							// In the contrary, we add a new measure
							console.log("--["+k+"] NEXT 2: last next: "+cursor.element.userName()+" at "+cursor.segment.tick);
							var remaining=computeRemainingRest(cursor.measure, cursor.track); //, cursor.segment.tick);
							var needed = durationTo64(fduration);
							success=((cursor.measure.nextMeasure!==null) || (needed<=remaining));

							console.log("?? could move to next segment, ==> checking if enough place or a next measure ("+(cursor.measure.nextMeasure?"next measure":"null")+" -- "+needed+"<>"+remaining+") => "+success);
						} else {
							console.log("--["+k+"] NEXT 2: last next: not found");
						}
						
                        if (!success) {
							// If the measure is full or doesn't have enough place, we add a new measure
							console.log("--["+k+"] NEXT 3: adding a new measure");
                            score.appendMeasures(1);
                            cursor.rewindToTick(cur_time);

                            if (newLine) {
                                var measure = cursor.measure;
                                console.log("Delayed change of ending bar line");
                                addDoubleLineBar(measure, score);
                            }

                            cursor.next();
							console.log("--["+k+"] NEXT 4: after new measure: "+cursor.element.userName()+" at "+cursor.segment.tick);
						}
                    }

                    var note = cursor.element;
					cur_time = cursor.segment.tick;

					console.log("--["+k+"] NEXT 5: adding note/rest at "+cursor.segment.tick);
			
                    var delta = pages[i][j].notes[k].note;
					
					if (delta !== null) {
					    // Note

					    var pitch = instru.cpitch + delta;
					    var sharp_mode = true;
					    var f = (chord.sharp !== undefined) ? chord.sharp : _chords[root][mode]; // si un mode est spécifié on l'utilise sinon on prend celui par défaut
					    if (f !== undefined)
					        sharp_mode = f;

					    var target = {
					        "pitch": pitch,
					        "concertPitch": false,
					        "sharp_mode": f
					    };

					    //cur_time = note.parent.tick; // getting note's segment's tick

					    note = NoteHelper.restToNote(note, target,fduration);

					} else {
					    // Rest
					    //2.4.0 change adapt rest to the right duration
						console.log("...of "+fduration.str);
						cursor.setDuration(fduration.numerator,fduration.denominator);
						cursor.addRest();
						cursor.rewindToTick(cur_time);
						note=cursor.element
					}
					
                    // Adding a key signature
                    // TODO: finalize
                    /*if (chord.key && (k == 0)) {
                        var keysig = newElement(Element.KEYSIG);
                        //keysig.layoutBreakType = 1; //line break
                        cursor.add(keysig);
                    }*/

                    // Adding the chord's name

                    if (prevChord.symb !== chord.symb || prevChord.name !== chord.name || prevRoot !== root) {
                        var csymb = newElement(Element.HARMONY);
                        if (chord.name !== undefined) {
                            // preferred name set. Using it.
                            csymb.text = chord.name;
                        } else {
                            // no preferred name set. Just a root(pitch). Computing a name.
                            csymb.text = rootToName(root, sharp_mode, chord.symb);
                        }

                        //note.parent.parent.add(csymb); //note->chord->segment
                        cursor.add(csymb); //note->chord->segment


                    }

                    // Adding the pattern description
                    if (((i !== prevPage) || ((k == 0) && (j > 0) && (pages[i][j].representation != pages[i][j - 1].representation))) || newLine) {
                        var ptext = newElement(Element.STAFF_TEXT);
                        var t = "";
                        ptext.text = pages[i][j].representation;
                        cursor.add(ptext);

                    }

                    // Adding the signature change if needed (must be done **after** a note has been added to the new measure.
                    if ((beatsByMeasure != prevBeatsByM) || newLine) {
                        console.log("Adapting measure to " + beatsByMeasure + "/4  (#2)");
                        var ts = newElement(Element.TIMESIG);
                        ts.timesig = fraction(beatsByMeasure, 4);
                        cursor.add(ts);
                        //cursor.rewindToTick(cur_time); // be sure to move to the next rest, as now defined
                        //cursor.next();
                        prevBeatsByM = beatsByMeasure;
                    }

                    // Adding a Line break if required by a "|"
                    if (chord.end && (k == (pages[i][j].notes.length - 1))) {

                        var lbreak = newElement(Element.LAYOUT_BREAK);
                        lbreak.layoutBreakType = 1; //line break
                        cursor.add(lbreak);
                    }

                    //debugNote(delta, note);
					

                    prevRoot = root;
                    prevChord = chord;
                    prevMode = mode;
                    prevPage = i;
                    newLine = false;

                }

				
                // Fill with rests until end of measure
                if (chkStrictLayout.checked) {
					var total=patternDuration(pages[i][j].notes);
                    var fill = total % beatsByMeasure;
                    if (fill > 0) {
                        //fill = 4 - fill;
                        console.log("Going to fill from :" + fill);
                        for (var f = fill; f < beatsByMeasure; f++) {
                            cursor.rewindToTick(cur_time); // rewing to the last note
                            var success = cursor.next(); // move to the next position
                            if (success) { // if we haven't reach the end of the part, add a rest, otherwise that's just fine
                                cursor.setDuration(1, 4); // quarter
                                cursor.addRest();
                                if (cursor.segment)
                                    cur_time = cursor.segment.tick;
                                else
                                    cur_time = score.lastSegment.tick
                            }
                        }
                    }
                }
            }

        }

        score.endCmd();

    }

	/**
	a pattern described as :
			"notes": array of {"note": integer/null, "durarion": float }; "null" is for rest
            "loopAt": mode,
            "chord": { "symb": text, "scale": [0, 2, 4, 5, 7, 9, 11, 12], "mode": "major"|"minor" }
            "name": text
	*/		
	
    function extendPattern(pattern) {
        var extpattern = pattern;
        var basesteps = pattern.notes;
        var scale = pattern.chord.scale;
        var loopAt = pattern.loopAt;
		var lastrest=null;
		
		if (basesteps[basesteps.length-1].note===null) {
			lastrest=basesteps.pop();
		}

        extpattern.representation = (pattern.name && pattern.name !== "") ? pattern.name : patternToString(pattern.notes, pattern.loopAt);

        extpattern["subpatterns"] = [];
		
		debugO("before",basesteps);


        // first the original pattern


        // looping patterns

        if ((loopAt.type == 1) && (Math.abs(loopAt.shift) < basesteps.length) && (loopAt.shift != 0)) {
            // 1) Regular loopAt mode, where we loop from the current pattern, restarting the pattern (and looping)
            // from the next step of it : A-B-C, B-C-A, C-A-B
            console.log("--Looping patterns : shift mode--");
			
			// reducing the basesteps to only the 1) the notes (and dropping the rests) 2) only the notes (not taking care of the durations)
			var reduced=basesteps.filter(function(e) { return e.note!==null}).map(function(e) { return e.note});

            // octave up or down ? Is the pattern going up or going down ?
            var pattdir = 1;
			var b0=reduced[0];
			var bn=reduced[reduced.length - 1];
            if (b0 > bn)
                pattdir = -1; // first is higher than last, the pattern is going down
            else if (b0 == bn)
                pattdir = 0; // first is equal to last, the pattern is staying flat



            // We'll tweak the original pattern one to have flowing logically among the subpatterns
            /*if (((loopAt.shift > 0) && (pattdir < 0)) || ((loopAt.shift < 0) && (pattdir > 0))) {
            // En mode decreasing, je monte toute la pattern d'une octave
            for (var i = 0; i < basesteps.length; i++) {
            basesteps[i] = basesteps[i] + 12;
            }
            }*/
            if ((pattdir < 0)) {
                // En mode decreasing, je monte toute la pattern d'une octave
                for (var i = 0; i < reduced.length; i++) {
                    reduced[i] = reduced[i] + 12;
                }
            }

            var e2e = false;
            var e2edir = 0;
            var notesteps = [].concat(reduced); // clone basesteps to not alter the gloable pattern (shallow copy is ok here)
            if ((Math.abs(b0 - bn) == 12) || (b0 == bn)) {
                //
                e2e = true;
                e2edir = (bn - b0) / 12; // -1: C4->C3, 0: C4->C4, 1: C4->C5
                notesteps.pop(); // Remove the last step
            }

            var debug = 0;
            var from = (loopAt.shift > 0) ? 0 : (reduced.length - 1); // delta in index of the pattern for the regular loopAt mode
            while (debug < 999) {
                debug++;

                // Building next start point
                console.log("Regular Looping at " + from);

                // Have we reached the end ?
                if ((loopAt.shift > 0) && (from > 0) && ((from % reduced.length) == 0))
                    break;
                else if ((loopAt.shift < 0) && (from < 0))
                    break;

                var shifted = [];
                for (var j = 0; j < notesteps.length; j++) {
                    var idx = (from + j) % notesteps.length
                    var octave = Math.floor((from + j) / notesteps.length);
                    // octave up or down ? Is the pattern going up or going down ?
                    octave *= pattdir;

                    var _n = notesteps[idx] + octave * 12;
                    console.log(">should play " + notesteps[idx] + " but I'm playing " + _n + " (" + octave + ")");
                    shifted.push(_n);
                }
                if (e2e) {
                    // We re-add the first note
                    var _n = shifted[0] + 12 * e2edir;
                    shifted.push(_n);
                }

                // reinserting the rests and the durations
                var p = [];
                for (var j = 0; j < basesteps.length; j++) {
                    var _b = basesteps[j];
                    if (_b.note === null) {
                        shifted.splice(j, 0, null);
                    }
                    p.push({
                        note: shifted[j],
                        duration: basesteps[j].duration
                    });
                }

				// if there was a rest at the end reinserting it
                if (lastrest) {
                    p.push(lastrest);
                }
                extpattern["subpatterns"].push(p);

                from += loopAt.shift;

                }
        } else if (loopAt.type == 2) {
            // 2) REverse loopAt mode, we simply reverse the pattern
            console.log("-- Looping patterns : reverse mode --");

			if (lastrest) {
            extpattern["subpatterns"].push([].concat(basesteps).concat(lastrest));
			} else 
            extpattern["subpatterns"].push(basesteps);

			var reversed=reversePattern(basesteps);

			if (lastrest) {
				reversed.push(lastrest);
			}
			
			debugO("basesteps",basesteps); // debug
			debugO("reversed",reversed); // debug


            extpattern["subpatterns"].push(reversed);
			
        } else if (loopAt.type == -1) {
            // 3) Scale loopAt mode, we decline the pattern along the scale (up/down, by degree/Triad)
            console.log("Looping patterns : scale mode (" + shift + ") --");
            var shift = loopAt.shift; //Math.abs(loopAt) * (-1);
            // We clear all the patterns because will be restarting from the last step
            extpattern["subpatterns"] = [];

            // Building the other ones
            var counter = 0;
            var dia = [];
            var delta = Math.abs(shift);
            // we compute the degree to have III V VII
            for (var i = 0; i < scale.length; i += delta) {
                console.log("Adding " + i + " (" + scale[i] + ")");
                dia.push(i);
            }

            // if we have a scale ending on a tonic (I - 12), and our steps have stopped before (ex the next triad after the VII is the II, not the I)
            // we add it explicitely
            if ((scale[scale.length - 1] == 12) && (dia[dia.length - 1] < (scale.length - 1))) {
                dia.push(scale.length - 1); // the repetition must end with the last step of the scale (the one that holds "12")
            }
            if (shift > 0) {
                // we loop it
                for (var i = 0; i < dia.length; i++) {
                    counter++;
                    console.log("Looping patterns : scale mode at " + dia[i]);
                    var shifted = shiftPattern(basesteps, scale, dia[i]);
					if (lastrest) {
						shifted.push(lastrest);
					}
					
                    extpattern["subpatterns"].push(shifted);
                    if (counter > 99) // security
                        break;
                }
            } else {

                // we loop it in reverse
                for (var i = (dia.length - 1); i >= 0; i--) {
                    counter++;
                    console.log("Looping patterns : scale mode at " + dia[i]);
                    var shifted = shiftPattern(basesteps, scale, dia[i]);
					if (lastrest) {
						shifted.push(lastrest);
					}
                    extpattern["subpatterns"].push(shifted);
                    if (counter > 99) // security
                        break;
                }
            }

        } else {
            console.log("-- Looping patterns : no loop requested --");
			if (lastrest) {
				basesteps.push(lastrest);
			}
            extpattern["subpatterns"].push(basesteps);

        }

        return extpattern;

    }
	
	function reversePattern(pattern) {
	    var reduced = pattern.filter(function (e) {
	        return e.note !== null
	    }).map(function (e) {
	        return e.note
	    });

	    reduced = reduced.reverse();

	    var p = [];

	    // reinserting the rests and the durations
	    var p = [];
	    for (var j = 0; j < pattern.length; j++) {
	        var _b = pattern[j];
	        if (_b.note === null) {
	            reduced.splice(j, 0, null);
	        }
	        p.push({
	            note: reduced[j],
	            duration: pattern[j].duration
	        });
	    }
	    return p;

	}

    function shiftPattern(pattern, scale, step) {
        var pdia = [];
        // 1) convert a chromatic pattern into a diatonic pattern
        for (var ip = 0; ip < pattern.length; ip++) {
            // for every step of the pattern we look for its diatonic equivalent.
            // And a delta. For a b5, while in major scale, we will retrieve a degree of "4" + a delta of 1 semitone
            var d = undefined;
            var p = pattern[ip].note;
			if(p!==null) {
            var o = Math.floor(p / 12);
            p = p % 12;
            for (var is = 0; is < scale.length; is++) {
                s = scale[is];
                if (s == p) {
                    d = {
                        "degree": is,
                        "semi": 0,
                        "octave": o
                    };
                    break;
                } else if (s > p) {
                    d = {
                        "degree": (is == 0) ? 0 : is - 1,
                        "semi": s - p,
                        "octave": o
                    };
                    break;
                }
            }

            if (d === undefined) {
                // if not found, it means we are beyond the last degree
                d = {
                    "degree": scale.length - 1,
                    "semi": p - scale[scale.length - 1],
                    "octave": o
                };

            }

		} else {
			d=null;
		}
            pdia.push(d);
			console.log("[shift " + step + "] 1)[" + ip + "]" + p + "->" + debugDia(d));
        }

        // 2) shift the diatonic pattern by the amount of steps
        for (var ip = 0; ip < pdia.length; ip++) {
            var d = pdia[ip];
			if (d!==null) {
            d.degree += step;
            d.octave += Math.floor(d.degree / 7); // degrees are ranging from 0->6, 7 is 0 at the nexy octave //scale.length);
            d.degree = d.degree % 7; //scale.length;
			}
            pdia[ip] = d;
            console.log("[shift " + step + "] 2)[" + ip + "]->" + debugDia(d));
        }

        // 3) Convert back to a chromatic scale
        var pshift = [];
        for (var ip = 0; ip < pdia.length; ip++) {
            var d = pdia[ip];
			var s=null;
			if(d!==null) {
            if (d.degree >= scale.length) {
                // We are beyond the scale, let's propose some value
                d.semi += (d.degree - scale.length + 1) * 1; // 1 semi-tone by missing degree
                d.degree = scale.length - 1;
                if ((scale[d.degree] + d.semi) >= 12)
                    d.semi = 11;
            }
            s = scale[d.degree] + 12 * d.octave + d.semi;
			} else {
				s=null;
			}
            pshift.push(s);
            console.log("[shift " + step + "] 3)[" + ip + "]" + debugDia(d) + "->" + s);
        }
		
		// 4) Reset the right durations
        for (var ip = 0; ip < pattern.length; ip++) {
			pshift[ip]={
				"note": pshift[ip],
				"duration": pattern[ip].duration
			};
		}
		
        return pshift;

    }

	function patternDuration(notes) {
		var count=0;
		for(var i=0; i<notes.length;i++) {
			count+=notes[i].duration;
			console.log("--- "+i+") "+notes[i].duration + " ==> total = "+count);
		}
		console.log("total pattern duration "+count);
		return count;
	}

    function signatureForPattern(notes) {
		var count=patternDuration(notes);
		
		count=Math.ceil(count);
		
        if ((count % 4) === 0)
            return 4;
        else if ((count % 3) === 0)
            return 3;
        else if ((count % 5) === 0)
            return 5;
        else
            return count;
    }

    function patternToString(pattern, loopAt) {
        var str = "";
        for (var i = 0; i < pattern.length; i++) {
			if (pattern[i].note===null) continue;
            if (str.length > 0)
                str += "/";
            var d = _degrees[pattern[i].note];
            if (d !== undefined) {
                d = d.replace("(", "");
                d = d.replace(")", "");
                str += d;
            } else {

                str += "?";
            }
        }

        if (loopAt.type != 0) {
            str += " - ";
            str += loopAt["short"];
        }

        return str;
    }

    function debugDia(d) {
		if (d!==null)         return "{degree:" + d.degree + ",semi:" + d.semi + ",octave:" + d.octave + "}";
		else return "{degree: null (=rest)}";
    }

    function filterTpcs(root, mode) {
        var sharp_mode = true;

        var f = _chords[root][mode];
        if (f !== undefined)
            sharp_mode = f;

        //console.log(_chords[root].root + " " + mode + " => sharp: " + sharp_mode);

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

    function rootToName(root, sharp_mode, chordsymb) {
        // no preferred name set. Just a root(pitch). Computing a name.
        var rtxt = _chords[root].root.replace(/♯/gi, '#').replace(/♭/gi, "b");
        var name;

        // chord's roots
        if (!rtxt.includes("/")) {
            name = rtxt;
        } else {
            var parts = rtxt.split("/");
            if (parts[0].includes("#")) {
                if (sharp_mode)
                    name = parts[0];
                else
                    name = parts[1]
            } else {
                if (sharp_mode)
                    name = parts[1];
                else
                    name = parts[0]
            }
        }

        // chord's type
        name += chordsymb;

        return name;

    }
    /**
     * Changes a ending measure bar line to a double one.
     * !! If the measure is the last one of the score, adding a new measure after will override this change.
     */
    function addDoubleLineBar(measure, score) {
        // The ending line bar for a measure added by the API is viewable only after the measure addition is enclosed in its own startCmd/endCmd
        if (score === undefined)
            score = curScore;
        score.endCmd();
        score.startCmd();

        var segment = measure.lastSegment;
        var bar = segment.elementAt(0);
        if (bar.type == Element.BAR_LINE) {
            bar.barlineType = 32;
            console.log("Last element is a barline (type=" + bar.userName() + ")");
        } else {
            console.log("Last element is not a barline (type=" + bar.userName() + ")");
        }

    }

    function debugNote(delta, n) {
        NoteHelper.enrichNote(n);
        console.log("delta:" + delta + ", pitch:" + n.pitch + ", tpc:" + n.tpc + ", name:" + n.extname.fullname);
    }

    function toClipboard(index, scaleMode) {
        if (scaleMode === undefined)
            scaleMode = (modeIndex() == 0);
        console.log("To Clipboard for pattern " + index);
        clipboard = getPattern(index, scaleMode);

    }

    function fromClipboard(index, scaleMode) {
        if (scaleMode === undefined)
            scaleMode = (modeIndex() == 0);

        if (clipboard === undefined)
            return;

        if (clipboard.type === (scaleMode ? _SCALE_MODE : _GRID_MODE)) {
            setPattern(index, clipboard, scaleMode);
        } else {
            console.log("Non matching clipboard. Expected " + (scaleMode ? _SCALE_MODE : _GRID_MODE) + ", while clipboard is: " + clipboard.type);
        }
    }

    function clearPattern(index, scaleMode) {
        setPattern(index, undefined, scaleMode)
    }

    function getPattern(index, scaleMode) {
        if (scaleMode === undefined)
            scaleMode = (modeIndex() == 0);

        var steps = [];
		var current=mpatterns.get(index);
        for (var i = 0; i < current.steps.count; i++) {
            var d = -1;
            if (scaleMode) {
                var note = current.steps.get(i).note;
                if (note !== '') {
                    d = _degrees.indexOf(note);
                }
            } else {
                var degree = current.steps.get(i).degree;
                if (degree !== '') {
                    d = _griddegrees.indexOf(degree);
                }
            }

            if (d > -1)
                steps.push(d);
            else
                break;
        }

        var p = new patternClass(steps, current.loopMode, current.chordType, current.pattName, (scaleMode ? _SCALE_MODE : _GRID_MODE), current.gridType);

        console.log(p.label);

        return p;

    }

    function setPattern(index, pattern, scaleMode) {
        if (scaleMode === undefined)
            scaleMode = (modeIndex() == 0);

        console.log("Setting pattern " + index + ", mode: " + (scaleMode ? _SCALE_MODE : _GRID_MODE)+", pattern: "+((pattern)?pattern.label:"undefined"));

        if (pattern !== undefined && pattern.type !== (scaleMode ? _SCALE_MODE : _GRID_MODE)) {
            console.log("!! Cannot setPattern due to non-matching pattern. Expected " + (scaleMode ? _SCALE_MODE : _GRID_MODE) + ", while pattern is: " + pattern.type);
            return;
        }

		var current=mpatterns.get(index);
        for (var i = 0; i < current.steps.count; i++) {
            var sn = current.steps.get(i);
            if (scaleMode) {
                var note = (pattern !== undefined && (i < pattern.steps.length)) ? _degrees[pattern.steps[i]] : '';
                sn.note = note;
            } else {
                var degree = (pattern !== undefined && (i < pattern.steps.length)) ? _griddegrees[pattern.steps[i]] : '';
                sn.degree = degree;
            }
        }

		current.chordType=((pattern !== undefined) && (pattern.scale !== undefined))?pattern.scale:'';
		current.loopMode=((pattern !== undefined) && (pattern.loopMode !== undefined))?pattern.loopMode:"--";
        current.pattName= ((pattern!== undefined) && (pattern.name!== undefined)) ? pattern.name : "";;
		current.gridType=((pattern!== undefined) && (pattern.gridType!== undefined))?pattern.gridType:"grid";

        // console.log("clearing the workout saved name");
        workoutName = undefined; // resetting the name of the workout. One has to save it again to regain the name


    }

    function savePattern(index, scaleMode) {
        if (scaleMode === undefined)
            scaleMode = (modeIndex() == 0);
        var p = getPattern(index, scaleMode);
        var i = findInLibrary(p);
        if (i < 0) { // pattern not found in library
            console.log("Pattern " + p.label + " added to the library (type " + p.type + ")");
            library.push(p);
            resetL = !resetL;
            saveLibrary();
        } else {
            console.log("Pattern " + p.label + " not added to the library - already present");
        }
    }

    function deletePattern(pattern, scaleMode) {
        if (scaleMode === undefined)
            scaleMode = (modeIndex() == 0);

        var i = findInLibrary(pattern);
        if (i >= 0) { // pattern found in library
            console.log("Pattern " + pattern.label + " deleted from the library (at " + i + ")");
            library.splice(i, 1);
            resetL = !resetL;
            saveLibrary();
        } else {
            console.log("Pattern " + pattern.label + " cannot be deleted from the library : not found");

        }

    }

    function findInLibrary(pattern) {
        for (var i = 0; i < library.length; i++) {
            var p = library[i];
            if (p.hash === pattern.hash) {
                return i;
            }
        }
        return -1;
    }

    function getPhrase(label) {

        var phraseText = txtPhrase.text;
        var phraseArray = phraseText.replace(endRegexp, '|;').split(";").map(function (e) {
            e = e.trim();
            return e;
        });
		
		var defaultSharp=undefined;

        var roots = phraseArray.map(function (ptxt) {

            var match = ptxt.match(keyRegexp); // --> ["(bbb)Abadd9|" ,"(bbb)" ,"bbb" ,"Abadd9" ,"|"]
            var end = match[4] === "|";
            var name = match[3];
            var key = match[2];
            if (key && key.includes("#")) {
                defaultSharp = true;
            } else if (key && key.includes("b")) {
                defaultSharp = false;
            } else if (key && (key.trim()==="")) { // vide 
                defaultSharp = undefined;
            } // else: je ne fais rien. Je garde la définition précédente

            var c = ChordHelper.chordFromText(name);
            if (c != null) {
                var isSharp = defaultSharp; // si l'accord n'a pas d'accidental on utilise la key signature
                if (c.accidental.startsWith("SHARP")) {
                    isSharp = true;
                }
                if (c.accidental.startsWith("FLAT")) {
                    isSharp = false;
                }
                var forPhrase = {
                    "root": c.pitch,
                    "type": c.name,
					"chordnotes": c.chordnotes,
					"bass": c.bass,
                    "sharp": isSharp,
                    "name": name,
                    "end": end,
                    "key": key,
                };
                debugO("Using chord : > ", forPhrase, ["scale"]);
                return forPhrase;
            } else {
                return null;
            }
        }).filter(function (chord) {
            return (chord != null);
        });

        var p = new phraseClass((label !== undefined) ? label : "", roots);

        console.log(p.label);

        return p;

    }

    function setPhrase(phrase) {
        //console.log("setPhrase: in: " + ((typeof phrase !== 'undefined') ? phrase.name : undefined));
        if (!phrase)
            phrase = new phraseClass("");
        //console.log("setPhrase: clear: " + ((typeof phrase !== 'undefined') ? phrase.name : undefined));
        var rr = phrase.chords;
        //debugO("setPhrase: chords", rr);
        var astext = rr.map(function (c) {
            var key = (c.key !== undefined) ? ("(" + c.key + ")") : "";
            var end = (c.end) ? "|" : ";";
            var name = (c.name !== undefined && c.name.trim() !== "") ? c.name : rootToName(c.root, true, c.type); // no easy way to know if we should use sharps or flats
            return key + name + end;

        }).join("");
        astext = astext.slice(0, astext.length - 1);

        console.log("Phrase as text: " + astext);

        txtPhrase.text = astext;

        resetR = false;
        resetR = true;

        rootSchemeName = phrase.name;
        console.log("rootSchemeName set to :" + rootSchemeName + ":");

    }

    /**
     * @return a conflicting phrase in the phrase list. Return null if no conflict identified.
     */
    function verifyPhrase(phrase, ask) {

        // 1) look for an existing workput with the same name
        var filtered;
        if (phrase.name !== "") {
            console.log(">>Comparing at name level (" + phrase.name + ")");
            filtered = phrases.filter(function (w) {
                return (w.name !== "" && w.name.localeCompare(phrase.name) === 0);
            });
            if (filtered.length > 0) {
                console.log(">>Got a conflict at name level (" + filtered[0].name + ")");
                if (ask) {
                    confirmReplaceWorkoutDialog.origworkout = filtered[0];
                    confirmReplaceWorkoutDialog.newworkout = phrase;
                    confirmReplaceWorkoutDialog.state = "phrase";
                    confirmReplaceWorkoutDialog.open();
                }
                return filtered[0];
            }
        }
        // 2) looking for a phrase with the same chords
        console.log(">>Comparing at hash level (" + phrase.hash + ")");
        filtered = phrases.filter(function (w) {
            return w.hash == phrase.hash;
        });

        if (filtered.length > 0) {
            console.log(">>Got a conflict at hash level (" + filtered[0].hash + ")");
            if (ask) {
                confirmReplaceWorkoutDialog.origworkout = filtered[0];
                confirmReplaceWorkoutDialog.newworkout = phrase;
                confirmReplaceWorkoutDialog.state = "phrase";
                confirmReplaceWorkoutDialog.open();
            }
            return filtered[0];
        }

        return null;

    }

    function emptyPhrase() {
        setPhrase(undefined);
    }

    /**
     * Simply adds that phrase on top of the phrases list. No verification of duplicates is performed.
     */
    function savePhrase(phrase) {
        phrases.push(phrase);
        resetL = !resetL;
        saveLibrary();
        // workoutName = phrase.name; // 14/12/21: incorrect
        lastLoadedPhraseName = phrase.name;
        rootSchemeName = phrase.name;
    }

    /**
     * Replace a phrase by another. Might be another name or another definition.
     */
    function replacePhrase(oldPhrase, newPhrase) {
        for (var i = 0; i < phrases.length; i++) {
            console.log(phrases[i].name + " (" + phrases[i].hash + ") <> " + oldPhrase.name + " (" + oldPhrase.hash + ")");
            if (phrases[i].hash == oldPhrase.hash) {
                console.log("REPLACING THIS ONE");
                phrases[i] = newPhrase;
                break;
            }
        }
        resetL = !resetL;
        saveLibrary();
    }

    function deletePhrase(phrase) {
        for (var i = 0; i < phrases.length; i++) {
            if (phrases[i].hash == phrase.hash) {
                phrases.splice(i, 1);
                break;
            }
        }
        resetL = !resetL;
        saveLibrary();
    }

    function getPhraseFromSelection() {
        var score = curScore;

        if (score == null) {
            console.log("no score");
            cannotFetchPhraseFromSelectionDialog.message = "No current score";
            cannotFetchPhraseFromSelectionDialog.open();
            return;
        }

        var chords = SelHelper.getChordsRestsFromCursor();

        if (chords && (chords.length > 0)) {
            console.log("CHORDS FOUND FROM CURSOR");
        } else {
            chords = SelHelper.getChordsRestsFromSelection();
            if (chords && (chords.length > 0)) {
                console.log("CHORDS FOUND FROM SELECTION");
            } else {
                chords = SelHelper.getChordsRestsFromScore();
                console.log("CHORDS FOUND FROM ENTIRE SCORE");
            }
        }

        if (!chords || (chords.length == 0)) {
            console.log("no selection");
            cannotFetchPhraseFromSelectionDialog.message = "No selection.";
            cannotFetchPhraseFromSelectionDialog.open();
            return;
        }

        // Notes and Rests
        var prevSeg = null;
        var prevChord = null;
        var grid = [];
        for (var i = 0; i < chords.length; i++) {
            var el = chords[i];
            var seg = el.parent;
            //console.log(i + ")" + el.userName() + " / " + seg.segmentType);

            // Looking for new Chord symbol
            if (!prevSeg || (seg && (seg !== prevSeg))) {
                // nouveau segment, on y cherche un accord
                prevSeg = seg;

                var annotations = seg.annotations;
                //console.log(annotations.length + " annotations");
                if (annotations && (annotations.length > 0)) {
                    for (var j = 0; j < annotations.length; j++) {
                        var ann = annotations[j];
                        //console.log("  (" + i + ") " + ann.userName() + " / " + ann.text + " / " + ann.harmonyType);
                        if (ann.type === Element.HARMONY && ann.harmonyType === HarmonyType.STANDARD ) { // Not using the Roman and Nashvill Harmony types 
                            // keeping 1st Chord
                            var c = ChordHelper.chordFromText(ann.text);
                            if (c != null) {
                                var isSharp = undefined; // si accidental==NONE on garde `undefined`
                                if (c.accidental.startsWith("SHARP")) {
                                    isSharp = true;
                                }
                                if (c.accidental.startsWith("FLAT")) {
                                    isSharp = false;
                                }
                                var forPhrase = {
                                    "root": c.pitch,
                                    "type": c.name,
                                    "sharp": isSharp,
                                    "name": ann.text
                                };

                                debugO("Using chord : > ", forPhrase, ["scale"]);
                                if ((prevChord===null) || (prevChord.root !== forPhrase.root) || (prevChord.type !== forPhrase.type)) {
                                    prevChord = forPhrase;
									console.log("ADD IT");
                                    grid.push(forPhrase);
                                }
                                break;
                            }
                        }
                    }
                }
            }

        }

        if (grid.length == 0) {
            console.log("no chords");
            cannotFetchPhraseFromSelectionDialog.message = "No chords text found in the selection";
            cannotFetchPhraseFromSelectionDialog.open();
            return;
        }

        // building and pushing to gui the phrase
        var name = score.title;
        if (!name || name == "")
            name = undefined;
        //console.log("TITLE:"+score.title+":"+name+":");
        var phrase = new phraseClass(name, grid);

        setPhrase(phrase);

    }

    function applyWorkout(workout) {

        var log = ((workout === undefined) ? "Null" : workout.label);
        if (workout !== undefined)
            log += ", mode: " + workout.type;
        console.log("Applying workout " + log);
        // debugO("Workout", workout);

        // patterns
        var m = (workout !== undefined) ? Math.min(_max_patterns, workout.patterns.length) : 0;

        for (var i = 0; i < m; i++) {
            setPattern(i, workout.patterns[i]);
        }

        for (var i = m; i < _max_patterns; i++) {
            setPattern(i, undefined);
        }

        // roots/phrase
        if (workout !== undefined && (workout.type === _SCALE_MODE)) {
            // SCALE workout. If the roots are defined
            if (workout.roots !== undefined) {
                m = Math.min(_max_roots, workout.roots.length);

                for (var i = 0; i < m; i++) {
                    idRoot.itemAt(i).currentIndex = _ddRoots.indexOf(_roots[workout.roots[i]]); // id --> label --> indexOf dans le tableau de présentation
                }

                for (var i = m; i < _max_patterns; i++) {
                    idRoot.itemAt(i).currentIndex = 0;
                }
            }

        } else if (workout !== undefined && (workout.type === _GRID_MODE)) {
            // GRID workout. If the phrase is defined
            if (workout.phrase !== undefined)
                setPhrase(workout.phrase);
        } else {
            setPhrase(undefined);
        }

        // options, if defined in the workout
        if (workout !== undefined && workout.bypattern !== undefined) {
            chkByPattern.checkState = (workout.bypattern === "true") ? Qt.Checked : Qt.Unchecked;

        }
        if (workout !== undefined && workout.invert !== undefined) {
            chkInvert.checkState = (workout.invert === "true") ? Qt.Che.cked : Qt.Unchecked;
        }

        workoutName = (workout !== undefined) ? workout.name : undefined;

    }

    function buildWorkout(label, withPhrase) {

        withPhrase = (withPhrase) ? true : false;

        var pp = [];
        for (var i = 0; i < _max_patterns; i++) {
            var p = getPattern(i);
            if (p.steps.length == 0 && p.gridType === 'grid')
                break;
            pp.push(p);
        }

        var workout;
        if (modeIndex() == 0) {
            workout = new workoutClass(label, pp, undefined, chkByPattern.checked, chkInvert.checked);
        } else {
            var phrase = (withPhrase) ? getPhrase() : undefined;
            workout = new gridWorkoutClass(label, pp, phrase, chkByPattern.checked, chkInvert.checked);

        }
        return workout;
    }

    /**
     * @return a conflicting workout in the workouts list. Return null if no conflict identified.
     */
    function verifyWorkout(workout, ask) {

        // 1) look for an existing workput with the same name
        var filtered = workouts.filter(function (w) {
            return (w.name.localeCompare(workout.name) == 0);
        });
        if (filtered.length > 0) {
            if (ask) {
                confirmReplaceWorkoutDialog.origworkout = filtered[0];
                confirmReplaceWorkoutDialog.newworkout = workout;
                confirmReplaceWorkoutDialog.open();
            }
            return filtered[0];
        }
        // 2) looking for a workoout with the same patterns
        filtered = workouts.filter(function (w) {
            return w.hash == workout.hash;
        });
        console.log("workouts <> " + workout.name + ": " + filtered.length);

        if (filtered.length > 0) {
            if (ask) {
                confirmReplaceWorkoutDialog.origworkout = filtered[0];
                confirmReplaceWorkoutDialog.newworkout = workout;
                confirmReplaceWorkoutDialog.open();
            }
            return filtered[0];
        }

        return null;

    }

    function emptyAll() {
        applyWorkout(undefined);
    }

    /**
     * Simply adds that workout on top of the workouts list. No verification of duplicates is performed.
     */
    function saveWorkout(workout) {

        debugO("Workout à sauver", workout);

        workouts.push(workout);
        resetL = !resetL;
        saveLibrary();
        workoutName = workout.name;

        if (workout.type == _SCALE_MODE) {
            lastLoadedWorkoutName = workout.name;
        } else {
            lastLoadedGridWorkoutName = workout.name;
        }

    }
    /**
     * Simply adds that workout on top of the workouts list. No verification of duplicates is performed.
     */
    function replaceWorkout(oldWorkout, newWorkout) {
        for (var i = 0; i < workouts.length; i++) {
            //console.log(workouts[i].name + " (" + workouts[i].hash + ") <> " + oldWorkout.name + " (" + oldWorkout.hash + ")");
            if (workouts[i].hash == oldWorkout.hash) {
                console.log("REPLACING THIS ONE");
                workouts[i] = newWorkout;
                break;
            }
        }
        resetL = !resetL;
        saveLibrary();

        workoutName = newWorkout.name;

        if (newWorkout.type == _SCALE_MODE) {
            lastLoadedWorkoutName = newWorkout.name;
        } else {
            lastLoadedGridWorkoutName = newWorkout.name;
        }
    }

    function deleteWorkout(workout) {
        for (var i = 0; i < workouts.length; i++) {
            if (workouts[i].hash == workout.hash) {
                workouts.splice(i, 1);
                break;
            }
        }
        resetL = !resetL;
        saveLibrary();
    }

    function loadLibrary() {

        console.log("Loading library " + libraryFile.source);
        if (!libraryFile.exists()) {
            console.log("file not found");
            return;

        }

        var json = libraryFile.read();

        var lib = {};

        try {
            lib = JSON.parse(json);
        } catch (e) {
            console.error('while reading the library file', e.message);
        }

        // 1) Les patterns
        var allpresets = lib.patterns;
        library = [];
        if (allpresets !== undefined) {
            for (var i = 0; i < allpresets.length; i++) {
                var pp = allpresets[i];
                var p = new patternClassRaw(pp);
                library.push(p);
            }
        }
        console.log("Library loaded");

        //2) Les phrases
        var allphrases = lib.phrases;

        phrases = [];
        if (allphrases !== undefined) {
            for (var i = 0; i < allphrases.length; i++) {
                var pp = allphrases[i];
                var p = new phraseClassRaw(pp);
                phrases.push(p);
            }
        }
        console.log("Phrases loaded");

        // 3) Les workouts
        var allworkouts = lib.workouts;
        workouts = [];
        if (allworkouts !== undefined) {
            for (var i = 0; i < allworkouts.length; i++) {
                var pp = allworkouts[i];
                var p = new workoutClassRaw(pp);
                workouts.push(p);
            }
        }
        workouts = workouts.sort(function (a, b) {
            return a.label.localeCompare(b.label);
        });

        console.log("Workouts loaded");

        resetL = !resetL;
    }

    function saveLibrary() {

        workouts = workouts.sort(function (a, b) {
            return a.label.localeCompare(b.label);
        });

        var lib = {
            patterns: library,
            workouts: workouts,
            phrases: phrases
        };

        var t = JSON.stringify(lib) + "\n";
        console.log(t);

        if (libraryFile.write(t)) {
            console.log("Library saved");
        } else {
            console.log("Error while saving the library");
        }
    }

    property bool resetR: true // Reset roots
    property bool resetP: true // Reset patterns grid
    property bool resetL: true // Reset library

    GridLayout {
        anchors.fill: parent
        anchors.margins: 25
        columnSpacing: 10
        rowSpacing: 10
        columns: 2

        SystemPalette {
            id: systemPalette;
            colorGroup: SystemPalette.Active
        }

        GroupBox {
            title: "Mode selection..."
            id: grpModes

            Layout.columnSpan: 2
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: 0
            Layout.bottomMargin: 10
            topPadding: 10
            bottomPadding: 10
            rightPadding: 20
            leftPadding: 20

            // Layout.preferredHeight: layModes.height + padding * 2 + labMode.height / 2

            background: Rectangle {
                id: r100
                y: grpModes.topPadding - grpModes.bottomPadding
                width: parent.width
                implicitHeight: layModes.height + grpModes.padding * 2
                border.color: "#929292"
                color: "transparent"
                radius: 5
            }

            label:
            Rectangle {
                x: grpModes.leftPadding
                y: grpModes.topPadding - grpModes.bottomPadding - labMode.height / 2
                implicitWidth: labMode.width + 12
                implicitHeight: labMode.height
                color: systemPalette.window
                Label {
                    id: labMode
                    x: 6
                    // width: grpModes.availableWidth
                    text: grpModes.title
                    elide: Text.ElideRight
                }
            }
            RowLayout {
                id: layModes
                ButtonGroup {
                    id: bar
                }
                NiceRadioButton {
                    id: rdbScale
                    text: qsTr("Scale workout")
                    checked: true
                    ButtonGroup.group: bar
                }
                NiceRadioButton {
                    id: rdbGrid
                    text: qsTr("Grid workout")
                    ButtonGroup.group: bar
                }
            }
        }
        GridLayout { // un small element within the fullWidth/fullHeight where we paint the repeater
            //anchors.verticalCenter : parent.verticalCenter
            id: idNoteGrid
            rows: _max_patterns + 1
            // columns: _max_steps + 6
            columnSpacing: 0
            rowSpacing: 0

            Layout.columnSpan: 2
            Layout.alignment: Qt.AlignCenter
            Layout.fillHeight: false

            //Layout.preferredWidth : _max_steps * 20
            //Layout.preferredHeight : (_max_patterns + 1) * 20

            Repeater {
                id: idPatternLabels
                model: _max_patterns

                Label {
                    Layout.row: index + 1
                    Layout.column: 0
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    Layout.rightMargin: 10
                    Layout.leftMargin: 2
                    text: "Pattern " + (index + 1) + ":"
                }
            }
			
			

			Label {// v2.3.0
				Layout.row: 0
				Layout.column: 1 
				Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
				Layout.rightMargin: 1
				Layout.leftMargin: 1
				Layout.bottomMargin: 5
				text: "C.N."
				visible: modeIndex()!=0

			}

            Repeater { // 2.3.0
                id: idGridTypes
                model: mpatterns

				
				ComboBox {
                    //Layout.fillWidth : true
					id: lstGridType

                    model: _gridTypes
					
					textRole: "label" 
					property var imageRole: "image"
					property var valueRole: "type"


					onActivated: {
					    // loopMode = currentValue;
					    gridType = model[currentIndex][valueRole];
					    console.log(gridType);
					}

					Binding on currentIndex {
					    value: {
							var ci=_gridTypes.map(function(e) { return e[valueRole] }).indexOf(gridType);
							ci;
						}
					}
					
					visible: modeIndex()!=0

					property var _row: index + 1
					property var _column: 1
                    Layout.row: _row
                    Layout.column: _column 

                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    Layout.rightMargin: 0
                    Layout.leftMargin: 0

                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 30 + indicator.width

                    delegate: ItemDelegate { // requiert QuickControls 2.2
                        contentItem: Image {
                            height: 25
                            width: 25
                            source: "./workoutbuilder/" + modelData[imageRole]
                            fillMode: Image.Pad
                            verticalAlignment: Text.AlignVCenter
                            ToolTip.text: modelData[textRole]
                            ToolTip.delay: tooltipShow
                            ToolTip.timeout: tooltipHide
                            ToolTip.visible: hovered
                        }
                        highlighted: lstGridType.highlightedIndex === index

                    }

                    contentItem: Image {
                        height: 25
                        width: 25
                        fillMode: Image.Pad
                        source: "./workoutbuilder/" +model[lstGridType.currentIndex][imageRole]

                        ToolTip.text: lstGridType.displayText
                        ToolTip.delay: tooltipShow
                        ToolTip.timeout: tooltipHide
                        ToolTip.visible: hovered

                    }

                }

				
            }
			
				
            Repeater {
                id: idNoteLabels
                model: _max_steps

                RowLayout {
                    Layout.row: 0
                    Layout.column: index + 2 // v2.3.0
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                    Layout.rightMargin: 2
                    Layout.leftMargin: 2
                    Layout.bottomMargin: 5

                    property var stepIndex: index

                    Label {
                        text: (index + 1)
                    }
                    ComboBox {
                        id: lstStepDuration
                        model: durations

                        textRole: "text"
                        property var valueRole: "duration"
                        property var duration: 1

                        onActivated: {
                            // loopMode = currentValue;
                            duration = model[currentIndex][valueRole];
                            console.log(duration);

                            for (var i = 0; i < _max_patterns; i++) {
                                var raw = mpatterns.get(i);

                                // console.log("Setting duration of step/pattern "+index+"/"+i+" to "+duration);

                                raw.steps.get(stepIndex).duration = duration;
                            }

                        }

                        Binding on currentIndex {
                            value: durations.map(function (e) {
                                return e[lstStepDuration.valueRole]
                            }).indexOf(lstStepDuration.duration);
                        }

                        implicitHeight: 30
                        implicitWidth: 50

                        font.family: 'MScore Text'
                        font.pointSize: 10

                        delegate: ItemDelegate {
                            contentItem: Text {
                                text: modelData[lstStepDuration.textRole]
                                verticalAlignment: Text.AlignVCenter
                                font: lstStepDuration.font
                            }
                            highlighted: durations.highlightedIndex === index

                        }
                        indicator: Canvas {
                            id: canvas
                            x: lstStepDuration.width - width - lstStepDuration.rightPadding
                            y: lstStepDuration.topPadding + (lstStepDuration.availableHeight - height) / 2
                            width: 8
                            height: width * 1.5

                            contextType: "2d"

                            Connections {
                                target: lstStepDuration
                                function onPressedChanged() {
                                    canvas.requestPaint();
                                }
                            }

                            onPaint: {
                                context.reset();
                                context.lineWidth = 1.5;
                                context.strokeStyle = "black";
                                context.beginPath();
                                context.moveTo(0, height / 2 - 1);
                                context.lineTo(width / 2, 0);
                                context.lineTo(width, height / 2 - 1);
                                context.stroke();
                                context.beginPath();
                                context.moveTo(0, height / 2 + 1);
                                context.lineTo(width / 2, height);
                                context.lineTo(width, height / 2 + 1);
                                context.stroke();
                            }
                        }
                    }
                }
                }
                Repeater {
                    id: idStepNotes
                    model: mpatterns

                    Repeater {

                        id: idSingleStep
                        property var patternIndex: index

                        model: steps
					
					// Row {
						StackLayout {
					
							width: parent.width
							property var stepIndex: index
							property var _row: patternIndex + 1
							property var _column: 2 + stepIndex
							Layout.row: _row
							Layout.column: _column 
							Layout.preferredHeight: 30
							// Layout.maximumHeight: 30
							Layout.preferredWidth: 50
							
							// spacing: 2  // specific to "Row"

						// StackLayout {
							// width: 60

							currentIndex: modeIndex()
							
							ComboBox {
							    id: lstStep
							    model: _ddNotes

							    textRole: "text"
							    property var valueRole: "step"

							    onActivated: {
							        note = model[currentIndex][valueRole];
							        console.log(note);
							    }

							    Binding on currentIndex {
							        value: {
										_ddNotes.map(function (e) {
							            return e[lstStep.valueRole]
							        }).indexOf(note);
									}
							    }

							    editable: false
							    implicitWidth: 30
								
								// font.family: "FreeSerif"

							    delegate: ItemDelegate {
							        contentItem: Text {
							            text: modelData[lstStep.textRole]
							            // textFormat: Text.RichText
										anchors.verticalCenter: parent.verticalCenter
							            font: lstStep.font
							        }
							        highlighted: lstStep.highlightedIndex === index

							    }

							    contentItem: Text {
							        text: lstStep.displayText
							        // textFormat: Text.RichText
									verticalAlignment: Text.AlignVCenter
									anchors.verticalCenter: parent.verticalCenter
							        horizontalAlignment: Qt.AlignHCenter
							    }
								

								
							}
							ComboBox {
							    id: lstGStep

								model: _ddGridNotes

								enabled: gridType==="grid"

                                // Roles in the ComboBox model
							    textRole: "text"
							    property var valueRole: "step"

								onActivated: {
									console.log("degree at "+stepIndex+" of "+patternIndex+": "+degree);
									degree = model[currentIndex][valueRole];
									workoutName = undefined; // resetting the name of the 
									console.log("==> now degree: "+degree);
								}
								
								Binding on currentIndex {
									// value: lstGStep.model.indexOf(degree)
							        value: {
										_ddGridNotes.map(function (e) {
							            return e[lstGStep.valueRole]
                                    }).indexOf(degree);
									}
								}


								editable: false
								Layout.alignment: Qt.AlignLeft | Qt.QtAlignBottom
								implicitWidth: 30
								
							    delegate: ItemDelegate {
							        contentItem: Text {
							            text: modelData[lstGStep.textRole]
							            // textFormat: Text.RichText
										anchors.verticalCenter: parent.verticalCenter
							            font: lstGStep.font
							        }
							        highlighted: lstStep.highlightedIndex === index

							    }

							    contentItem: Text {
							        text: lstGStep.displayText
							        // textFormat: Text.RichText
									verticalAlignment: Text.AlignVCenter
									anchors.verticalCenter: parent.verticalCenter
							        horizontalAlignment: Qt.AlignHCenter
							    }
								
							}
						}
						
					    /*ComboBox {
					        id: lstNoteDuration
					        model: durations

					        textRole: "text"
					        property var valueRole: "duration"

					        onActivated: {
					            // loopMode = currentValue;
					            duration = model[currentIndex][valueRole];
					            console.log(duration);
					        }

					        Binding on currentIndex {
					            value: durations.map(function (e) {
					                return e[lstNoteDuration.valueRole]
					            }).indexOf(duration);
					        }

					        implicitHeight: 30
					        implicitWidth: 60

					        font.family: 'MScore Text'
					        font.pointSize: 8

					        delegate: ItemDelegate {
					            contentItem: Text {
					                text: modelData[lstNoteDuration.textRole]
					                verticalAlignment: Text.AlignVCenter
					                font: lstNoteDuration.font
					            }
					            highlighted: durations.highlightedIndex === index

					        }

					    }*/
					// }
				}
			}

			Label {
				Layout.row: 0
				Layout.column: _max_steps + 3 // v2.3.0
				Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
				Layout.rightMargin: 2
				Layout.leftMargin: 2
				Layout.bottomMargin: 5
				text: "Repeat"
			}

            Repeater {
                id: idLoopingMode
                model: mpatterns

                ComboBox {
                    //Layout.fillWidth : true
                    id: lstLoop
                    model: _loops
					
					textRole: "label" 
					property var imageRole: "image"
					property var valueRole: "id"
					
					onActivated: {
                        // loopMode = currentValue;
                        loopMode = model[currentIndex][valueRole];;
                        console.log(loopMode);
                    }

                    Binding on currentIndex {
					    value: {
							var ci=model.map(function(e) { return e[valueRole] }).indexOf(loopMode);
							ci;
						}
                    }

                    //clip: true
                    //focus: true
					property var _row: index + 1
					property var _column: steps.count + 3
                    Layout.row: _row
                    Layout.column: _column 
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                    Layout.rightMargin: 2
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 80

                    delegate: ItemDelegate { // requiert QuickControls 2.2
                        contentItem: Image {
                            height: 25
                            width: 25
                            source: "./workoutbuilder/" + modelData[imageRole]
                            fillMode: Image.Pad
                            verticalAlignment: Text.AlignVCenter
                            ToolTip.text: modelData[textRole]
                            ToolTip.delay: tooltipShow
                            ToolTip.timeout: tooltipHide
                            ToolTip.visible: hovered
                        }
                        highlighted: lstLoop.highlightedIndex === index

                    }

                    contentItem: Image {
                        height: 25
                        width: 25
                        fillMode: Image.Pad
                        // source: lstLoop.displayText?"./workoutbuilder/" +lstLoop.displayText:null
                        source: "./workoutbuilder/" +model[lstLoop.currentIndex][imageRole]

                        ToolTip.text: lstLoop.displayText
                        ToolTip.delay: tooltipShow
                        ToolTip.timeout: tooltipHide
                        ToolTip.visible: hovered

                    }

                }
            }

            Label {
                Layout.row: 0
                Layout.column: _max_steps + 4  // v2.3.0
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                Layout.rightMargin: 2
                Layout.leftMargin: 2
                Layout.bottomMargin: 5
                text: "Scale"
            }

            Repeater {
                id: idChordType
                model: mpatterns
				
                ComboBox {
                    id: lstChordType
                    model: _ddChordTypes

					onAccepted: {
						chordType = editText;
						console.log("manual chordType: "+chordType);
                        workoutName = undefined; // resetting the name of the workout. One has to save it again to regain the name
						
					}
					onActivated: {
						chordType = model[currentIndex];
						console.log("selected chordType: "+chordType);
                        workoutName = undefined; // resetting the name of the workout. One has to save it again to regain the name
					}

                    Binding on currentIndex {
                        value: lstChordType.model.indexOf(chordType)
					}
                    Binding on editText {
                        value: chordType
					}

                    editable: true
					property var _row: index + 1
					property var _column: steps.count + 4
                    Layout.row: _row
                    Layout.column: _column 
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                    Layout.rightMargin: 2
                    Layout.leftMargin: 2
                    Layout.preferredWidth: 90

                    states: [
                        State {
                            when: modeIndex() == 0
                            PropertyChanges {
                                target: lstChordType;
                                enabled: true
                            }
                        },
                        State {
                            when: modeIndex() != 0;
                            PropertyChanges {
                                target: lstChordType;
                                enabled: false
                            }
                        }
                    ]

                }
            }

            Repeater {
                id: idTools
                model: mpatterns

                Rectangle {

					property var _row: index + 1
					property var _column: steps.count + 5
                    Layout.row: _row
                    Layout.column: _column 
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                    Layout.rightMargin: 0
                    Layout.leftMargin: 0
                    width: gridTools.width + 6
                    height: gridTools.height + 6

                    color: "#E8E8E8"
                    radius: 4

                    Grid {
                        id: gridTools
                        anchors.centerIn: parent
                        rows: 1
                        columnSpacing: 2
                        rowSpacing: 0

                        ImageButton {
                            id: btnClear
                            imageSource: "cancel.svg"
                            ToolTip.text: "Clear"
                            onClicked: clearPattern(index);
                        }
                        ImageButton {
                            id: btnCopy
                            imageSource: "copy.svg"
                            ToolTip.text: "Copy"
                            onClicked: toClipboard(index);
                        }
                        ImageButton {
                            id: btnPaste
                            imageSource: "paste.svg"
                            ToolTip.text: "Paste"
                            enabled: clipboard !== undefined
                            onClicked: fromClipboard(index);
                        }
                        ImageButton {
                            id: btnLoad
                            imageSource: "upload.svg"
                            ToolTip.text: "Reuse saved pattern"
                            //onClicked: loadPattern(index);
                            onClicked: {
                                loadWindow.state = "pattern";
                                loadWindow.index = index;
                                loadWindow.show();
                            }
                        }
                        ImageButton {
                            id: btnSave
                            imageSource: "download.svg"
                            ToolTip.text: "Save for later reuse"
                            onClicked: savePattern(index);
                        }
                        ImageButton {
                            id: btnSetName
                            imageSource: "edittext.svg"
                            ToolTip.text: "Set pattern's name" +
                            ((pattName != "") ? ("\n\"" + pattName + "\"") : "\n--default--")
                            highlighted: (pattName != "")
                            onClicked: {
                                patternNameInputDialog.index = index;
                                patternNameInputDialog.open();

                            }
                        }
                    }
                }
            }

            // Repeater {
                // id: idPattName
                // model: mpatterns

                // Text {
                    // id: txtPN
                    // text: pattName
                    // visible: true // DEBUG was false
					// property var _row: index + 1
					// property var _column: steps.count + 6
                    // Layout.row: _row
                    // Layout.column: _column 
                // }
            // }

        }

        // Presets
        Label {
            //Layout.column : 0
            //Layout.row : 2
            text: "Presets:"
            id: labPresets

        }

        StackLayout {
            currentIndex: modeIndex()
            //Layout.preferredWidth: 220
            Layout.preferredHeight: 30
            Layout.fillWidth: true
            Layout.fillHeight: false

            ComboBox {
                id: lstPresets
                model: presets

                implicitHeight: 10
                Layout.preferredWidth: 220
                Layout.preferredHeight: 30
                Layout.fillWidth: false

                contentItem: Text {
                    text: lstPresets.displayText
                    verticalAlignment: Qt.AlignVCenter
                    padding: 5
                }

                delegate: ItemDelegate { // requiert QuickControls 2.2
                    contentItem: Text {
                        text: modelData.name
                        verticalAlignment: Text.AlignVCenter
                    }
                    highlighted: lstPresets.highlightedIndex === index

                }
                onActivated: {
                    var __preset = model[currentIndex];
                    var rr = __preset.roots;
                    console.log("Preset Changed: " + __preset.name + " -- " + rr);
                    for (var i = 0; i < _max_roots; i++) {
                        if (i < rr.length) {
                            idRoot.itemAt(i).currentIndex = _ddRoots.indexOf(_roots[rr[i]]);
                        } else {
                            idRoot.itemAt(i).currentIndex = 0;
                        }

                        //console.log("selecting root " + i + ": " + steproots[i]);
                    }
                    resetR = false;
                    resetR = true;

                    rootSchemeName = __preset.name;
                }

            }

            RowLayout {
                ComboBox {
                    id: lstPhrases
                    model: getPhrasesLibrary(resetL)

                    Layout.preferredWidth: 220
                    Layout.preferredHeight: 30
                    Layout.fillWidth: false

                    currentIndex: 0

                    displayText: model[currentIndex].label

                    contentItem: Text {
                        text: lstPhrases.displayText
                        verticalAlignment: Qt.AlignVCenter
                        padding: 5
                    }

                    delegate: ItemDelegate { // requiert QuickControls 2.2
                        contentItem: Text {
                            text: modelData.label
                            verticalAlignment: Text.AlignVCenter
                        }
                        highlighted: lstPhrases.highlightedIndex === index

                    }
                    onActivated: {
                        var __phrase = model[currentIndex];
                        console.log("Phrase Changed: " + __phrase.name);
                        setPhrase(__phrase);
                        lastLoadedPhraseName = __phrase.name
                    }

                }

                ImageButton {
                    imageSource: "download.svg"
                    ToolTip.text: "Save phrase"
                    imageHeight: 25
                    imagePadding: (buttonBox.contentItem.height - imageHeight) / 2
                    onClicked: {
                        newWorkoutDialog.state = "phrase";
                        newWorkoutDialog.defname = lastLoadedPhraseName;
                        newWorkoutDialog.open();
                    }

                }
                ImageButton {
                    imageSource: "remove.svg"
                    ToolTip.text: "Remove phrase"
                    imageHeight: 25
                    imagePadding: (buttonBox.contentItem.height - imageHeight) / 2
                    onClicked: {
                        loadWindow.state = "phrase";
                        loadWindow.show();
                    }

                }
                ImageButton {
                    imageSource: "upload.svg"
                    ToolTip.text: "Fetch phrase from current score"
                    // enabled: curScore!=null
                    imageHeight: 25
                    imagePadding: (buttonBox.contentItem.height - imageHeight) / 2
                    onClicked: {
                        getPhraseFromSelection();
                    }

                }

            }

        }

        // Roots

        Label {
            id: labRoots
            //Layout.column : 0
            //Layout.row : 3
            height: 20

            states: [
                State {
                    when: modeIndex() == 0
                    PropertyChanges {
                        target: labRoots
                        text: "Roots:"
                    }
                },
                State {
                    when: modeIndex() != 0;
                    PropertyChanges {
                        target: labRoots
                        text: "Phrase:"
                    }
                }
            ]

        }

        StackLayout {
            currentIndex: modeIndex()
            // width: parent.width
            Layout.fillHeight: false // true is the default for a StackLayout
            Flickable {
                id: flickable
                Layout.alignment: Qt.AlignLeft
                Layout.fillWidth: true
                implicitHeight: idRootsGrid.implicitHeight + sbRoots.height + 5
                contentWidth: idRootsGrid.width
                clip: true

                GridLayout {
                    id: idRootsGrid
                    columnSpacing: 5
                    // rowSpacing: 10
                    Layout.alignment: Qt.AlignLeft
                    rows: 1

                    Repeater {

                        id: idRoot
                        model: _max_roots

                        ComboBox {
                            id: lstRoot
                            Layout.alignment: Qt.AlignLeft | Qt.QtAlignBottom
                            editable: false
                            model: _ddRoots
                            Layout.preferredHeight: 30
                            implicitWidth: 90

                            onActivated: {
                                // manual change, resetting the rootSchemeName
                                rootSchemeName = undefined;
                            }
                        }

                    }
                } // gridlayout scale mode

                ScrollBar.horizontal: ScrollBar {
                    id: sbRoots

                    //anchors.top: idRootsGrid.bottom
                    anchors.right: flickable.right
                    anchors.left: flickable.left
                    active: true
                    visible: true
                }
            } // flicable scale mode

            TextField {
                id: txtPhrase
                text: ""
                Layout.fillWidth: true
                placeholderText: "Enter a grid such as Cm7;F7;C7;Ab7;G7;C7"
				selectByMouse: true

                Layout.alignment: Qt.AlignLeft | Qt.QtAlignBottom

            } // text grid mode


        } // stacklayout

        Label {
            //Layout.column : 0
            //Layout.row : 1
            text: "Options:"
        }
        RowLayout {
            //Layout.column : 1
            //Layout.row : 1

            CheckBox {
                id: chkByPattern
                text: "Group workouts by patterns"
                ToolTip.text: "All the patterns will be applied on the first root notes. Then the next root note. And so on.\nAlternatively, the first pattern will be applied for all the root notes. Then the next pattern. And so on."
                checked: true
                ToolTip.delay: tooltipShow
                ToolTip.timeout: tooltipHide
                ToolTip.visible: hovered

                states: [
                    State {
                        when: modeIndex() == 0
                        PropertyChanges {
                            target: chkByPattern;
                            //enabled: true
                            text: "Group workouts by patterns"
                            ToolTip.text: "All the patterns will be applied on the first root notes. Then the next root note. And so on.\nAlternatively, the first pattern will be applied for all the root notes. Then the next pattern. And so on."
                        }
                    },
                    State {
                        when: modeIndex() != 0;
                        PropertyChanges {
                            target: chkByPattern;
                            //enabled: false
                            text: "Group patterns repetition"
                            ToolTip.text: "Keep the patterns repetitions in the same phrase.\nAlternatively, the repetions will laid on as new phrases."
                        }
                    }
                ]
            }
            CheckBox {
                id: chkInvert
                text: "Invert pattern every two roots"
                checked: false
                enabled: chkByPattern.checked || modeIndex() != 0
                ToolTip.text: "During a pattern over different root notes, every two root notes, the pattern will be apply in the reversed order.\n (Meaning in a descending way for an ascending pattern)."
                ToolTip.delay: tooltipShow
                ToolTip.timeout: tooltipHide
                ToolTip.visible: hovered
            }
            CheckBox {
                id: chkStrictLayout
                text: "Complete measures with rests"
                checked: true
                ToolTip.text: "Add rests at the end of the pattern to ensure that the next iteration of the pattarn starts at the next measure."
                ToolTip.delay: tooltipShow
                ToolTip.timeout: tooltipHide
                ToolTip.visible: hovered
            }
            CheckBox {
                id: chkAdaptativeMeasure
                text: "Adapt signature to pattern"
                checked: true
                enabled: chkStrictLayout.checked
                ToolTip.text: "Adapt the score signatures to ensure that each patterns fits into one measure."
                ToolTip.delay: tooltipShow
                ToolTip.timeout: tooltipHide
                ToolTip.visible: hovered
            }
            /*CheckBox {
            id : chkPageBreak
            checked : false
            text : "Page break after each group"
            }*/
            Item {
                Layout.fillWidth: true
            }

        }

        Item {
            Layout.fillHeight: true
            //Layout.column : 0
            //Layout.row : 4
            Layout.columnSpan: 2
        }

        RowLayout {
            Layout.fillHeight: true
            //Layout.column : 0
            //Layout.row : 5
            Layout.columnSpan: 2

            ImageButton {
                imageSource: "about.svg"
                ToolTip.text: "About"
                imageHeight: 25
                imagePadding: (buttonBox.contentItem.height - imageHeight) / 2
                onClicked: aboutWindow.show();

            }
            ImageButton {
                imageSource: "upload.svg"
                ToolTip.text: "Load workout"
                imageHeight: 25
                imagePadding: (buttonBox.contentItem.height - imageHeight) / 2
                onClicked: {
                    loadWindow.state = "workout";
                    loadWindow.show();
                }

            }
            ImageButton {
                imageSource: "download.svg"
                ToolTip.text: "Save workout"
                imageHeight: 25
                imagePadding: (buttonBox.contentItem.height - imageHeight) / 2
                onClicked: {
                    newWorkoutDialog.state = "workout";
                    newWorkoutDialog.defname = ((modeIndex() == 0) ? lastLoadedWorkoutName : lastLoadedGridWorkoutName);
                    newWorkoutDialog.open();
                }

            }
            ImageButton {
                imageSource: "cancel.svg"
                ToolTip.text: "Clear the workout"
                imageHeight: 25
                imagePadding: (buttonBox.contentItem.height - imageHeight) / 2
                onClicked: emptyAll();

            }
            Item {
                Layout.fillWidth: true
            }

            Label {
                text: "Transposition:"
            }

            ComboBox {
                id: lstTransposition
                model: _instruments

                currentIndex: 0

                displayText: _instruments[currentIndex].label

                contentItem: Text {
                    text: lstTransposition.displayText
                    verticalAlignment: Qt.AlignVCenter
                    padding: 5
                }

                delegate: ItemDelegate { // requiert QuickControls 2.2
                    contentItem: Text {
                        text: modelData.label
                        verticalAlignment: Text.AlignVCenter
                    }
                    highlighted: lstTransposition.highlightedIndex === index

                }
            }

            DialogButtonBox {
                standardButtons: DialogButtonBox.Close
                id: buttonBox

                background.opacity: 0 // hide default white background

                Button {
                    text: "Apply"
                    DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                }

                onAccepted: {
                    printWorkout();
                    // Qt.quit();

                }
                onRejected: Qt.quit()

            }
        }
    }

    Window {
        id: aboutWindow
        title: "About..."
        width: 500
        height: 200
        modality: Qt.WindowModal
        flags: Qt.Dialog | Qt.WindowSystemMenuHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint
        //color: "#E3E3E3"

        ColumnLayout {

            anchors.fill: parent
            spacing: 5
            anchors.margins: 5

            Text {
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: 12
                text: pluginName + " " + version
            }

            Text {
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: 9
                topPadding: -5
                bottomPadding: 15
                text: 'by <a href="https://www.laurentvanroy.be/" title="Laurent van Roy">Laurent van Roy</a>'
                onLinkActivated: Qt.openUrlExternally(link)
            }

            Item {
                // spacer
                Layout.fillHeight: true;
                Layout.fillWidth: true;
                //Layout.columnSpan: 2
            }

            DialogButtonBox {
                id: opionsButtonBox
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                background.opacity: 0 // hide default white background
                standardButtons: DialogButtonBox.Close //| DialogButtonBox.Save
                onRejected: aboutWindow.hide()
                onAccepted: aboutWindow.hide()

            }

            Text {
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: 10
                anchors.bottomMargin: 20

                text: 'Icons made by <a href="https://www.freepik.com" title="Freepik">Freepik</a> from <a href="https://www.flaticon.com/" title="Flaticon">www.flaticon.com</a>'

                wrapMode: Text.Wrap

                onLinkActivated: Qt.openUrlExternally(link)

            }

        }
    }

    Window {
        id: loadWindow
        title: "Reuse pattern..."
        width: 500
        height: 500
        modality: Qt.WindowModal
        flags: Qt.Dialog | Qt.WindowSystemMenuHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint
        //color: "#E3E3E3"

        property int index: -1

        property string state: "pattern"
        Item {
            anchors.fill: parent

            state: loadWindow.state

            states: [
                State {
                    name: "pattern";
                    PropertyChanges {
                        target: loadWindow;
                        title: "Reuse pattern..."
                    }
                    PropertyChanges {
                        target: lstLibrary;
                        model: getPresetsLibrary(resetL, (modeIndex() == 0) ? _SCALE_MODE : _GRID_MODE)
                    }
                    PropertyChanges {
                        target: btnDelPatt;
                        ToolTip.text: "Delete the selected pattern from the library"
                    }

                },
                State {
                    name: "workout";
                    PropertyChanges {
                        target: loadWindow;
                        title: "Reuse workout..."
                    }
                    PropertyChanges {
                        target: lstLibrary;
                        model: getWorkoutsLibrary(resetL, (modeIndex() == 0) ? _SCALE_MODE : _GRID_MODE)
                    }
                    PropertyChanges {
                        target: btnDelPatt;
                        ToolTip.text: "Delete the selected workout from the library"
                    }
                },
                State {
                    name: "phrase";
                    PropertyChanges {
                        target: loadWindow;
                        title: "Reuse phrase..."
                    }
                    PropertyChanges {
                        target: lstLibrary;
                        model: getPhrasesLibrary(resetL)
                    }
                    PropertyChanges {
                        target: btnDelPatt;
                        ToolTip.text: "Delete the selected phrase from the library"
                    }
                }
            ]

            ColumnLayout {

                anchors.fill: parent
                spacing: 5
                anchors.margins: 10

                Text {
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignLeft
                    text: "Select :"
                    bottomPadding: 5

                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    border.color: "grey"

                    ListView { // Presets

                        id: lstLibrary

                        anchors.fill: parent
                        anchors.margins: 5

                        //model: getPresetsLibrary(resetL) //__library
                        //delegate: presetComponent
                        clip: true
                        focus: true

                        delegate: Text {
                            readonly property ListView __lv: ListView.view
                            text: lstLibrary.model[model.index].label;
                            padding: 4

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton

                                onDoubleClicked: {
                                    switch (loadWindow.state) {
                                    case "pattern":
                                        setPattern(loadWindow.index, modelData);
                                        break;
                                    case "workout":
                                        applyWorkout(modelData);
                                        if (modeIndex() == 0) {
                                            lastLoadedWorkoutName = modelData.name;
                                        } else {
                                            lastLoadedGridWorkoutName = modelData.name;
                                        }
                                        break;
                                    case "phrase":
                                        setPhrase(modelData);
                                        lastLoadedPhraseName = modelData.name;
                                        break;
                                    }
                                }

                                onClicked: {
                                    __lv.currentIndex = index;
                                }
                            }
                        }

                        highlightMoveDuration: 250 // 250 pour changer la sélection
                        highlightMoveVelocity: 2000 // ou 2000px/sec


                        // scrollbar
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        highlight: Rectangle {
                            color: "lightsteelblue"
                            //width: parent.width
                            anchors { // throws some errors, but is working fine
                                left: (parent)?parent.left:undefined
                                right: (parent)?parent.right:undefined
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.columnSpan: 2

                    ImageButton {
                        imageSource: "remove.svg"
                        id: btnDelPatt
                        enabled: lstLibrary.currentIndex >= 0
                        imageHeight: 25
                        imagePadding: (libButtonBox.contentItem.height - imageHeight) / 2
                        onClicked: {
                            confirmRemovePatternDialog.pattern = lstLibrary.model[lstLibrary.currentIndex];
                            confirmRemovePatternDialog.open();
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }

                    DialogButtonBox {
                        //Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        id: libButtonBox

                        background.opacity: 0 // hide default white background

                        standardButtons: DialogButtonBox.Cancel
                        Button {
                            text: "Apply"
                            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                        }

                        onAccepted: {
                            var modelData = lstLibrary.model[lstLibrary.currentIndex];
                            switch (loadWindow.state) {
                            case "pattern":
                                setPattern(loadWindow.index, modelData);
                                break;
                            case "workout":
                                applyWorkout(modelData);
                                if (modeIndex() == 0) {
                                    lastLoadedWorkoutName = modelData.name;
                                } else {
                                    lastLoadedGridWorkoutName = modelData.name;
                                }
                                break;
                            case "phrase":
                                setPhrase(modelData);
                                lastLoadedPhraseName = modelData.name;
                                break;
                            }

                            loadWindow.hide();
                        }
                        onRejected: loadWindow.hide()

                    }
                }
            }
        }
    }

    Dialog {
        id: newWorkoutDialog
        title: "Save " + ((state === "workout") ? "workout" : "phrase") + "..."
        //modal: true
        standardButtons: Dialog.Save | Dialog.Cancel

        property string state: "workout"
        property var defname: undefined

        GridLayout {
            state: newWorkoutDialog.state
            anchors.fill: parent
            anchors.margins: 5
            columnSpacing: 10
            rowSpacing: 5
            columns: 2

            Label {
                id: labSave
                text: "Save as:"
            }

            TextField {
                id: txtWorkoutName

                //Layout.preferredHeight: 30
                text: "--"
                Layout.fillWidth: true
                Layout.preferredWidth: 200
                placeholderText: "Enter new " + ((state === "workout") ? "workout" : "phrase") + "'s name"
                maximumLength: 255

            }
            CheckBox {
                id: chkIncludePhrase
                Layout.columnSpan: 2
                Layout.alignment: Qt.AlignLeft
                text: "Include the phrase in the workout"
                checked: false
                enabled: (modeIndex() != 0)
                ToolTip.text: "Includes the current phrase in the workout or keep it blank."
                ToolTip.delay: tooltipShow
                ToolTip.timeout: tooltipHide
                ToolTip.visible: hovered
            }

            states: [
                State {
                    name: "workout";
                    PropertyChanges {
                        target: newWorkoutDialog
                        title: "Save workout as..."
                    }
                    PropertyChanges {
                        target: txtWorkoutName;
                        placeholderText: "Enter new workout's name"
                    }
                    PropertyChanges {
                        target: chkIncludePhrase;
                        visible: true
                    }

                },
                State {
                    name: "phrase";
                    PropertyChanges {
                        target: newWorkoutDialog
                        title: "Save phrase as..."
                    }
                    PropertyChanges {
                        target: txtWorkoutName;
                        placeholderText: "Enter new phrase's name"
                    }
                    PropertyChanges {
                        target: chkIncludePhrase;
                        visible: false
                    }

                }
            ]
        }

        onVisibleChanged: {
            if (visible) {
                txtWorkoutName.text = ((newWorkoutDialog.defname !== undefined) ? newWorkoutDialog.defname : "");
                txtWorkoutName.focus = true;
                txtWorkoutName.selectAll();
            }
        }

        onAccepted: {
            var name = txtWorkoutName.text.trim();
            console.log("==> " + name);
            if ("" === name)
                return;
            var workout = (state === "workout") ? buildWorkout(name, chkIncludePhrase.checked) : getPhrase(name);
            console.log(workout.label);
            newWorkoutDialog.close();
            var conflict = (state === "workout") ? verifyWorkout(workout, true) : verifyPhrase(workout, true);
            if (conflict == null) // no conflict
                if (state === "workout") {
                    saveWorkout(workout);
                } else {
                    savePhrase(workout);
                }
        }
        onRejected: newWorkoutDialog.close();

    }

    Dialog {
        id: patternNameInputDialog
        title: "Pattern name..."
        //modal: true
        standardButtons: Dialog.Save | Dialog.Cancel

        property var index: -1

        RowLayout {
            Label {
                text: "Pattern name:"
            }

            TextField {
                id: txtInputPatternName

                //Layout.preferredHeight: 30
                text: ""
                Layout.fillWidth: true
                placeholderText: "Leave blank for default name"
                maximumLength: 255

            }

        }

        onVisibleChanged: {
            if (visible) {
                txtInputPatternName.text = ((index === -1)) ? "??" : mpatterns.get(index).pattName;
            }
        }

        onAccepted: {
            if (index === -1)
                return;
            var name = txtInputPatternName.text.trim();
            console.log("==> " + name);
            patternNameInputDialog.close();
			mpatterns.get(index).pattName=name;
        }
        onRejected: patternNameInputDialog.close();

    }

    MessageDialog {
        id: confirmReplaceWorkoutDialog
        title: "Save " + ((state === "workout") ? "workout" : "phrase") + "..."
        icon: StandardIcon.Question

        standardButtons: StandardButton.Save | StandardButton.Cancel

        property string state: "workout"

        property var origworkout: {
            label: "--"
        }
        property var newworkout: {
            label: "--"
        }

        text: "The following " + ((state === "workout") ? "workout" : "phrase") + ":\n" + origworkout.label +
        "\nwill be " + ((origworkout.hash == newworkout.hash) ? "renamed into" : "redefined as") + ":\n" +
        newworkout.label + "\n\nDo you want to proceed ?"

        onAccepted: {
            if (state === "workout") {
                replaceWorkout(origworkout, newworkout);
            } else {
                replacePhrase(origworkout, newworkout);
            }
        }
        onRejected: newWorkoutDialog.close();

    }

    MessageDialog {
        id: missingStuffDialog
        icon: StandardIcon.Warning
        standardButtons: StandardButton.Ok
        title: 'Cannot proceed'
        text: 'At least one pattern and one root note must be defined to create the score.'
    }

    MessageDialog {
        id: confirmRemovePatternDialog
        icon: StandardIcon.Warning
        standardButtons: StandardButton.Yes | StandardButton.No
        title: 'Confirm '
        property var pattern: null
        text: 'Please confirm the deletion of the following element: <br/>' + ((pattern == null) ? "--" : pattern.label)
        onYes: {
            confirmRemovePatternDialog.close();
            if (loadWindow.state === "pattern") {
                deletePattern(pattern);
            } else if (loadWindow.state === "phrase") {
                deletePhrase(pattern);
            } else {
                deleteWorkout(pattern);
            }
        }
        onNo: confirmRemovePatternDialog.close();
    }

    MessageDialog {
        id: invalidLibraryDialog
        icon: StandardIcon.Critical
        standardButtons: StandardButton.Ok
        title: 'Invalid libraries'
        text: "Invalid 'notehelper.js' or 'chordanalyser.js' versions.\nExpecting " + noteHelperVersion + " and " + chordHelperVersion + ".\n" + pluginName + " will stop here."
        onAccepted: {
            Qt.quit()
        }
    }

    MessageDialog {
        id: cannotFetchPhraseFromSelectionDialog
        icon: StandardIcon.Warning
        standardButtons: StandardButton.Ok
        property var message: ""
        title: 'Fetch phrase from score'
        text: "Failed to fetch a phrase from the current score:\n" + message +
        "\n\nNote: This action requires a score being openened and that a selection made, containing chord texts."
        onAccepted: {
            cannotFetchPhraseFromSelectionDialog.close()
        }
    }

    function getPatterns(uglyHack) {
        return patterns;
    }

    function getPresetsLibrary(uglyHack, type) {
        var filtered = library.filter(function (p) {
            return (p.type === type);
        });
        return filtered;
    }

    function getPhrasesLibrary(uglyHack) {
        //console.log("Library has " + library.length + " elements");
        return [new phraseClass("")].concat(phrases);
    }

    function getWorkoutsLibrary(uglyHack, type) {
        var filtered = workouts.filter(function (p) {
            return (p.type === type);
        });
        return filtered;
    }

    /**
     * @return 0 for Scale mode, 1 for Grid mode
     */
    function modeIndex() {
        // return bar.currentIndex;
        return rdbScale.checked ? 0 : 1;
    }

    property var presets: [{
            "name": '',
            "root": 0,
            "roots": []
        },
        new presetClass("Chromatic progression", 0, function (r) {
            return r + 1;
        }),
        new presetClass("by Seconds", 0, function (r) {
            return r + 2;
        }),
        new presetClass("Circle of fourths", 0, function (r) {
            return r + 5;
        }),
        new presetClass("Circle of fifths", 0, function (r) {
            return r + 7;
        }),
    ]

    function presetClass(name, root, funcNext) {
        this.name = name;
        this.root = root;
        this.getNext = funcNext;
        Object.defineProperty(this, "roots", {
            get: function () {
                console.log("getting roots for " + this.name);
                var roots = [this.root];
                var r = this.root;
                while (true) {
                    r = this.getNext(r);
                    r = r % 12;
                    if (r == root) {
                        break;
                    }
                    roots.push(r);
                }

                return roots;
            },

            enumerable: true
        });

    }

    function patternClass(steps, loopMode, scale, name, type, gridType) {
        this.steps = (steps !== undefined) ? steps : [];
        this.loopMode = loopMode;
        this.scale = scale;
        this.type = (typeof grid === 'undefined' === undefined || (type !== _SCALE_MODE && type !== _GRID_MODE)) ? _SCALE_MODE : type;
        this.name = (name && (name != null)) ? name : "";
		this.gridType = (typeof gridType === 'undefined')?"grid":gridType;
		
		// debugO("new pattern class",this);

        this.toJSON = function (key) {
            return {
                steps: this.steps,
                loopMode: this.loopMode,
                scale: this.scale,
                name: this.name,
                type: this.type,
                gridType: this.gridType
            };

        };

        // transient properties
        // label
        var label = "";
		// console.log("toString for "+this.type+"/"+this.gridType);
		if (this.type===_GRID_MODE && this.gridType!='grid') {
			var l=_gridTypes.find(function(e) { return e.type=== this.gridType});
			label +=(typeof l !== 'undefined')?l.label:"---";
		} else if (this.steps.length == 0)
            label += "---";
        else
            for (var i = 0; ((i < this.steps.length) && (this.steps[i] !== undefined)); i++) {
                if (i > 0)
                    label += "-";
                if (this.type === _SCALE_MODE) {
                    label += _degrees[this.steps[i]];
                } else {
                    label += _griddegrees[this.steps[i]];
                }
            }

        if (name && name !== "") {
            label += " (" + name + ")";
        }

        if ((loopMode !== "--") && (loopMode !== undefined)) {
            var m = loopMode;
            var filtered = _loops.filter(function (p) {
                return (p.id === loopMode);
            });
            if (filtered.length > 0) {
                m = filtered[0].short;
            }
            label += " / " + m;
        }
        if ((scale !== "") && (scale !== undefined)) {
            label += " / " + scale;
        }

        this.label = label;

        // hash
        var hash = 7;
        for (var i = 0; ((i < steps.length) && (steps[i] !== undefined)); i++) {
            hash = hash * 31 + steps[i];
        }
        if (loopMode !== undefined) {
            hash = hash * 31 + loopMode.hashCode();
        } else {
            hash = hash * 31 + "--".hashCode();
        }
        if (scale !== undefined) {
            hash = hash * 31 + scale.hashCode();
        } else {
            hash = hash * 31 + "--".hashCode();
        }
        hash = hash * 31 + (this.type === _SCALE_MODE ? 1 : 2);

        this.hash = hash;

    }

    /**
     * Creation of a pattern from a pattern object containing the *enumerable* fields (ie. the non transient fields)
     */
    function patternClassRaw(raw) {
        patternClass.call(this, raw.steps, raw.loopMode, raw.scale, raw.name, raw.type, raw.gridType);
    }

    function workoutClass(name, patterns, roots, bypattern, invert) {
        this.type = _SCALE_MODE;
        this.patterns = (patterns !== undefined) ? patterns : [];
        this.name = ((name !== undefined) && (name.trim() !== "")) ? name.trim() : "???";
        this.roots = roots;
        this.bypattern = bypattern;
        this.invert = invert;

        this.toJSON = function (key) {
            return {
                patterns: this.patterns,
                name: this.name,
                type: this.type,
                roots: this.roots,
                bypattern: this.bypattern,
                invert: this.invert
            };

        };

        // transient properties
        // label
        var label = this.name;

        if (patterns.length == 1) {
            label += " (" + patterns[0].label + ")"
        } else if (patterns.length > 1) {
            label += " (" + patterns[0].label + ", +" + (patterns.length - 1) + " )"
        }

        this.label = label;

        // hash
        var hash = 7;
        for (var i = 0; i < this.patterns.length; i++) {
            hash = hash * 31 + this.patterns[i].hash;
        }
        if (this.roots != undefined) {
            for (var i = 0; i < this.roots.length; i++) {
                hash = hash * 31 + this.roots[i].hash;
            }
        }
        if (this.bypattern !== undefined) {
            hash = hash * 31 + (this.bypattern ? 1 : 2);
        }
        if (this.invert !== undefined) {
            hash = hash * 31 + (this.invert ? 1 : 2);
        }
        hash = hash * 31 + (this.type === _SCALE_MODE ? 1 : 2);

        this.hash = hash;

        // makes object immutable
        Object.freeze(this.patterns);
        if (this.roots !== undefined)
            Object.freeze(this.roots);
        Object.freeze(this);

    }

    function gridWorkoutClass(name, patterns, phrase, bypattern, invert) {
        this.type = _GRID_MODE;
        this.patterns = (patterns !== undefined) ? patterns : [];
        this.name = ((name !== undefined) && (name.trim() !== "")) ? name.trim() : "???";
        this.phrase = ((phrase === undefined) || (phrase.chords === undefined) || (phrase.chords.length == 0)) ? undefined : phrase;
        this.bypattern = bypattern;
        this.invert = invert;

        // Trying to pick a name for the phrase
        if (this.phrase !== undefined && this.phrase.name === "") {
            console.log(">>Looking for name");
            var named = verifyPhrase(this.phrase, false);
            if (named != null) {
                console.log(">>Found " + named.name);
                //this.phrase.name = named.name; // readonly prop
                this.phrase = named;
                console.log(">>So now " + this.phrase.name);
            }

        }

        this.toJSON = function (key) {
            return {
                patterns: this.patterns,
                name: this.name,
                type: this.type,
                phrase: this.phrase,
                bypattern: this.bypattern,
                invert: this.invert
            };

        };

        // transient properties
        // label
        var label = this.name;

        if (patterns.length == 1) {
            label += " (" + patterns[0].label + ")"
        } else if (patterns.length > 1) {
            label += " (" + patterns[0].label + ", +" + (patterns.length - 1) + " )"
        }

        if (this.phrase !== undefined) {
            label += " - on " + this.phrase.label;
        }

        this.label = label;

        // hash
        var hash = 7;
        for (var i = 0; i < this.patterns.length; i++) {
            hash = hash * 31 + this.patterns[i].hash;
        }
        if (this.phrase != undefined) {
            hash = hash * 31 + this.phrase.hash;
        }
        if (this.bypattern !== undefined) {
            hash = hash * 31 + (this.bypattern ? 1 : 2);
        }
        if (this.invert !== undefined) {
            hash = hash * 31 + (this.invert ? 1 : 2);
        }
        hash = hash * 31 + (this.type === _SCALE_MODE ? 1 : 2);

        this.hash = hash;

        // makes object immutable
        Object.freeze(this.patterns);
        if (this.roots !== undefined)
            Object.freeze(this.roots);
        Object.freeze(this);

    }

    /**
     * Creation of a complete workout from a workout object containing the *enumerable* fields (ie. the non transient fields)
     */
    function workoutClassRaw(raw) {

        var type = (raw.type === undefined || (raw.type !== _SCALE_MODE && raw.type !== _GRID_MODE)) ? _SCALE_MODE : raw.type;

        var p = raw.patterns;
        var pp = [];
        for (var i = 0; i < p.length; i++) {
            // Keep only the patterns with of the same type (and if no type is set, force it to the workout's type)
            if (p[i]["type"] === undefined)
                p[i].type = type;
            if (p[i].type !== type)
                continue;
            pp.push(new patternClassRaw(p[i]));
        }

        if (type === _SCALE_MODE)
            workoutClass.call(this, raw.name, pp, raw["roots"], raw["bypattern"], raw["invert"]);
        else {
            var phrase = (raw.phrase !== undefined) ? new phraseClassRaw(raw["phrase"]) : undefined;
            gridWorkoutClass.call(this, raw.name, pp, phrase, raw["bypattern"], raw["invert"]);
        }
    }

    /**
     * chords is an array of {"root": index_in__chords_array, "type": key_in__chordTypes_map}
     */
    function phraseClass(name, chords) {
        this.name = ((name !== undefined) && (name.trim() !== "")) ? name.trim() : undefined;
        this.chords = (chords !== undefined) ? chords : [];

        this.toJSON = function (key) {
            return {
                name: this.name,
                chords: this.chords,
            };

        };

        // transient properties
        // label
        if (this.name && this.name !== "") {
            this.label = this.name;
        } else {
            var label = "";
            for (var i = 0; i < Math.min(5, this.chords.length); i++) {
                if (i > 0)
                    label += ", ";
                label += _chords[chords[i].root].root + this.chords[i].type;
            }
            if (this.chords.length > 5) {
                label += ", ..."
            }

            this.label = label;
        }
        // hash
        var hash = 7;
        for (var i = 0; i < this.chords.length; i++) {
            hash = hash * 31 + this.chords[i].root;
            hash = hash * 31 + this.chords[i].type.hashCode();
        }
        this.hash = hash;

        // makes object immutable
        Object.freeze(this.chords);
        Object.freeze(this);

    }

    /**
     * Creation of a phrase from a phrase object containing the *enumerable* fields (ie. the non transient fields)
     */
    function phraseClassRaw(raw) {
        phraseClass.call(this, raw.name, raw.chords);
    }

    FileIO {
        id: libraryFile
        source: librarypath
        onError: {
            console.log(msg);
        }
    }

    function debugO(label, element, excludes) {

        if (typeof element === 'undefined') {
            console.log(label + ": undefined");
        } else if (element === null) {
            console.log(label + ": null");

        } else if (Array.isArray(element)) {
            for (var i = 0; i < element.length; i++) {
                debugO(label + "-" + i, element[i], excludes);
            }

        } else if (typeof element === 'object') {

            var kys = Object.keys(element);
            for (var i = 0; i < kys.length; i++) {
                if (!excludes || excludes.indexOf(kys[i]) == -1) {
                    debugO(label + ": " + kys[i], element[kys[i]], excludes);
                }
            }
        } else {
            console.log(label + ": " + element);
        }
    }
	
	
	// -----------------------------
	    /**
     * Computes the duration of the rests at the end of the measure.
     * If the track is empty (no chords, no rests) return an arbitrary value of -1
     */
    function computeRemainingRest(measure, track, abovetick) {
        var last = measure.lastSegment;
        var duration = 0;

        console.log("Analyzing track " + (((track !== undefined) && (track != null)) ? track : "all") + ", above " + (abovetick ? abovetick : "-1"));

        if ((track !== undefined) && (track != null)) {
            duration = _computeRemainingRest(measure, track, abovetick);
            return duration;

        } else {
            duration = 999;
            // Analyze made on all tracks
            for (var t = 0; t < curScore.ntracks; t++) {
                console.log(">>>> " + t + "/" + curScore.ntracks + " <<<<");
                var localavailable = _computeRemainingRest(measure, t, abovetick);
                console.log("Available at track " + t + ": " + localavailable + " (" + duration + ")");
                duration = Math.min(duration, localavailable);
                if (duration == 0)
                    break;
            }
            return duration;
        }

    }
	
	    /*
     * Instead of counting the rests at the end of measure, we count what's inside the measure beyond the last rests.
     * That way, we take into account the fact that changing the time signature of a measure doesn't fill it with rests, but leaves an empty space.
     */
    function _computeRemainingRest(measure, track, abovetick) {
        var last = measure.lastSegment;
        var duration = sigTo64(measure.timesigActual);

        // setting the limit until which to look for rests
        abovetick = (abovetick === undefined) ? -1 : abovetick;

        console.log("_computeRemainingRest: " + (((track !== undefined) && (track != null)) ? track : "all") + ", above tick " + (abovetick ? abovetick : "-1"));

        if ((track !== undefined) && (track != null)) {
            // Analyze limited to one track
            var inTail = true;
            while ((last != null)) {
                var element = _d(last, track);
                // if ((element != null) && ((element.type == Element.CHORD) )) {
                if ((element != null) && ((element.type == Element.CHORD) || (last.tick <= abovetick))) { // 16/3/22
                    if (inTail)
                        console.log("switching outside of available buffer");
                    // As soon as we encounter a Chord, we leave the "rest-tail"
                    inTail = false;
                }
                if ((element != null) && ((element.type == Element.REST) || (element.type == Element.CHORD)) && !inTail) {
                    // When not longer in the "rest-tail" we decrease the remaing length by the element duration
                    // var eldur=durationTo64(element.duration);
                    // 1.3.0 take into account the effective dur of the element when within a tuplet
                    var eldur = elementTo64Effective(element);
                    duration -= eldur;
                }
                last = last.prevInMeasure;
            }
        }

        duration = Math.round(duration);
        return duration;
    }
	
	    /**
     * Effective duration of an element (so taking into account the tuplet it belongs to)
     */
    function elementTo64Effective(element) {
        // if (!element.duration)
        // return 0;
        var dur = durationTo64(element.duration);
        if (element.tuplet !== null) {
            dur = dur * element.tuplet.normalNotes / element.tuplet.actualNotes;
        }
        return dur;
    }
    function durationTo64(duration) {
        return 64 * duration.numerator / duration.denominator;
    }
	
	    function sigTo64(sig) {
        return 64 * sig.numerator / sig.denominator;
    }

	
    function _d(last, track) {
        var el = last.elementAt(track);
        console.log(" At " + last.tick + "/" + track + ": " + ((el !== null) ? el.userName() : " / "));
        return el;
    }


}