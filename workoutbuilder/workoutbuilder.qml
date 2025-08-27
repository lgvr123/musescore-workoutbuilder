import QtQuick 2.9
import QtQuick.Controls 2.2
import MuseScore 3.0
import QtQuick.Window 2.2
import QtQuick.Dialogs 1.2
import QtQuick.Controls.Styles 1.4
import QtQuick.Layouts 1.3
import FileIO 3.0
import Qt.labs.settings 1.0

import "notehelper.js" as NoteHelper
import "chordanalyser.js" as ChordHelper
import "selectionhelper.js" as SelHelper

/**********************
/* Parking B - MuseScore - Scale Workout builder plugin
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
/*  - 2.3.0 Store settings (CheckBoxes, instrument)
/*  - 2.3.0 Add new "Bass" instrument (should a require a F-clef, but the clef is not available from the API)
/*  - 2.4.0 alpha 1: Add step durations
/*  - 2.4.0 alpha 2: Limit to standard Harmony types
/*  - 2.4.0 alpha 2: Improved chord naming
/*  - 2.4.0 alpha 3: Pushing grid patterns was not working
/*  - 2.4.0 alpha 3: A GridWorkout with 2 patterns was not correctly printed.
/*  - 2.4.0 beta 1: New plugin folder organisation
/*  - 2.4.0 beta 1: Port to MS4
/*  - 2.4.0 beta 1: Loop mode was not deducing the right chord type at some occasions
/*  - 2.4.0 beta 1: New option of exporting 1 score by root note.
/*  - 2.4.0 beta 1: 6/4 measures allowed (instead of splitting them in two 3/4).
/*  - 2.4.1 Better title in case of one score per root note
/*  - 2.4.1 Improvment for MS4 - but still no effect.
/*  - 2.4.1 Bugfix in the QML subcomponents and in chordanalyser library (Issue#2)
/*  - 2.4.2 Repeat the chord symbol at each pattern repetition
/*  - 2.4.2 Distinction between C# and Db, G# and Ab, ...
/*  - 2.4.2 Use correct notes e.g. a 3rd of Bb must be some kind of D. So 3m of Bb is Db and not C#
/*  - 2.4.2 Correct scale notes naming convention (e.g. "♭3" and "3" instead of "m3" and "M3")
/*  - 2.4.2 Add option for line break at each repetition
/*  - 2.4.2 Size of several small windows
/*  - 2.4.2 degrees up to "15" (thord ocatve root)
/*  - 2.4.2 Score properties (for easier batch export)
/*  - 2.4.2 Some new degrees (b4, #5, b8)
/*  - 2.5.0 Srollbars
/*  - 2.5.0 (ongoing) fix new degrees behaviour with loop modes ("LYDIAN BUG")
/*  - 2.5.0 (ongoing) refactoring des propriétés - étape 1 : "degreeName" renommé "degree"


/**********************************************/
MuseScore {
    menuPath: "Plugins." + pluginName
    description: "This plugin builds chordscale workouts based on patterns defined by the user."
    version: "2.5.0-SNAPSHOT"

    pluginType: "dialog"
    requiresScore: false
    width: 1375
    height: 860

    id: mainWindow

    readonly property var pluginName: "Scale Workout Builder"
    readonly property var noteHelperVersion: "1.0.3"
    readonly property var chordHelperVersion: "1.2.8"
    readonly property var selHelperVersion: "1.2.0"

    Component.onCompleted : {
        if (mscoreMajorVersion >= 4) {
            mainWindow.title = pluginName ;
            mainWindow.thumbnailName = "logo.png";
        }
    }

    readonly property var librarypath: { {
            var f = Qt.resolvedUrl("workoutbuilder.library");
            f = f.slice(8); // remove the "file:" added by Qt.resolveUrl and not understood by the FileIO API
            return f;
        }
    }

    readonly property var keyRegexp: /^(\((b*?|#*?)\))?\s*(.*?)(\|?)$/m
    readonly property var endRegexp: /\|\s*;?/g

    readonly property var debugPrepare: true
    readonly property var tracePrepare: true
    readonly property var debugPrint: false
    readonly property var tracePrint: false
    readonly property var debugNextMeasure: false
    readonly property var traceLoadSave: false
    
    readonly property int cellHeight: 30
    readonly property int cellWidth: 70
    readonly property int colSpacing: 5
    readonly property int rowSpacing: 5
    
    

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
		property alias singleScoreExport: chkSingleScoreExport.checked
		property alias orderByPattern: chkByPattern.checked
		property alias adaptativeMeasure: chkAdaptativeMeasure.checked
		property alias strictLayout: chkStrictLayout.checked
		property alias lineBreak: chkLineBreak.checked
		property alias instrument: lstTransposition.currentIndex
    }


    readonly property var _SCALE_MODE: "scale"
    readonly property var _GRID_MODE: "grid"

    property int _max_patterns: 10
    property int _max_steps: 20 
	
    property int _max_roots: 12
    property int _id_Rest: 999
    property var _degrees: [
        // semitones = nb de demi-tons par rapport au root
        // degree = degrée de référence. Ex: b3 => degré de référence = 3
        // id correspond à l'ancien index
        {"semitones": -2, "degree": 7, "octave":-1, "delta":-1, "id": 40,  "label": "-♭7" , "degreeLabel": "♭VII-"  }, //bb1
        {"semitones": -1, "degree": 7, "octave":-1, "delta": 0, "id": 41,  "label": "-7"  , "degreeLabel": "VII"  },
        {"semitones": 0,  "degree": 1, "octave": 0, "delta": 0, "id": 00,  "label": "1"   , "degreeLabel": "I"  },
        {"semitones": 1,  "degree": 2, "octave": 0, "delta":-1, "id": 01,  "label": "♭2"  , "degreeLabel": "♭II"  },
        {"semitones": 2,  "degree": 2, "octave": 0, "delta": 0, "id": 02,  "label": "2"   , "degreeLabel": "II"  },
        {"semitones": 3,  "degree": 3, "octave": 0, "delta":-1, "id": 03,  "label": "♭3"  , "degreeLabel": "♭III"  },
        {"semitones": 4,  "degree": 3, "octave": 0, "delta": 0, "id": 04,  "label": "3"   , "degreeLabel": "III"  },
        {"semitones": 4,  "degree": 1, "octave": 0, "delta":-1, "id": 54,  "label": "♭4"  , "degreeLabel": "♭IV"  },
        {"semitones": 5,  "degree": 4, "octave": 0, "delta": 0, "id": 05,  "label": "4"   , "degreeLabel": "IV"  },
        {"semitones": 6,  "degree": 4, "octave": 0, "delta": 1, "id": 06,  "label": "#4"  , "degreeLabel": "#IV"  },
        {"semitones": 6,  "degree": 5, "octave": 0, "delta":-1, "id": 50,  "label": "♭5"  , "degreeLabel": "♭V"  },
        {"semitones": 7,  "degree": 5, "octave": 0, "delta": 0, "id": 07,  "label": "5"  , "degreeLabel": "V"  },
        {"semitones": 8,  "degree": 5, "octave": 0, "delta": 1, "id": 55,  "label": "#5"  , "degreeLabel": "#V"  },
        {"semitones": 8,  "degree": 6, "octave": 0, "delta":-1, "id": 08,  "label": "♭6"  , "degreeLabel": "♭VI"  },
        {"semitones": 9,  "degree": 6, "octave": 0, "delta": 0, "id": 09,  "label": "6"   , "degreeLabel": "VI"  },
        {"semitones": 10, "degree": 7, "octave": 0, "delta":-1, "id": 10,  "label": "♭7"  , "degreeLabel": "♭VII"  },
        {"semitones": 11, "degree": 7, "octave": 0, "delta": 0, "id": 11,  "label": "7"   , "degreeLabel": "VII"  },
        {"semitones": 11, "degree": 1, "octave": 1, "delta":-1, "id": 56,  "label": "♭(8)", "degreeLabel": "♭I+"  },
        {"semitones": 12, "degree": 1, "octave": 1, "delta": 0, "id": 12,  "label": "(8)" , "degreeLabel": "I+"  },
        {"semitones": 13, "degree": 2, "octave": 1, "delta":-1, "id": 13,  "label": "♭9"  , "degreeLabel": "♭II+"  },
        {"semitones": 14, "degree": 2, "octave": 1, "delta": 0, "id": 14,  "label": "9"  ,  "degreeLabel": "II+"  }       ,    
        {"semitones": 15, "degree": 2, "octave": 1, "delta": 1, "id": 15,  "label": "♯9"  , "degreeLabel": "#II+"  },
        {"semitones": 15, "degree": 3, "octave": 1, "delta":-1, "id": 51,  "label": "♭10" , "degreeLabel": "♭III+"   },
        {"semitones": 16, "degree": 3, "octave": 1, "delta": 0, "id": 52,  "label": "10"  , "degreeLabel": "III+"  },
        {"semitones": 16, "degree": 4, "octave": 1, "delta":-1, "id": 16,  "label": "♭11" , "degreeLabel": "♭IV+"   },
        {"semitones": 17, "degree": 4, "octave": 1, "delta": 0, "id": 17,  "label": "11"  , "degreeLabel": "IV+"  },
        {"semitones": 18, "degree": 4, "octave": 1, "delta": 1, "id": 18,  "label": "♯11" , "degreeLabel": "#IV+"   },
        {"semitones": 19, "degree": 5, "octave": 1, "delta": 0, "id": 19,  "label": "(12)", "degreeLabel": "V+"    },
        {"semitones": 20, "degree": 6, "octave": 1, "delta":-1, "id": 20,  "label": "♭13" , "degreeLabel": "♭VI+"   },
        {"semitones": 21, "degree": 6, "octave": 1, "delta": 0, "id": 21,  "label": "13"  , "degreeLabel": "VI+"  },
        {"semitones": 22, "degree": 6, "octave": 1, "delta": 1, "id": 22,  "label": "♯13" , "degreeLabel": "#VI+"   },
        {"semitones": 23, "degree": 7, "octave": 2, "delta": 0, "id": 23,  "label": "14", "degreeLabel": "VII+"    },
        {"semitones": 24, "degree": 1, "octave": 2, "delta": 0, "id": 53,  "label": "(15)", "degreeLabel": "I++"    },
        {"semitones": -999, "id": _id_Rest,  "label": "𝄽"} // rest
        ]

    property var _notenames: ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

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
            "scale": [0, 2, 4, 5, 7, 9, 11, 12], // degree ids
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
            "scale": [0, 2, 3, 5, 50, 8, 10, 12],
            "mode": "minor"
        },
        "dim": {
            "symb": "o",
            "scale": [0, 1, 3, 4, 50, 7, 9, 12], // 50=b5
            "mode": "minor"
        },
        "Dorien": {
            "symb": "m6",
            "scale": [0, 2, 3, 5, 7, 9, 10, 12],
            "mode": "major"
        },
        "Lydian": {
            "symb": "t7#11",
            "scale": [0, 2, 4, 6, 7, 9, 11, 12], // 6 = #11
            "mode": "major"
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

    property var _rootsData: [{
            "rootLabel": 'C',
            "cleanName": 'C',
            "rawName": 'C',
            "major": false, // we consider C as a flat scale, sothat a m7 is displayed as B♭ instead of A♯
            "minor": false,
            "semitones": 0,
            "accidental": ""
        }, {
            "rootLabel": 'C♯',
            "cleanName": 'C#',
            "rawName": 'C',
            "major": true,
            "minor": true,
            "semitones": 1,
            "accidental": "SHARP"
        }, {
            "rootLabel": 'D♭',
            "cleanName": 'Db',
            "rawName": 'D',
            "major": false,
            "minor": false,
            "semitones": 1,
            "accidental": "FLAT"
        }, {
            "rootLabel": 'D',
            "cleanName": 'D',
            "rawName": 'D',
            "major": true,
            "minor": false,
            "semitones": 2,
            "accidental": ""
        }, {
            "rootLabel": 'D♯',
            "cleanName": 'D#',
            "rawName": 'D',
            "major": true,
            "minor": true,
            "semitones": 3,
            "accidental": "SHARP"
        }, {
            "rootLabel": 'E♭',
            "cleanName": 'Eb',
            "rawName": 'E',
            "major": false,
            "minor": false,
            "semitones": 3,
            "accidental": "FLAT"
        }, {
            "rootLabel": 'E',
            "cleanName": 'E',
            "rawName": 'E',
            "major": true,
            "minor": true,
            "semitones": 4,
            "accidental": ""
        }, {
            "rootLabel": 'F♭',
            "cleanName": 'Fb',
            "rawName": 'F',
            "major": false,
            "minor": false,
            "semitones": 4,
            "accidental": "FLAT"
        }, {
            "rootLabel": 'F',
            "cleanName": 'F',
            "rawName": 'F',
            "major": false,
            "minor": false,
            "semitones": 5,
            "accidental": ""
        }, {
            "rootLabel": 'F♯',
            "cleanName": 'F#',
            "rawName": 'F',
            "major": true,
            "minor": true,
            "semitones": 6,
            "accidental": "SHARP"
        }, {
            "rootLabel": 'G♭',
            "cleanName": 'Gb',
            "rawName": 'G',
            "major": false,
            "minor": false,
            "semitones": 6,
            "accidental": "FLAT"
        }, {
            "rootLabel": 'G',
            "cleanName": 'G',
            "rawName": 'G',
            "major": true,
            "minor": false,
            "semitones": 7,
            "accidental": ""
        }, {
            "rootLabel": 'G♯',
            "cleanName": 'G#',
            "rawName": 'G',
            "major": true,
            "minor": true,
            "semitones": 8,
            "accidental": "SHARP"
        }, {
            "rootLabel": 'A♭',
            "cleanName": 'Ab',
            "rawName": 'A',
            "major": false,
            "minor": false,
            "semitones": 8,
            "accidental": "FLAT"
        }, {
            "rootLabel": 'A',
            "cleanName": 'A',
            "rawName": 'A',
            "major": true,
            "minor": true,
            "semitones": 9,
            "accidental": ""
        }, {
            "rootLabel": 'A♯',
            "cleanName": 'A#',
            "rawName": 'A',
            "major": true,
            "minor": true,
            "semitones": 10,
            "accidental": "SHARP"
        }, {
            "rootLabel": 'B♭',
            "cleanName": 'Bb',
            "rawName": 'B',
            "major": false,
            "minor": false,
            "semitones": 10,
            "accidental": "FLAT"
        }, {
            "rootLabel": 'B',
            "cleanName": 'B',
            "rawName": 'B',
            "major": true,
            "minor": true,
            "semitones": 11,
            "accidental": ""
        }, {
            "rootLabel": 'C♭',
            "cleanName": 'Cb',
            "rawName": 'C',
            "major": false,
            "minor": false,
            "semitones": 11,
            "accidental": "FLAT"
        }
    ]

    property var _rootLabels: { {
            var dd = [];
            for (var i = 0; i < _rootsData.length; i++) {
                dd.push(_rootsData[i].rootLabel);
            }
            return dd;
        }
    }

    property var _ddRoots: { {
            var dd = [''];
            dd = dd.concat(_rootLabels);
            return dd;
        }
    }

    property var _ddNotes: { {
			var dd=_degrees.map(function (e) { return {label: e.label, degreeLabel: e.degreeLabel, id: e.id, delta:e.delta}});
			// dd.unshift({text: '<html><span style="font-family:\'MScore Text\'; font-size: 20px; text-align: center; vertical-align: middle">\uE4E5</span></html>', step: 'R'});
			// dd.unshift({text: String.fromCharCode(7694), step: 'R'});
			dd.unshift({label: '', degreeLabel: '', id: -1, delta: 999});
            return dd;
        }
    }

    property var _ddGridNotes: { {
			var dd=_griddegrees.map(function (e) { return {text: e, step: e}});
			// dd.unshift({text: '(R)', step: 'R'});
			dd.unshift({text: '𝄽', step: 'R'});
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
                        // "note": '', // scale mode
                        "note": -1, // scale mode 
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
            debugO("[" + i + "]", pages[i], ["notes","chord"]);
            //if (pages[i]===undefined) continue; // ne devrait plus arriver
            for (var j = 0; j < pages[i].length; j++) {
				debugO("for print, pattern "+j+"/"+i, pages[i][j],["scale"]);
                // for (var k = 0; k < pages[i][j].notes.length; k++) {
                    // console.log(i + ") [" + pages[i][j].root + "/" + pages[i][j].mode + "/" + pages[i][j].chord.name + "] " + k + ": " + pages[i][j].notes[k]);
                // }
            }
        }

        if (!scaleMode || chkByPattern.checked || chkSingleScoreExport.checked) {
        // if (chkSingleScoreExport.checked) {
            printWorkout_pushToScore(pages);
        } else {
            if (debugPrepare) console.log("Splitting workout in multiple scores");

            var prevroot = null;
            var one = null;
            for (var i = 0; i < pages.length; i++) {
                var page = pages[i];
                var root=pages[i][0].root; // on prend la pattern de la 1ère root
                if (debugPrepare) console.log("This root: "+root+", previous root: "+prevroot);
                
                if (root !== prevroot) {
                    if (one) {
                        if (debugPrepare) console.log("Building a new page (for: "+prevroot+")");
                        printWorkout_pushToScore(one);
                    }
                    one = [];
                    prevroot=root;
                }
                one.push(page);
            }
            if (one) {
                if (debugPrepare) console.log("Building the last page (for: "+prevroot+")");
                printWorkout_pushToScore(one);
            }
        }
    }
	
    function printWorkout_forGrid() {
        // 1) Collecting the roots
        var chords = getPhrase().chords;

        var patts = [];
        
        console.log("~~Preparing for GridWorkout print~~");

        // 2) Collect the patterns and their definition
        for (var i = 0; i < _max_patterns; i++) {
            console.log("Analyzing pattern "+i);
            // 1.1) Collecting the basesteps
			var raw=mpatterns.get(i);

            var p = null;
            console.log("\twhich is "+raw.gridType+" pattern type");
			if (raw.gridType==='grid') {
				p = [];
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
                    console.log("\tbut empty. Stopping here.");
                    break;
                }
                
                // 1.2) Completing the pattern to have a round duration
                if (chkAdaptativeMeasure.valid) {
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
            var loopAt = raw.loopMode;
			loopAt = _loops.filter(function(e) {return e.id===loopAt})[0];
            console.log("looping mode : " + loopAt.label);

            // Retrieving Chord type
            // Build final pattern
            var pattern = {
                "notes": p, // array de {note: [1..x], duration}
                "loopAt": loopAt,
                "name": (raw.gridType!=="grid")?"Chord notes":raw.pattName,
				"gridType": raw.gridType,
            };
            patts.push(pattern);
			debugO("Notes in pattern",pattern.notes); // debug

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
            console.log("~~Building pattern " + p + "/" + patts.length+" ~~");
            var pp = patts[p];
            // On change de "page" entre chaque pattern
            if (debugPrepare) console.log("page++ (SP)");
            page = pages.length; // i.e. Go 1 index further (so if the array is empty, the first index will be 0)
            console.log(">>page for pattern " + p + ": " + page);

            for (var r = 0; r < chords.length; r++) {
                console.log("By P, patterns: " + p + "/" + (patts.length - 1) + "; chords:" + r + "/" + (chords.length - 1) + " => " + page);

                var chord = chords[r];
                var rootIndex = chord.root;
                var rawRootName = _rootsData[rootIndex].rawName; // raw root name : e.g. "E" for "Eb";
                
                var chordtype = chord.type;
                // var scale = _chordTypes[chordtype].scale;
                // v2.1.0
                var effective_chord;
                var scale;
                if (debugPrepare) console.log(Object.keys(_chordTypes));

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
                    var steps=chord.chordnotes
                        .map(function(e) {return {note: e.note, degreeName:parseInt(e.role), duration: 1}})
                        .sort(function(a,b) { return a.note-b.note;});
					
					console.log("~~Collecting notes for "+pp.gridType+" on "+effective_chord.name+" ~~");
					if (chord.bass!=null) {
						if (debugPrepare) console.log("~~~~Dealing with the bass~~~~~")
                        if (tracePrepare) debugO("steps before",steps);
						var bass=parseInt(chord.bass.key);
                        console.log("basse: "+bass);
						var idx=-1;
                        for(var xyz=0;xyz<steps.length;xyz++) {
                            if(steps[xyz].note==bass) {
                                idx=xyz;
                                if (tracePrepare) debugO("Bass found at "+xyz,steps[xyz]);
                                break;
                            }
                        }
                        if (idx>=0) {
                            var bassData=JSON.parse(JSON.stringify(steps[idx]));;
                            steps.pop(); // retirer le "12"
                            if (tracePrepare) debugO("steps without 12",steps);
                            steps=steps.concat(steps.splice(0,idx).map(function(e){ e.note+=12; return e;}));
                            if (tracePrepare) debugO("steps rotated",steps);
                            
                            bassData.note+=12;
                            steps=steps.concat(bassData);
                            if (tracePrepare) debugO("steps with bass+12",steps);
                        }

					}
					
					if(pp.gridType=="chorddown") steps=reversePattern(steps);
					
				} else {
					// Traditional mode: pattern based
					console.log("~~Collecting notes for "+pp.gridType+" ~~");
					for (var n = 0; n < pp.notes.length; n++) {
						var stepData=pp.notes[n];
						var inScale =null;
                        var degreeName="";
                        // rem: "note" = le degré demandé dans la pattern: e.g. 2 pour II
						if (stepData.note !== null) {
                            var ip = parseInt(stepData.note) - 1; // TODO: This is not clean: using a label "1" and trying to deduce the valid array index

                            if (tracePrepare) console.log(n+": "+ip + "--" + (ip % 7) + "--" + Math.floor(ip / 7) + "--" + (Math.floor(ip / 7) * 12) + "**" + scale[ip % 7] + "**" + (scale[ip % 7] + (Math.floor(ip / 7) * 12)));

                            inScale = (scale[ip % 7]) + (Math.floor(ip / 7) * 12);
                            degreeName=(ip%7)+1; // ip =[0,...], degreeName=[1,...]
						}
						if (debugPrepare) console.log(n + ": " + pp.notes[n].note + " --> " + ip + " --> " + inScale);
						var step={note: inScale, duration: stepData.duration, degreeName: degreeName }; 
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

                    if (debugPrepare) console.log(">> Looking at pattern " + p + ", subpattern " + s + " => will be placed at page " + placeAt + " (page=" + page + ")");
                    if (pages[placeAt] === undefined)
                        pages[placeAt] = [];

                    var basesteps = subpatterns[s];

                    var notes = [];

					var pt=(!chkInvert.checked || ((r % 2) == 0))?basesteps:reversePattern(basesteps);
					
                    for (var j = 0; j < pt.length; j++) {
                        if (debugPrepare) console.log(">>> Looking at note " + j + ": " + pt[j].note);

                        var smt=_rootsData[rootIndex].semitones;
                        var noteName = noteFromRoot(rawRootName,pt[j].degreeName);
                        if (debugPrepare) console.log(">>>   with root id = "+rootIndex+" ("+smt+")");
                        // var _n=(pt[j].note!==null)?(rootIndex + pt[j].note):null;
                        var _n=(pt[j].note!==null)?(smt + pt[j].note):null;
                        notes.push({"note" : _n, "noteName": noteName, "duration": pt[j].duration });
                    }


                    if (debugPrepare) debugO("pushing to pages (effective_chord): ", effective_chord, ["scale"]);

                    pages[placeAt].push({
                        "root": rootIndex,
                        "chord": effective_chord,
                        "mode": effective_chord.mode,
                        "notes": notes,
                        "representation": local.representation,
						"gridType": local.gridType
                    });

                }

            }
        }
        
        console.log("~~Preparing for GridWorkout print : done ~~");

        return pages;
        //return [];

    }
    function printWorkout_forScale() {

        console.log("~~Preparing for ScaleWorkout print~~");

        var patts = [];

        // 1) Collect the patterns and their definition
        for (var i = 0; i < _max_patterns; i++) {
            console.log("Analyzing pattern "+i);
			var raw=mpatterns.get(i);
			// if (raw.isEmpty(_SCALE_MODE)) continue;
			
            // 1.1) Collecting the basesteps
            var p = [];
			// 2.4.0 adding in reverse order
            for (var j = (_max_steps-1); j >=0 ; j--) {
                var sn = raw.steps.get(j);
                if (sn.note === _id_Rest) { // Step = Rest
                    p.unshift({"note": null, "duration": sn.duration}); // LYDIAN "note" -> "semitones"
				}
                // else if (sn.note !== '') {
                else if (sn.note > -1) { // Step not empty
                    // var smt = _degrees.indexOf(sn.note);
                    var noteData=_degrees.filter(function(e) {
                        return e.id===sn.note;
                    });
                    noteData=(noteData && noteData.length>0)?noteData[0]:undefined;
                    
                    if(noteData) {
                        var smt=parseInt(noteData.semitones);
                    // if (smt > -1) {
                        // var arr=noteData.label.match(/\d+/); // On extrait si on le degré auquel on se réfère (ex b2 => 2)
                        // var degreeName=(arr!==null && arr.length>0)?arr[0]:null;
                        
                        // LYDIAN BUG ...
                        // old:
                        var step={"note": smt, 
                            "degree": noteData.degree, // LYDIAN degreeName -> degree
                            "duration": sn.duration,
                            "label": noteData.label};
                        // new:
                        // /*  {"semitones": -2, "degree": 7, "octave":-1, "delta":-1, "id": 40,  "label": "-♭7" , "degreeLabel": "♭VII-"  } */
                        // var step=JSON.parse( JSON.stringify(noteData)); 
                        // step.duration=sn.duration;
                        // ... LYDIAN BUG
                        p.unshift(step);
                        if (tracePrepare) console.log("Adding "+JSON.stringify(step));
                    }
                } else if (p.length===0) {
					continue;
                } 
				// else
                    // p.unshift({"note": null, "duration": sn.duration}); // LYDIAN "note" -> "semitones"
            }
			

            if (p.length == 0) {
                break;
            }
			
			// 1.2) Completing the pattern to have a round duration
			if (chkAdaptativeMeasure.valid) {
			    var total = p.map(function (e) {
			        return e.duration
			    }).reduce(function (t, n) {
			        return t + n;
			    });
			    if (total < Math.ceil(total)) {
			        var inc = Math.ceil(total) - total;
			        console.log("adding a rest of " + inc);
			        p.push({
			            "note": null, // LYDIAN "note" -> "semitones"
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
            var cText = raw.chordType; // editable
            var orig = cText;
            console.log("Retrieving scale for \""+cText+"\"");
            var chordData = _chordTypes[cText];
            var isExplicitChord=true;
            if (chordData === undefined) {
                if (cText === '') {
                    // Pas d'accords spécifié => pas d'accord explicite (mais un accord déduit)
                    isExplicitChord=false;
                    
                    // on cherche à le déduire de la pattern en fonction des demi-tons présents
                    var nn = p.map(function (e) {return e.note}); // LYDIAN "note" -> "semitones"
                    // matching sur base des demi-tons !!
                    var m3 = (nn.indexOf(3) > -1); // if we have the "♭3" the we are in minor mode.
                    if (nn.indexOf(10) > -1) { //♭7
                        cText = m3 ? "m7" : "7";
                    } else if (nn.indexOf(11) > -1) { //M7
                        cText = m3 ? "m7" : "t7";
                    } else {
                        cText = m3 ? "m" : "M";
                    }
                    console.log("Empty scale text. So building one from the pattern. Ending up with \"" + cText + "\"");
                } else if (cText.toLowerCase() === 'dom7') {
                    cText = "7";
                }
                console.log("Unknown scale text. Translating it if possible. Ending up with \"" + cText + "\"");
                chordData = _chordTypes[cText];
            }
            if (chordData === undefined) {
                // For user-specific chord type, we take a Major scale, or the Min scale of we found a "-"
                // Clone them so we can modify the name without affecting the main object
                if (cText.includes("-"))  {
                    chordData = JSON.parse( JSON.stringify( _chordTypes['m'])); 
                    console.log("Couldn't find a scale for that text. Taking the minor one.");
                } else {
                    chordData = JSON.parse( JSON.stringify( _chordTypes['M'])); 
                    console.log("Couldn't find a scale for that text. Taking the major one.");
                }
                chordData.symb = cText;
            }
            
            // LYDIAN BUG: on mémorise si l'accord/scale a été explicitement specifié ou implictement déduit
            chordData.isExplicitChord=isExplicitChord; 

            console.log("Pattern " + i + ": \"" + orig + "\" > \"" + chordData.symb + "\", scale : "+JSON.stringify(chordData.scale));

            // Build final pattern
            var pattern = {
                "notes": p, // LYDIAN: array of noteData objects
                "loopAt": mode,
                "chord": chordData,
                "name": raw.pattName,
            };
            patts.push(pattern);
			
			debugO("ready",pattern.notes); // debug

        }

        // Collecting the roots
        if (debugPrepare) console.log("collecting the roots: ");
        var rootIndexes = [];
        for (var i = 0; i < _max_roots; i++) {
            var txt = idRoot.itemAt(i).currentText;
            if (debugPrepare) console.log("root at "+i+": "+txt);
            if (txt === '' || txt === undefined)
                continue;
            var r = _rootLabels.indexOf(txt);
            if (debugPrepare) console.log("-- => index = " + r);
            if (r > -1) {
                rootIndexes.push(r);
                
            }
        }

        // Must have at least 1 pattern and 1 root
        var pages = [];
        if (patts.length == 0 || rootIndexes.length == 0) {
            return [];
        }

        // Extending the patterns with their subpatterns
        var extpatts = [];
        for (var p = 0; p < patts.length; p++) {
            var pattern = extendPattern(patts[p]);
            extpatts.push(pattern);
        }

        // Building the notes and their order
        var page = -1;
        if (chkByPattern.checked) {
            // We sort by patterns. By pattern, repeat over each root
            for (var p = 0; p < extpatts.length; p++) {
                var pattern = extpatts[p];
                // LYDIAN 24/08...
                // var mode = (pattern.notes.map(function(e) { return e.note }).indexOf(3) > -1) ? "minor" : "major"; // if we have the "♭3" the we are in minor mode.
                var mode=pattern.chord.mode;
                // ...LYDIAN 24/08

                //var page = p; //0; //(chkPageBreak.checked) ? p : 0;
                if ((p == 0) || ((patts.length > 1) && (rootIndexes.length > 1))) {
                    console.log("page++");
                    page++;
                }
                for (var r = 0; r < rootIndexes.length; r++) {
                    console.log("By P, patterns: " + p + "/" + (patts.length - 1) + "; roots:" + r + "/" + (rootIndexes.length - 1) + " => " + page);

                    var rootIndex = rootIndexes[r]; // index in the _rootsData array
                    var rawRootName = _rootsData[rootIndex].rawName; // raw root name : e.g. "E" for "Eb";

                    // Looping through the "loopAt" subpatterns (keeping them as a whole)
                    for (var s = 0; s < pattern["subpatterns"].length; s++) {
                        if (pages[page] === undefined)
                            pages[page] = [];

                        var basesteps = pattern["subpatterns"][s];

                        var notes = [];

						var _base=(!chkInvert.checked || ((r % 2) == 0))?basesteps:reversePattern(basesteps);

						for (var j = 0; j < _base.length; j++) {
							console.log(">>> Looking at note " + j + ": " + _base[j].note); // LYDIAN note -> semitones
                            var rootSemitones=_rootsData[rootIndex].semitones;
                            var noteName = noteFromRoot(rawRootName,_base[j].degree); // LYDIAN degreeName -> degree
                            if (debugPrepare) console.log(">>>   with root id = "+rootIndex+" ("+rootSemitones+")");
							// var _n=(_base[j].note!==null)?(rootIndex + _base[j].note):null;
							var noteSemitones=(_base[j].note!==null)?(rootSemitones + _base[j].note):null; // LYDIAN note -> semitones
                            notes.push({"note" : noteSemitones, "noteName": noteName,  "duration": _base[j].duration }); // LYDIAN note -> semitones
						}


                        pages[page].push({
                            "root": rootIndex,
                            "chord": pattern.chord,
                            "mode": mode,
                            "notes": notes, 
                            "representation": pattern.representation
                        });

                    }
                    // On ne change pas de "page" entre root sauf si
                    // a) la pattern coutante est "loopée", dans quel cas on change à chaque root (sauf à la dernière).
                    // b) la pattern suivante est "loopée", dans quel cas on change à chaque root (sauf à la dernière).

                    if (
                        (
                            (pattern["subpatterns"].length > 1) ||
                            ((p < (extpatts.length - 1)) && (extpatts[p + 1]["subpatterns"].length > 1) && (r == (rootIndexes.length - 1))))
                         &&
                        ((rootIndexes.length == 1) || (r < (rootIndexes.length - 1)))) {
                        console.log("page++ (SP)");
                        page++;
                    } {
                        console.log("no page++ (SP) : " + (pattern["subpatterns"].length) + "//" + r + "/" + (patts.length - 1));

                    }
                }

            }
        } else {
            // We sort by roots. By root, repeat every pattern
            for (var r = 0; r < rootIndexes.length; r++) {
                //var page = r; //0; //(chkPageBreak.checked) ? r : 0;

                var rootIndex = rootIndexes[r];
                var rawRootName = _rootsData[rootIndex].rawName; // raw root name : e.g. "E" for "Eb";

                if ((r == 0) || ((patts.length > 1) && (rootIndexes.length > 1))) {
                    console.log("page++");
                    page++;
                }
                for (var p = 0; p < extpatts.length; p++) {
                    console.log("By R, patterns: " + p + "/" + (patts.length - 1) + "; roots:" + r + "/" + (rootIndexes.length - 1) + " => " + page);

                    var pattern = extpatts[p];
                    // LYDIAN 24/08...
                    // var mode = (pattern.notes.map(function(e) { return e.note }).indexOf(3) > -1) ? "minor" : "major"; // if we have the "♭3" the we are in minor mode.
                    var mode=pattern.chord.mode;
                    // ...LYDIAN 24/08


                    // Looping through the "loopAt" subpatterns
                    for (var s = 0; s < pattern["subpatterns"].length; s++) {
                        if (pages[page] === undefined)
                            pages[page] = [];

                        var basesteps = pattern["subpatterns"][s];

                        var notes = [];

                        for (var j = 0; j < basesteps.length; j++) {
                            var rootSemitones=_rootsData[rootIndex].semitones;
                            var noteName = noteFromRoot(rawRootName,basesteps[j].degree); // LYDIAN degreeName -> degree
                            // var _n=(basesteps[j].note!==null)?(rootIndex + basesteps[j].note):null;
                            var noteSemitones=(basesteps[j].note!==null)?(rootSemitones + basesteps[j].note):null; // LYDIAN note -> semitones
                            notes.push({"note" : noteSemitones, "noteName": noteName, "duration": basesteps[j].duration }); // LYDIAN note -> semitones
                        }

                        pages[page].push({
                            "root": rootIndex,
                            "chord": pattern.chord,
                            "mode": mode,
                            "notes": notes, 
                            "representation": pattern.representation
                        });
                    }

                    // On ne change pas de "page" entre pattern sauf si la pattern est "loopée" ou que la suivante est loopée dans quel cas on change à chaque pattern.
                    if (
                        //(pattern["subpatterns"].length > 1)
                        (
                            (pattern["subpatterns"].length > 1)
                             || ((p < (extpatts.length - 1)) && (extpatts[p + 1]["subpatterns"].length > 1)))

                         && ((patts.length == 1) || (p < (patts.length - 1)))) {
                        console.log("page++ (SP)");
                        page++;
                    } else {
                        console.log("no page++ (SP) : " + (pattern["subpatterns"].length) + "//" + p + "/" + (patts.length - 1));

                    }

                }

            }

        }

        console.log("~~Preparing for ScaleWorkout print : done ~~");

        return pages;

    }

    function printWorkout_pushToScore(pages) {



        var instru = _instruments[lstTransposition.currentIndex];
        console.log("Instrument is " + instru.label);

        // Push all this to the score

        var title = (workoutName !== undefined) ? workoutName : "Scale workout";
        title += " - ";
        
        console.log("------------- rootSchemeName: "+rootSchemeName);
        console.log("------------- chkSingleScoreExport.enabled: "+chkSingleScoreExport.enabled);
        console.log("------------- chkSingleScoreExport.checked: "+chkSingleScoreExport.checked);
        console.log("------------- modeIndex: "+modeIndex());
        
        var subtitle="";
        
        if (rootSchemeName !== undefined && rootSchemeName.trim() !== "" && (chkSingleScoreExport.checked || !chkSingleScoreExport.enabled)) {
            // Si on a un nom schéma mais qu'on est en mode 1 page par root => on n'utilise pas ce nom.
            subtitle = rootSchemeName;

        }
        else if ((modeIndex() === 0)) {
            // scale mode
            /*for (var i = 0; i < _max_roots; i++) {
            var txt = idRoot.itemAt(i).currentText;
            // console.log("Next Root: " + txt);
            if (txt === '' || txt === undefined)
            break;
            if (i > 0)
            title += ", ";
            title += txt;
            }*/
            // On ne prend que les roots de ce qui nous est envoyé (2.4.0 Beta1)
            subtitle = pages.reduce(function (acc, val) {
                var rootIndexes = val.map(function (e) {
                    return e.root;
                });
                for (var r = 0; r < rootIndexes.length; r++) {
                    var rootIndex = rootIndexes[r];
                    if (acc.indexOf(rootIndex) === -1)
                        acc.push(rootIndex);
                }
                return acc;
            }, [])
            .map(function (e) {
                return _rootsData[e].rootLabel;
            })
            .join(", ");
            }
            else {
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
            subtitle = names.join(", ");

        }
        title += subtitle;

        // New score
        var score = newScore(title, instru.instrument, 1);

        // Styling
        score.addText("title", title);
        score.setMetaTag("workTitle", title);
        score.setMetaTag("movementTitle", subtitle);
        score.setMetaTag("composer","Parking B")
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
        score.style.setValue("oddFooterC", "More scores on https://www.parkingb.be/");
        score.style.setValue("evenFooterR", "");

        // end of styling

        var adaptativeMeasure = chkAdaptativeMeasure.valid;
        var beatsByMeasure;


        score.startCmd();

        var cursor = score.newCursor();
        cursor.track = 0;

        cursor.rewind(0);

        // first measure sign
        if (adaptativeMeasure) {
            beatsByMeasure = signatureForPattern(pages[0][0].notes);
			if (debugPrint) console.log("recomputing beatsByMeasure to "+beatsByMeasure);
			if (debugPrint) console.log("--> "+typeof(beatsByMeasure));
			
        } else {
            beatsByMeasure = 4;
			if (debugPrint) console.log("forcing beatsByMeasure to "+beatsByMeasure);
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
		

        for (var i = 0; i < pages.length; i++) {;


            var prevRoot = '';
            var prevMode = 'xxxxxxxxxxxxxxx';
            var prevChord = {
                "symb": 'xxxxxxxxxxxxxxx',
                "name": 'xxxxxxxxxxxxxxx'
            };
            for (var j = 0; j < pages[i].length; j++) {
                var shouldLineBreak=(chkLineBreak.valid)?((i>0) || (j>0)):((i>0) && (j==0));

                if (shouldLineBreak) {
                    // New Page ==> double bar + section break;
                    cursor.rewindToTick(cur_time); // rewing to the last note

                    // ... add a double line
                    var measure = cursor.measure;
                    if (measure.nextMeasure != null) {
                        addDoubleLineBar(measure, score);
                    } else {
                        if (debugPrint) console.log("Changing the bar line is delayed after the next measure is added");
                    }

                    // ... add a  linebreak
                    var lbreak = newElement(Element.LAYOUT_BREAK);
                    lbreak.layoutBreakType = 2; //section break
                    cursor.add(lbreak);
                    newLine = true;
                    newLine = true;
                    newLine = true;
                } else {
                    if (debugPrint) console.log("No LAYOUT_BREAK required");

                }



                var root = pages[i][j].root;
                var chord = pages[i][j].chord;
                var mode = pages[i][j].mode;
                if (root !== prevRoot || mode !== prevMode) {
                    preferredTpcs = filterTpcs(root, mode);
                }

                // 2.4.2: reset prevChord to be sure to reprint it at each pattern repetition 
                // Except in "flow" mode (i.e. not Complete measures with rests)
                if(chkStrictLayout.checked) {
                    prevChord = {
                        "symb": 'xxxxxxxxxxxxxxx',
                        "name": 'xxxxxxxxxxxxxxx'
                    };
                }


                if (adaptativeMeasure) {
                    // beatsByMeasure = (pages[i][j].gridType!=="grid")?pages[i][j].notes.length:signatureForPattern(pages[i][j].notes.length);
                    // beatsByMeasure = (pages[i][j].gridType!==undefined && pages[i][j].gridType!=="grid")?pages[i][j].notes.length:signatureForPattern(pages[i][j].notes);
                    beatsByMeasure = signatureForPattern(pages[i][j].notes);
					if (debugPrint) console.log("recomputing beatsByMeasure to "+beatsByMeasure+" (#2) / gridType: "+pages[i][j].gridType);
                } else {
                    beatsByMeasure = 4;
					if (debugPrint) console.log("forcing beatsByMeasure to "+beatsByMeasure+" (#2) / gridType: "+pages[i][j].gridType);
                }
				
                if (tracePrint) debugO("before print",pages[i][j].notes);

                for (var k = 0; k < pages[i][j].notes.length; k++, counter++) {

                    var duration = pages[i][j].notes[k].duration;
                    var fduration = durations.find(function(e) {return e.duration===duration;});
					if (debugPrint) console.log("duration = "+duration+" => fduration = "+((fduration!==undefined)?fduration.fraction.str:"undefined"));
					fduration=(fduration!==undefined)?fduration.fraction:fraction(1,4);

					if (debugNextMeasure) console.log("--["+k+"] NEXT 0");

                    if (counter > 0) { // the first time (ie counter===0, we don't need to move to the next one)
                        cursor.rewindToTick(cur_time); // be sure to move to the next rest, as now defined

						
						// looking for a next rest
						var success = cursor.next();
						while(success && (cursor.element.type!==Element.REST)) {
							 if (debugNextMeasure) console.log("--["+k+"] NEXT 1: next: "+cursor.element.userName()+" at "+cursor.segment.tick);
							 success = cursor.next();
						 }
						

						
						if(success) {
							// if we have found a next rest, we check if 
							// - either this rest is enough for the duration of what we have to write
							// - there is a measure following
							// In the contrary, we add a new measure
							if (debugNextMeasure) console.log("--["+k+"] NEXT 2: last next: "+cursor.element.userName()+" at "+cursor.segment.tick);
							var remaining=computeRemainingRest(cursor.measure, cursor.track); //, cursor.segment.tick);
							var needed = durationTo64(fduration);
							success=((cursor.measure.nextMeasure!==null) || (needed<=remaining));

							if (debugNextMeasure) console.log("?? could move to next segment, ==> checking if enough place or a next measure ("+(cursor.measure.nextMeasure?"next measure":"null")+" -- "+needed+"<>"+remaining+") => "+success);
						} else {
							if (debugNextMeasure) console.log("--["+k+"] NEXT 2: last next: not found");
						}
						
                        if (!success) {
							// If the measure is full or doesn't have enough place, we add a new measure
							if (debugNextMeasure) console.log("--["+k+"] NEXT 3: adding a new measure");
                            score.appendMeasures(1);
                            cursor.rewindToTick(cur_time);

                            if (newLine) {
                                var measure = cursor.measure;
                                if (debugPrint) console.log("Delayed change of ending bar line");
                                addDoubleLineBar(measure, score);
                            }

                            cursor.next();
							if (debugNextMeasure) console.log("--["+k+"] NEXT 4: after new measure: "+cursor.element.userName()+" at "+cursor.segment.tick);
						}
                    }

                    var elNote = cursor.element;
					cur_time = cursor.segment.tick;

					if (debugNextMeasure) console.log("--["+k+"] NEXT 5: adding note/rest at "+cursor.segment.tick);
			
                    var delta = pages[i][j].notes[k].note; // LYDIAN note -> semitones
                    var noteName = pages[i][j].notes[k].noteName;
					
					if (delta !== null) {
					    // Note

					    var pitch = instru.cpitch + delta;
					    var sharp_mode = true;
					    var f = (chord.sharp !== undefined) ? chord.sharp : _rootsData[root][mode]; // si un mode est spécifié on l'utilise sinon on prend celui par défaut
					    if (f !== undefined)
					        sharp_mode = f;

					    var target = {
					        "pitch": pitch,
					        "concertPitch": false,
                            "name" : noteName, // 2.4.2: by preference look for the right tpc based on the note name
					        "sharp_mode": f,
					    };

					    //cur_time = elNote.parent.tick; // getting note's segment's tick
                        
                        debugO("Target: ",target);

					    elNote = NoteHelper.restToNote(elNote, target,fduration);

					} else {
					    // Rest
					    //2.4.0 change adapt rest to the right duration
						if (debugPrint) console.log("Adding rest of "+fduration.str);
						cursor.setDuration(fduration.numerator,fduration.denominator);
						cursor.addRest();
						cursor.rewindToTick(cur_time);
						elNote=cursor.element
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
                    // if ((beatsByMeasure != prevBeatsByM) || newLine) {
                    if ((beatsByMeasure != prevBeatsByM)) { // 24/1/24 Pourquoi rajouter une signature à chaque "newLine" ?
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

                    //debugNote(delta, elNote);
					

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
			"notes": array of {
                "note": semitones: integer/null, // LYDIAN note -> semitones
                "degree": [1..14], // LYDIAN degreeName -> degree
                "duration": float, 
                "label": string }; 
                - or -
                "null" is for rest
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
		
		if (basesteps[basesteps.length-1].note===null) { // LYDIAN note -> semitones
			lastrest=basesteps.pop();
		}

        extpattern.representation = (pattern.name && pattern.name !== "") ? pattern.name : patternToString(pattern.notes, pattern.loopAt);

        extpattern["subpatterns"] = [];
		
		if (tracePrepare) debugO("before",basesteps);


        // first the original pattern


        // looping patterns

        if ((loopAt.type == 1) && (Math.abs(loopAt.shift) < basesteps.length) && (loopAt.shift != 0)) {
            // 1) Regular loopAt mode, where we loop from the current pattern, restarting the pattern (and looping)
            // from the next step of it : A-B-C, B-C-A, C-A-B
            if (debugPrepare) console.log("--Looping patterns : shift mode--");
			
			// reducing the basesteps to only the 1) the notes (and dropping the rests) 2) only the notes (not taking care of the durations)
			//var reduced=basesteps.filter(function(e) { return e.note!==null}).map(function(e) { return e.note});
    	    var reduced = basesteps.filter(function (e) {
    	        return e.note !== null // LYDIAN note -> semitones
    	    }).map(function (e) {
    	        return JSON.parse(JSON.stringify(e)); // clone
    	    });

    	    // octave up or down ? Is the pattern going up or going down ?
            var pattdir = 1;
			var b0=reduced[0].note; // LYDIAN note -> semitones
			var bn=reduced[reduced.length - 1].note; // LYDIAN note -> semitones
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
                    reduced[i].note = reduced[i].note + 12; // LYDIAN note -> semitones
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
                if (debugPrepare) console.log("Regular Looping at " + from);

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

                    var _n = JSON.parse(JSON.stringify(notesteps[idx])); 
                    _n.note += octave * 12; // LYDIAN note -> semitones
                    console.log(">should play " + notesteps[idx].note + " but I'm playing " + _n.note + " (" + octave + ")"); // LYDIAN note -> semitones
                    shifted.push(_n);
                }
                if (e2e) {
                    // We re-add the first note
                    var _n = JSON.parse(JSON.stringify(shifted[0]));
                    _n.note += e2edir * 12; // LYDIAN note -> semitones
                    shifted.push(_n);
                }

                // reinserting the rests and the durations
                var p = [];
                for (var j = 0; j < basesteps.length; j++) {
                    var _b = basesteps[j];
                    if (_b.note === null) { // LYDIAN note -> semitones
                        shifted.splice(j, 0, null);
                    }
                    // var newDegree=degreeForSemitones(shifted[j].note);
                    p.push({
                        note: shifted[j].note, // LYDIAN note -> semitones
                        degree: shifted[j].degree, // la note garde son degré // LYDIAN degreeName -> degree
                        label: shifted[j].label,
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
            if (debugPrepare) console.log("-- Looping patterns : reverse mode --");

			if (lastrest) {
            extpattern["subpatterns"].push([].concat(basesteps).concat(lastrest));
			} else 
            extpattern["subpatterns"].push(basesteps);

			var reversed=reversePattern(basesteps);

			if (lastrest) {
				reversed.push(lastrest);
			}
			
			if (tracePrepare) debugO("basesteps",basesteps); // debug
			if (tracePrepare) debugO("reversed",reversed); // debug


            extpattern["subpatterns"].push(reversed);
			
        } else if (loopAt.type == -1) {
            // 3) Scale loopAt mode, we decline the pattern along the scale (up/down, by degree/Triad)
            var shift = loopAt.shift; //Math.abs(loopAt) * (-1);
            if (debugPrepare) console.log("Looping patterns : scale mode (" + shift + ") --");
            // We clear all the patterns because will be restarting from the last step
            extpattern["subpatterns"] = [];

            // Building the other ones
            var counter = 0;
            var dia = [];
            var delta = Math.abs(shift);
            // we compute the degree to have III V VII
            for (var i = 0; i < scale.length; i += delta) {
                if (debugPrepare) console.log("Adding " + i + " (" + scale[i] + ")");
                dia.push(i);
            }

            // if we have a scale ending on a tonic (1 - 12), and our steps have stopped before (ex the next triad after the VII is the II, not the I)
            // we add it explicitely
            if ((scale[scale.length - 1] == 12) && (dia[dia.length - 1] < (scale.length - 1))) {
                dia.push(scale.length - 1); // the repetition must end with the last step of the scale (the one that holds "12")
            }
            if (shift > 0) {
                // we loop it
                for (var i = 0; i < dia.length; i++) {
                    counter++;
                    if (debugPrepare) console.log("Looping patterns : scale mode at " + dia[i]);
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
                    if (debugPrepare) console.log("Looping patterns : scale mode at " + dia[i]);
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
            if (debugPrepare) console.log("-- Looping patterns : no loop requested --");
			if (lastrest) {
				basesteps.push(lastrest);
			}
            extpattern["subpatterns"].push(basesteps);

        }

        return extpattern;

    }
	
	function reversePattern(pattern) {
	    var reduced = pattern.filter(function (e) {
	        return e.note !== null // LYDIAN note -> semitones
	    }).map(function (e) {
	        return JSON.parse( JSON.stringify(e)); // clone 
	    });

	    reduced.reverse(); // in place reverse

	    var p = [];

	    // reinserting the rests and the durations
	    var p = [];
	    for (var j = 0; j < pattern.length; j++) {
	        var _b = pattern[j];
	        if (_b.note === null) { // LYDIAN note -> semitones
	            reduced.splice(j, 0, null);
	        }
            reduced[j].duration=pattern[j].duration;
	        p.push(reduced[j]);
	    }
	    return p;

	}

    /**
    * scale = array of degree ids : e.g. 0 for 1, 6 for b5, 50 for #11
    */
    function shiftPattern(pattern, scale, step) {
        console.log("----SHIFT PATTERN---");
        debugO("pattern",pattern);
        debugO("scale",scale);
        var pdia = [];
        var degreeScale=_degrees.filter(function (e) { return scale.indexOf(e.id)>=0})
            .map(function(e,index) { e.index=index; return e}); // on rajoute l'index dans la table des deegrés
        ;
        debugO("degreeScale",degreeScale);
        
        // 1) convert a chromatic pattern into a diatonic pattern
        for (var ip = 0; ip < pattern.length; ip++) {
            // for every step of the pattern we look for its diatonic equivalent.
            // And a delta. For a b5, while in major scale, we will retrieve a degree of "5" + a delta of -1 semitone
            
            // LYDIAN BUG
            /* Todo: Trouver un moyen pour que pattern[i].degree = 4 matche avec // LYDIAN degreeName -> degree
            Debug: degreeScale-3: semitones: 6
            Debug: degreeScale-3: degree: 4
            Debug: degreeScale-3: octave: 0
            Debug: degreeScale-3: delta: 1
            Debug: degreeScale-3: id: 6
            Debug: degreeScale-3: label: #4
            Debug: degreeScale-3: index: 3
            
            Par exemple avec degreeScale[ parseInt(pattern[i].degree)-1]
            Ou via degreeScale.filter(e -> e.degree==parseInt(pattern[i].degree))
           
            
            Ce qui permet de trouver le vrai degré et permet de dire "2-4-1" et de l'application tant à du lydien
            ce qui déduira que "4" est le #11, qu'à du majeur qui en déduire que le "4" est bécarre11
            
            
            */
            
            var computeData = undefined;
            var smt = pattern[ip].note; // LYDIAN note -> semitones
            var degree= pattern[ip].degree;  // LYDIAN degreeName -> degree
            
            if(tracePrepare) console.log("[shift " + step + "] 0)[" + ip + "] searching for degree "+degree);

            
            var octave = Math.floor(smt / 12);
            smt = smt % 12;

            for(var ds=0; ds<degreeScale.length;ds++) {
                if (degreeScale[ds].degree===degree) {
                if(tracePrepare) console.log("[shift " + step + "] 0)[" + ip + "] searching for degree "+degree +" -- FOUND");
            
                    computeData = {
                            "degreeIndex": degreeScale[ds].index,
                            "semi": smt-degreeScale[ds].semitones, // la différence de demi-tons entre la note et son degré dans la gamme
                            "octave": octave
                        };
                    break;
                }

            }

           if (computeData === undefined) {
                // if not found, it means we are beyond the last degree
                if(tracePrepare) console.log("[shift " + step + "] 0)[" + ip + "] searching for degree "+degree +" -- NOT FOUND");
                var lastDegree=degreeScale[degreeScale.length-1];
                computeData = {
                    "degreeIndex": lastDegree.index,
                    "semi": smt - lastDegree.semitones,
                    "octave": octave
                };

            }

            pdia.push(computeData);
			console.log("[shift " + step + "] 1)[" + ip + "]" + smt + "->" + debugDia(computeData));
        }

        // 2) shift the diatonic pattern by the amount of steps
        for (var ip = 0; ip < pdia.length; ip++) {
            var computeData = pdia[ip];
			if (computeData!==null) {
                computeData.degreeIndex += step;
                computeData.octave += Math.floor(computeData.degreeIndex / 7); // degrees are ranging from 0->6, 7 is 0 at the next octave 
                computeData.degreeIndex = computeData.degreeIndex % 7; //scale.length;
			}
            pdia[ip] = computeData;
            console.log("[shift " + step + "] 2)[" + ip + "]->" + debugDia(computeData));
        }

        // 3) Convert back to a chromatic scale
        var pshift = [];
        for (var ip = 0; ip < pdia.length; ip++) {
            var computeData = pdia[ip];
			var noteData=null;
			if(computeData!==null) {
                if (computeData.degreeIndex >= degreeScale.length) {
                    // We are beyond the scale, let's propose some value
                    computeData.semi += (computeData.degreeIndex - degreeScale.length + 1) * 1; // 1 semi-tone by missing degree
                    computeData.degreeIndex = degreeScale.length - 1;
                    if ((degreeScale[computeData.degreeIndex] + computeData.semi) >= 12)
                        computeData.semi = 11;
                }
                var degreeData=degreeScale[computeData.degreeIndex];
                var label="";
                switch(computeData.semi) {
                    case -2:
                        label='\u1D12B';
                        break;
                    case -1:
                        label='\u266D';
                        break;
                    case 0:
                        label="";
                        break;
                    case 1:
                        label='\u266F';
                        break;
                    case 2:
                        label='\u1D12A';
                        break;
                    default:
                        label="("+computeData.semi+")"
                };
                label+=degreeData.degree;
                noteData = {
                    "note": degreeData.semitones + 12 * computeData.octave + computeData.semi, // LYDIAN note -> semitones
                    "degree": degreeData.degree, // LYDIAN degreeName -> degree
                    "label": label,
                };
                console.log("\tscale[.degree] + 12 * .octave + .semi: "+JSON.stringify(scale));
			} else {
				noteData=null;
			}
            pshift.push(noteData);
            console.log("[shift " + step + "] 3)[" + ip + "]" + debugDia(computeData) + "->" + noteData.note); // LYDIAN note -> semitones
        }
		
		// 4) Reset the right durations
        for (var ip = 0; ip < pattern.length; ip++) {
			pshift[ip].duration=pattern[ip].duration
		}
		
        return pshift;

    }
    /** 
    /* Retourne "A", "B", "C", ...
    */
    function noteFromRoot(rawRootName,degree) {
        var idxR=_notenames.indexOf(rawRootName);
        console.log("idxR of "+rawRootName+" = "+idxR);
        var idxN=idxR+parseInt(degree)-1; // degree goes from 1 to 7 and beyond
        console.log("idxN at degree "+degree+" = "+idxN);
        idxN = idxN % _notenames.length;
        console.log(" ==> = "+idxN);
        var noteName=_notenames[idxN];
        console.log(" ==> noteName = "+noteName);
        if(tracePrepare) console.log(degree +"° of "+rawRootName+" is "+noteName);
        return noteName;
    }

	function patternDuration(notes) {
		var count=0;
		for(var i=0; i<notes.length;i++) {
			count+=notes[i].duration;
			if (debugPrint) console.log("--- "+i+") "+notes[i].duration + " ==> total = "+count);
		}
		console.log("total pattern duration "+count);
		return count;
	}
    
    /*
    Retourne l'objet _degree qui correspond au nombre de demi-tons demandé. Si plusieurs objets ont le même nombre de demi-tons (ex #4 et b5) retourne (pour le moment) le 1er trouvé.
    */
    function degreeForSemitones(semitones) {
        var rounded=(144+semitones)%12; //144 = 12*12, on s'assure que 144+semitones soit tjs >=0
        console.log("---> "+semitones+" => "+rounded);
        var noteData=_degrees.filter(function(e) {
            return e.semitones===rounded;
        });
        noteData=(noteData && noteData.length>0)?noteData[0]:undefined;
        return noteData;
    }

    function signatureForPattern(notes) {
		var count=patternDuration(notes);
		
		count=Math.ceil(count);
		
        if ((count % 4) === 0)
            return 4;
        else if ((count % 6) === 0)
            return 6;
        else if ((count % 3) === 0)
            return 3;
        else if ((count % 5) === 0)
            return 5;
        else
            return count;
    }


	/**
	notes described as :
        array of {"note": semitones: integer/null, "degree": [1..14], "delta": semitones to degree "duration": float, "label": string }; "null" is for rest
        // LYDIAN degreeName -> degree
        // LYDIAN note -> semitones
	*/		
    function patternToString(notes, loopAt) {
        var str = "";
        for (var i = 0; i < notes.length; i++) {
            var noteData=notes[i];
			if (noteData.note===null) continue; // LYDIAN note -> semitones
            if (str.length > 0)
                str += "/";
            var d=noteData.label;
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
		// if (d!==null)         return "{degree:" + d.degree + ",semi:" + d.semi + ",octave:" + d.octave + "}";
		if (d!==null)         return "{degreeIndex:" + d.degreeIndex + ",semi:" + d.semi + ",octave:" + d.octave + "}";
		else return "{degree: null (=rest)}";
    }

    function filterTpcs(rootIndex, mode) {
        var sharp_mode = true;

        var f = _rootsData[rootIndex][mode];
        if (f !== undefined)
            sharp_mode = f;

        //console.log(_rootsData[rootIndex].rootLabel + " " + mode + " => sharp: " + sharp_mode);

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

    function rootToName(rootIndex, sharp_mode, chordsymb) {
        // no preferred name set. Just a root(pitch). Computing a name.
        var rtxt = _rootsData[rootIndex].cleanName;
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
                var id = current.steps.get(i).note;
                // if (note !== '') {
                if (id >= 0) { // non empty step
                    // d = _degrees.indexOf(id);
                    d = id;
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
                // var note = (pattern !== undefined && (i < pattern.steps.length)) ? _degrees[pattern.steps[i]] : '';
                var note = (pattern !== undefined && (i < pattern.steps.length)) ? pattern.steps[i] : -1;
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
                var rootAccidental="";
                if (c.accidental.startsWith("SHARP")) {
                    isSharp = true;
                    rootAccidental="SHARP";
                }
                if (c.accidental.startsWith("FLAT")) {
                    isSharp = false;
                    rootAccidental="FLAT";
                }
                
                var rootIndex=getRootIndex(c.pitch,rootAccidental);
                
                debugO("Found root",{pitch: c.pitch, chord: name, accidental: rootAccidental, found: _rootsData[rootIndex].rootLabel});
                debugO("",c.chordnotes);
                
                var forPhrase = {
                    // "root": c.pitch,
                    "root": rootIndex,
                    "type": c.name,
					"chordnotes": c.chordnotes,
					"bass": c.bass,
                    "sharp": isSharp,
                    "name": name,
                    "end": end,
                    "key": key,
                };
                //debugO("Using chord : > ", forPhrase, ["scale"]);
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

                                //debugO("Using chord : > ", forPhrase, ["scale"]);
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
    
    function getRootIndex(semitones, accidental) {
        var acc=(accidental==="SHARP" || accidental==="FLAT")?accidental:"" ;
        
        // On cherche la concordance entre demi-tons et altération
        for(var i=0; i<_rootsData.length;i++) {
            var e=_rootsData[i];
            if (e.semitones===semitones && e.accidental===accidental) {
                return i;
            }
        }
        
        // Si on n'a pas trouvé, on cherche juste la concordance sur les demis-tons
        for(var i=0; i<_rootsData.length;i++) {
            var e=_rootsData[i];
            if (e.semitones===semitones) {
                return i;
            }
        }

        // Si on n'a toujours pas trouvé, on retourne 0, arbitrairement
        return 0;
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
                    // TODO ??
                    idRoot.itemAt(i).currentIndex = _ddRoots.indexOf(_rootLabels[workout.roots[i]]); // id --> label --> indexOf dans le tableau de présentation
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

        if (traceLoadSave) debugO("Workout à sauver", workout);

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
        GridLayout {
            id: allStepsGrid
            Layout.columnSpan: 2
            Layout.alignment: Qt.AlignCenter
            Layout.fillHeight: true
            Layout.fillWidth: true
            
            rows: 2 // header+grid
            columns: 5 // label + grid + loopAt+Scale+Tools
            
            

            ScrollView { // Steps Header
                id: svStepsHeader
                
                Layout.column: 1
                Layout.row: 0
                
                Layout.fillWidth: true
                contentWidth: stepLabelsGrid.width
                contentHeight: stepLabelsGrid.height
                
                clip:true
                
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                
                Flickable {
                    id: stepLabelsFlickable
                    
                    Binding on contentX {
                        value: notesFlickable.contentX
                    }
                    
                    interactive: false
                    
                    GridLayout {
                        id: stepLabelsGrid
                        columns: _max_steps
                        columnSpacing: colSpacing
                        rowSpacing: rowSpacing
                        Repeater {
                            model: _max_steps


                            Label {
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                                Layout.fillWidth: true
                                Layout.rightMargin: 0
                                Layout.leftMargin: 0
                                Layout.bottomMargin: 0

                                // Layout.row: 0
                                text: (index + 1)
                                horizontalAlignment: Text.AlignHCenter

                                Layout.minimumWidth: cellWidth - Layout.leftMargin - Layout.rightMargin
                                Layout.maximumWidth: cellWidth - Layout.leftMargin - Layout.rightMargin
                                //implicitWidth: cellWidth - Layout.leftMargin - Layout.rightMargin
                            }
                        }        

                        Repeater {
                            model: _max_steps
                        
                            ComboBox {
                                id: lstStepDuration
                                model: durations
                                // Layout.row: 1

                                property var stepIndex: index // index is a "context property" given to the repeated element by the repeater

                                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                                Layout.fillWidth: true
                                Layout.topMargin: 0
                                Layout.rightMargin: 0
                                Layout.leftMargin: 0
                                Layout.bottomMargin: 5

                                Layout.minimumWidth: cellWidth - Layout.leftMargin - Layout.rightMargin
                                Layout.maximumWidth: cellWidth - Layout.leftMargin - Layout.rightMargin
                                implicitWidth: cellWidth - Layout.leftMargin - Layout.rightMargin



                                textRole: "text"
                                property var comboValue: "duration"
                                property var duration: 1

                                onActivated: {
                                    // loopMode = currentValue;
                                    duration = model[currentIndex][comboValue];
                                    console.log("step "+stepIndex + ": "+duration);

                                    for (var i = 0; i < _max_patterns; i++) {
                                        var raw = mpatterns.get(i);

                                        // console.log("Setting duration of step/pattern "+index+"/"+i+" to "+duration);

                                        raw.steps.get(stepIndex).duration = duration;
                                    }

                                }

                                Binding on currentIndex {
                                    value: durations.map(function (e) {
                                        return e[lstStepDuration.comboValue]
                                    }).indexOf(lstStepDuration.duration);
                                }


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
                }
            }
            
            
            ScrollView { // Pattern labels
                id: svLeftColumn
                Layout.column: 0
                Layout.row: 1
                Layout.fillHeight: true
                contentWidth: patternLabelsGrid.width
                contentHeight: patternLabelsGrid.height

                clip: true
                
                Flickable {
                    id: leftColumnFlickable

                    Binding on contentY {
                        value: notesFlickable.contentY
                    }

                    interactive: false
               
                
                    GridLayout {
                        id: patternLabelsGrid
                        rows: _max_patterns
                        columnSpacing: colSpacing
                        rowSpacing: rowSpacing
                        flow: GridLayout.TopToBottom
                        
                        Repeater {
                            id: idPatternLabels
                            model: _max_patterns

                            Label {
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                Layout.rightMargin: 10
                                Layout.leftMargin: 2
                                Layout.minimumHeight: cellHeight - Layout.bottomMargin - Layout.topMargin
                                Layout.maximumHeight: cellHeight - Layout.bottomMargin - Layout.topMargin
                                text: "Pattern " + (index + 1) + ":"
                                
                            }
                        }
                        
                        Repeater { // 2.3.0
                            id: idGridTypes
                            model: mpatterns

                            
                            ComboBox {
                                //Layout.fillWidth : true
                                id: lstGridType
                                Layout.minimumHeight: cellHeight - Layout.bottomMargin - Layout.topMargin
                                Layout.maximumHeight: cellHeight - Layout.bottomMargin - Layout.topMargin   
                                implicitHeight: cellHeight - Layout.bottomMargin - Layout.topMargin
                                
                                model: _gridTypes
                                
                                textRole: "label" 
                                property var imageRole: "image"
                                property var comboValue: "type"


                                onActivated: {
                                    // loopMode = currentValue;
                                    gridType = model[currentIndex][comboValue];
                                    console.log(gridType);
                                }

                                Binding on currentIndex {
                                    value: {
                                        var ci=_gridTypes.map(function(e) { return e[comboValue] }).indexOf(gridType);
                                        ci;
                                    }
                                }
                                
                                visible: modeIndex()!=0

                                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                Layout.rightMargin: 0
                                Layout.leftMargin: 0

                                Layout.preferredWidth: 30 + indicator.width

                                delegate: ItemDelegate { // requiert QuickControls 2.2
                                    contentItem: Image {
                                        height: 25
                                        width: 25
                                        source: "./" + modelData[imageRole]
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
                                    source: "./" +model[lstGridType.currentIndex][imageRole]

                                    ToolTip.text: lstGridType.displayText
                                    ToolTip.delay: tooltipShow
                                    ToolTip.timeout: tooltipHide
                                    ToolTip.visible: hovered

                                }

                            }

                            
                        }
                        
                    }
                }
            }
            
            ScrollView { // Note grid
                Layout.column: 1
                Layout.row: 1
                
                id: svGrid

                clip: true
                Layout.fillHeight: true
                Layout.fillWidth: true
                contentWidth: notesGrid.width
                contentHeight: notesGrid.height
                
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                
                
                Flickable { // J'ajoute un Flickable pour pouvoir atteindre la propriété contentX
                    id: notesFlickable

                    GridLayout {
                        columns: _max_steps
                        rows: _max_patterns
                        columnSpacing: colSpacing
                        rowSpacing: rowSpacing
                        
                        id: notesGrid
                        
                        // flow: Grid.TopToBottom
                        
                        Repeater {
                            id: idStepNotes
                            model: mpatterns
                            

                            Repeater {

                                id: idSingleStep
                                property var patternIndex: index

                                model: steps
                            
                                StackLayout {
                            
                                    width: cellWidth
                                    height: cellHeight
                                    
                                    property var stepIndex: index

                                    Layout.minimumWidth: cellWidth - Layout.leftMargin - Layout.rightMargin
                                    Layout.maximumWidth: cellWidth - Layout.leftMargin - Layout.rightMargin
                                    implicitWidth: cellWidth - Layout.leftMargin - Layout.rightMargin
                                    Layout.minimumHeight: cellHeight - Layout.bottomMargin - Layout.topMargin
                                    Layout.maximumHeight: cellHeight - Layout.bottomMargin - Layout.topMargin   
                                    implicitHeight: cellHeight - Layout.bottomMargin - Layout.topMargin
                                    
                                    
                                    currentIndex: modeIndex()
                                    
                                    ComboBox {
                                        id: lstStep
                                        model: _ddNotes

                                        textRole: (chordType!=="")?"degreeLabel":"label"
                                        property var comboValue: "id"
                                        
                                        property var isDegree: model[currentIndex]["delta"]===0

                                        onActivated: {
                                            note = model[currentIndex][comboValue];
                                            console.log(note);
                                            console.log("Current scale = "+chordType);
                                        }

                                        Binding on currentIndex {
                                            value: {
                                                _ddNotes.map(function (e) {
                                                return e[lstStep.comboValue]
                                            }).indexOf(note);
                                            }
                                        }

                                        editable: false
                                        
                                        // font.family: "FreeSerif"

                                        delegate: ItemDelegate {
                                            contentItem: Text {
                                                text: modelData[lstStep.textRole]
                                                // textFormat: Text.RichText
                                                anchors.verticalCenter: parent.verticalCenter
                                                font: lstStep.font
                                                color: modelData["delta"]===0?"blue":systemPalette.windowText
                                                
                                            }
                                            highlighted: lstStep.highlightedIndex === index

                                        }

                                        contentItem: Text {
                                            text: lstStep.displayText
                                            // textFormat: Text.RichText
                                            verticalAlignment: Text.AlignVCenter
                                            anchors.verticalCenter: parent.verticalCenter
                                            horizontalAlignment: Qt.AlignHCenter
                                            color: lstStep.isDegree?"blue":systemPalette.windowText
                                        }
                                        

                                        
                                    }
                                    ComboBox {
                                        id: lstGStep

                                        model: _ddGridNotes

                                        enabled: gridType==="grid"

                                        // Roles in the ComboBox model
                                        textRole: "text"
                                        property var comboValue: "step"

                                        onActivated: {
                                            console.log("degree at "+stepIndex+" of "+patternIndex+": "+degree);
                                            degree = model[currentIndex][comboValue];
                                            workoutName = undefined; // resetting the name of the 
                                            console.log("==> now degree: "+degree);
                                        }
                                        
                                        Binding on currentIndex {
                                            // value: lstGStep.model.indexOf(degree)
                                            value: {
                                                _ddGridNotes.map(function (e) {
                                                return e[lstGStep.comboValue]
                                            }).indexOf(degree);
                                            }
                                        }


                                        editable: false
                                        Layout.alignment: Qt.AlignLeft | Qt.QtAlignBottom
                                        // implicitWidth: 30
                                        
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
                                
                            // }
                        }
                    }
                        
                    }
                }
            }
        
            
            ScrollView { // Repeat Column
                id: svRepeatColumn
                Layout.column: 2
                Layout.row: 1

                clip: true
                Layout.fillHeight: true
                contentWidth: repeatGrid.width
                contentHeight: repeatGrid.height
                
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                
                
                Flickable { // J'ajoute un Flickable pour pouvoir atteindre la propriété contentX
                    id: repeatFlickable

                    Binding on contentY {
                        value: notesFlickable.contentY
                    }

                    interactive: false
                
                    GridLayout {
                        id: repeatGrid
                        rows: _max_patterns
                        columnSpacing: colSpacing
                        rowSpacing: rowSpacing
                        flow: GridLayout.TopToBottom
                        
                        Repeater {
                            id: idLoopingMode
                            model: mpatterns

                            ComboBox {
                                //Layout.fillWidth : true
                                id: lstLoop
                                model: _loops
                                
                                textRole: "label" 
                                property var imageRole: "image"
                                property var comboValue: "id"
                                
                                onActivated: {
                                    // loopMode = currentValue;
                                    loopMode = model[currentIndex][comboValue];;
                                    console.log(loopMode);
                                }

                                Binding on currentIndex {
                                    value: {
                                        var ci=model.map(function(e) { return e[comboValue] }).indexOf(loopMode);
                                        ci;
                                    }
                                }

                                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                                Layout.rightMargin: 2
                                Layout.minimumHeight: cellHeight - Layout.bottomMargin - Layout.topMargin
                                Layout.maximumHeight: cellHeight - Layout.bottomMargin - Layout.topMargin   
                                implicitHeight: cellHeight - Layout.bottomMargin - Layout.topMargin

                                Layout.preferredWidth: 80 

                                delegate: ItemDelegate { // requiert QuickControls 2.2
                                    contentItem: Image {
                                        height: 25
                                        width: 25
                                        source: "./" + modelData[imageRole]
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
                                    source: "./" +model[lstLoop.currentIndex][imageRole]

                                    ToolTip.text: lstLoop.displayText
                                    ToolTip.delay: tooltipShow
                                    ToolTip.timeout: tooltipHide
                                    ToolTip.visible: hovered

                                }

                            }
                        }
                        
                    }
                }
            }
                
            ScrollView { // Scale Column
                id: svScaleColumn
                Layout.column: 3
                Layout.row: 1
                    
                clip: true
                Layout.fillHeight: true
                contentWidth: scaleGrid.width
                contentHeight: scaleGrid.height
                
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                
                
                Flickable { // J'ajoute un Flickable pour pouvoir atteindre la propriété contentX
                    id: scaleFlickable

                    Binding on contentY {
                        value: notesFlickable.contentY
                    }
                
                    interactive: false

                    GridLayout {
                        id: scaleGrid
                        rows: _max_patterns
                        columnSpacing: colSpacing
                        rowSpacing: rowSpacing
                        flow: GridLayout.TopToBottom
                    
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
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                                Layout.rightMargin: 2
                                Layout.leftMargin: 2

                                Layout.minimumHeight: cellHeight - Layout.bottomMargin - Layout.topMargin
                                Layout.maximumHeight: cellHeight - Layout.bottomMargin - Layout.topMargin   
                                implicitHeight: cellHeight - Layout.bottomMargin - Layout.topMargin
                                
                                Layout.preferredWidth: 120

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
                    }
                }
            }
            
            ScrollView { // Tools Column
                id: svToolsColumn
                Layout.column: 4
                Layout.row: 1
                
                clip: true
                Layout.fillHeight: true
                contentWidth: toolsGrid.width
                contentHeight: toolsGrid.height
                
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                
                
                Flickable { // J'ajoute un Flickable pour pouvoir atteindre la propriété contentX
                    id: toolsFlickable

                    Binding on contentY {
                        value: notesFlickable.contentY
                    }

                    interactive: false
                
                    GridLayout {
                        id: toolsGrid
                        rows: _max_patterns
                        columnSpacing: colSpacing
                        rowSpacing: rowSpacing
                        flow: GridLayout.TopToBottom
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
                                // height: gridTools.height + 6

                                Layout.minimumHeight: cellHeight - Layout.bottomMargin - Layout.topMargin
                                Layout.maximumHeight: cellHeight - Layout.bottomMargin - Layout.topMargin   

                                implicitHeight: cellHeight - Layout.bottomMargin - Layout.topMargin

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



                    }
                    
                }
            }
            
            Label {
                Layout.row: 0
                Layout.column: 2
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                Layout.rightMargin: 2
                Layout.leftMargin: 2
                Layout.bottomMargin: 5
                text: "Repeat"
            }            
    
            Label {
                Layout.row: 0
                Layout.column: 3
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                Layout.rightMargin: 2
                Layout.leftMargin: 2
                Layout.bottomMargin: 5
                text: "Scale"
            }

            
            
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
                    var rr = __preset.rootIndexes;
                    console.log("Preset Changed: " + __preset.name + " -- " + rr);
                    for (var i = 0; i < _max_roots; i++) {
                        if (i < rr.length) {
                            // TODO	??
                            idRoot.itemAt(i).currentIndex = _ddRoots.indexOf(_rootLabels[rr[i]]);
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
            ScrollView {
                id: flickable
                Layout.alignment: Qt.AlignLeft
                Layout.fillWidth: true
                implicitHeight: idRootsGrid.implicitHeight /*+ sbRoots.height*/ + 5
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

                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            } // scrollview scale mode

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
        // RowLayout {
        GridLayout {
            //Layout.column : 1
            //Layout.row : 1
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            columns:3

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
                id: chkSingleScoreExport
                text: "One score for all"
                checked: true
                enabled: !chkByPattern.checked && modeIndex() === 0
                ToolTip.text: "When grouping the pattern by roots, use one score for all the patterns or export every root on its own pattern."
                ToolTip.delay: tooltipShow
                ToolTip.timeout: tooltipHide
                ToolTip.visible: hovered
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
                enabled: chkStrictLayout.checked
                checked: true
                property bool valid: chkAdaptativeMeasure.checked && chkStrictLayout.checked
                ToolTip.text: "Adapt the score signatures to ensure that each patterns fits into one measure."
                ToolTip.delay: tooltipShow
                ToolTip.timeout: tooltipHide
                ToolTip.visible: hovered
            }
            CheckBox {
                id : chkLineBreak
                enabled: chkStrictLayout.checked
                checked : false
                property bool valid: chkLineBreak.checked && chkStrictLayout.checked
                text : "Line break after each repetition"
            }
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
        width: 800
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
                Layout.preferredWidth: 400
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

                text: ""
                Layout.preferredWidth: 400
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
            "rootIndexes": []
        },
        new presetClass("Chromatic progression", ["C","C#","D","Eb","E","F","F#","G","Ab","A","Bb","B","C"]),
        new presetClass("by Seconds", ["C","D","E","F#","G#","A#"]),
        new presetClass("Circle of fourths", ["C","F","Bb","Eb","Ab","Db","F#","B","E","A","D","G","C"]),
        new presetClass("Circle of fifths", ["C","G","D","A","E","B","F#","Db","Ab","Eb","Bb","F","C"]),
    ]

    function presetClass(name, rootNames) {
        this.name = name;
        Object.defineProperty(this, "rootIndexes", {
            get: function () {
                console.log("getting roots for " + this.name);
                var indexes = rootNames.map(function(name) {
                    for(var i=0;i<_rootsData.length;i++) {
                        console.log("Comparing "+name+" and "+_rootsData[i].cleanName);
                        if(_rootsData[i].cleanName===name) return i;
                    }
                    return -1;
                }).filter(function(e) {
                    return e>=0;
                });
                return indexes;
            },

            enumerable: true
        });
        this.root = this.rootIndexes[0];

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
                    var id=this.steps[i];
                    var lb=_degrees.filter(function(e) { return e.id===id;});
                    label += (lb && lb.length>0)?lb[0].label:"?";
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
     * chords is an array of {
         "root": index_in__chords_array, 
         "type": key_in__chordTypes_map
         "chordnotes"
         "bass"
         "sharp": true|false|undefined
         "name"
         "end": true|false si l'accord est une fin (il faut par ex un retour chariot)
         "key": "bbb", "#", "", ... la clé de la phrase
         }
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
                label += _rootsData[chords[i].root].rootLabel + this.chords[i].type;
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

        if (debugPrint) console.log("Analyzing track " + (((track !== undefined) && (track != null)) ? track : "all") + ", above " + (abovetick ? abovetick : "-1"));

        if ((track !== undefined) && (track != null)) {
            duration = _computeRemainingRest(measure, track, abovetick);
            return duration;

        } else {
            duration = 999;
            // Analyze made on all tracks
            for (var t = 0; t < curScore.ntracks; t++) {
                if (tracePrint) console.log(">>>> " + t + "/" + curScore.ntracks + " <<<<");
                var localavailable = _computeRemainingRest(measure, t, abovetick);
                if (tracePrint) console.log("Available at track " + t + ": " + localavailable + " (" + duration + ")");
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

        if (debugPrint) console.log("_computeRemainingRest: " + (((track !== undefined) && (track != null)) ? track : "all") + ", above tick " + (abovetick ? abovetick : "-1"));

        if ((track !== undefined) && (track != null)) {
            // Analyze limited to one track
            var inTail = true;
            while ((last != null)) {
                var element = _d(last, track);
                // if ((element != null) && ((element.type == Element.CHORD) )) {
                if ((element != null) && ((element.type == Element.CHORD) || (last.tick <= abovetick))) { // 16/3/22
                    if (inTail)
                        if (tracePrint) console.log("switching outside of available buffer");
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
        if (tracePrint) console.log(" At " + last.tick + "/" + track + ": " + ((el !== null) ? el.userName() : " / "));
        return el;
    }


}