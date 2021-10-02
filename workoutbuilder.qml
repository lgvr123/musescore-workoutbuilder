import QtQuick 2.9
import QtQuick.Controls 2.2
import MuseScore 3.0
import QtQuick.Window 2.2
import QtQuick.Dialogs 1.2
import QtQuick.Controls.Styles 1.4
import QtQuick.Layouts 1.1
import FileIO 3.0

import "zparkingb/notehelper.js" as NoteHelper
import "workoutbuilder"

/**********************
/* Parking B - MuseScore - Scale Workout builder plugin
/* v1.1.0
/* ChangeLog:
/* 	- 0.0.0: Initial release
/*  - 1.0.0: Tools and library of patterns and workouts
/*  - 1.1.0: Transposing instruments, New options for measure management, order in the workouts list, ...
/*  - 1.2.0: Pattern name
/**********************************************/
MuseScore {
    menuPath: "Plugins." + pluginName
    description: "This plugin builds chordscale workouts based on patterns defined by the user."
    version: "1.2.0"

    pluginType: "dialog"
    requiresScore: false
    width: 1350
    height: 700

    id: mainWindow

    readonly property var pluginName: "Scale Workout Builder"
    readonly property var noteHelperVersion: "1.0.3"

    readonly property var librarypath: { {
            var f = Qt.resolvedUrl("workoutbuilder/workoutbuilder.library");
            f = f.slice(8); // remove the "file:///" added by Qt.resolveUrl and not understood by the FileIO API
            return f;
        }
    }
    onRun: {

        // Versionning
        if ((typeof(NoteHelper.checkVersion) !== 'function') || !NoteHelper.checkVersion(noteHelperVersion)) {
            console.log("Invalid zparkingb/notehelper.js versions. Expecting " + noteHelperVersion + ".");
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
        //console.log(Qt.resolvedUrl("MuseJazz.mss"));
        console.log(librarypath);
        console.log(libraryFile.source);

        loadLibrary();

        //		console.log(FileIO.homePath() + "/MuseJazz.mss");
        //		console.log(rootPath() + "/MuseJazz.mss");

    }

    property int _max_patterns: 10
    property int _max_steps: 12
    property int _max_roots: 12
    property var _degrees: ['1', 'b2', '2', 'm3', 'M3', '4', 'b5', '5', 'm6', 'M6', 'm7', 'M7',
        '(8)', 'b9', '9', '#9', 'b11', '11', '#11', '(12)', 'b13', '13', '#13', '(14)']

    property var _instruments: [{
            "label": "C Instruments (default)",
            "instrument": "flute",
            "cpitch": 60,
        }, {
            "label": "B♭ instruments",
            "instrument": "soprano-saxophone",
            "cpitch": 48,
        }, {
            "label": "E♭ instruments",
            "instrument": "eb-clarinet",
            "cpitch": 60,
        }, {
            "label": "D instruments",
            "instrument": "d-trumpet",
            "cpitch": 60,
        }, {
            "label": "E instruments",
            "instrument": "e-trumpet",
            "cpitch": 60,
        }, {
            "label": "F instruments",
            "instrument": "horn",
            "cpitch": 48,
        }, {
            "label": "G instruments",
            "instrument": "alto-flute",
            "cpitch": 48,
        }, {
            "label": "A instruments",
            "instrument": "a-cornet",
            "cpitch": 48,
        },
    ]

    property var _loops: [{
            "type": 0,
            "label": "No repetition",
            "image": "none.png",
            "id": "--"
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
            "short": "Reserve Cycled",
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

        "Maj": {
            "symb": "",
            "scale": [0, 2, 4, 5, 7, 9, 11, 12]
        },
        "Min": {
            "symb": "-",
            "scale": [0, 2, 3, 5, 7, 8, 10, 12]
        },
        "Maj7": {
            "symb": "t7",
            "scale": [0, 2, 4, 5, 7, 9, 11, 12]
        },
        "Dom7": {
            "symb": "7",
            "scale": [0, 2, 4, 5, 7, 9, 10, 12]
        },
        "Min7": {
            "symb": "-7",
            "scale": [0, 2, 3, 5, 7, 8, 10, 12]
        },
        "Bepop": {
            "symb": "-7",
            "scale": [0, 2, 4, 5, 7, 9, 10, 11, 12]
        },
    }

    property var _ddChordTypes: { {
            var dd = [''];
            dd = dd.concat(Object.keys(_chordTypes));
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
            "major": false,
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
            var dd = [''];
            dd = dd.concat(_degrees);
            return dd;
        }
    }

    property var patterns: { {

            var sn = [];

            for (var i = 0; i < _max_patterns; i++) {
                for (var j = 0; j < _max_steps; j++) {
                    var _sn = {
                        "pattern": i,
                        "step": j,
                        "note": '',
                    };
                    sn.push(_sn);
                }
            }
            return sn;
        }
    }

    property var steproots: { {
            var sr = [];
            for (var j = 0; j < _max_roots; j++) {
                sr.push('');
            }
            return sr;
        }
    }

    property var library: []
    property var workouts: []

    readonly property int tooltipShow: 500
    readonly property int tooltipHide: 5000

    property var clipboard: undefined

    property var rootSchemeName: undefined
    property var workoutName: undefined

    function printWorkout() {

        var patts = [];

        // 1) Collect the patterns and their definition
        for (var i = 0; i < _max_patterns; i++) {
            // 1.1) Collecting the basesteps
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

            if (p.length == 0) {
                break;
            }

            // 1.2) Retrieving loop mode
            var mode = idLoopingMode.itemAt(i).currentIndex
                mode = _loops[mode];
            console.log("looping mode : " + mode.label);

            // Retrieving Chord type
            var cText = idChordType.itemAt(i).editText; // editable
            if (cText === '') {
                var m3 = (p.indexOf(3) > -1); // if we have the "m3" the we are in minor mode.
                if (p.indexOf(10) > -1) { //m7
                    cText = m3 ? "Min7" : "Dom7";
                } else if (p.indexOf(11) > -1) { //M7
                    cText = m3 ? "Min7" : "Maj7";
                } else {
                    cText = m3 ? "Min" : "Maj";
                }

            }
            var cSymb = _chordTypes[cText];
            if (cSymb === undefined) {
                cSymb = cText.includes("-") ? _chordTypes['Min'] : _chordTypes['Maj']; // For user-specific chord type, we take a Major scale, or the Min scale of we found a "-"
                cSymb.symb = cText;
            }

            console.log("Pattern " + i + ": " + cText + " > " + cSymb);

            // Build final pattern
            var pattern = {
                "notes": p,
                "loopAt": mode,
                "chord": cSymb,
				"name": idPattName.itemAt(i).text
            };
            patts.push(pattern);

        }

        // Collecting the roots
        var roots = [];
        for (var i = 0; i < _max_roots; i++) {
            var txt = steproots[i];
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
            missingStuffDialog.open();
            return;
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
                var mode = (pp.notes.indexOf(3) > -1) ? "minor" : "major"; // if we have the "m3" the we are in minor mode.
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
                    var mode = (pp.notes.indexOf(3) > -1) ? "minor" : "major"; // if we have the "m3" the we are in minor mode.


                    // Looping through the "loopAt" subpatterns
                    for (var s = 0; s < pp["subpatterns"].length; s++) {
                        if (pages[page] === undefined)
                            pages[page] = [];

                        var basesteps = pp["subpatterns"][s];

                        var notes = [];

                        for (var j = 0; j < basesteps.length; j++) {
                            notes.push(root + basesteps[j]);
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

        // Debug
        /*for (var i = 0; i < pages.length; i++) {
        console.log("[" + i + "]" + pages[i]);
        //if (pages[i]===undefined) continue; // ne devrait plus arriver
        for (var j = 0; j < pages[i].length; j++) {
        for (var k = 0; k < pages[i][j].notes.length; k++) {
        console.log(i + ") [" + pages[i][j].root + "/" + pages[i][j].mode + "] " + pages[i][j].notes[k]);
        }
        }
        }*/

        var instru = _instruments[lstTransposition.currentIndex];
        console.log("Instrument is " + instru.label);

        // Push all this to the score
        var score = newScore("Workout", instru.instrument, 1);

        var title = (workoutName !== undefined) ? workoutName : "Scale workout";
        title += " - ";
        if (rootSchemeName != undefined) {
            title += rootSchemeName;
        } else {
            var sr = steproots.filter(function (s) {
                return (s !== undefined) && (s.trim() !== "");
            });
            title += sr.join(", ");
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
            beatsByMeasure = signatureForPattern(pages[0][0].notes.length);
        } else {
            beatsByMeasure = 4;
        }
        console.log("Adapting measure to " + beatsByMeasure + "/4");
        var ts = newElement(Element.TIMESIG);
        ts.timesig = fraction(beatsByMeasure, 4);
        cursor.add(ts);

        cursor.rewind(0);
        var cur_time = cursor.segment.tick;

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
            var prevChord = 'xxxxxxxxxxxxxxx'
                for (var j = 0; j < pages[i].length; j++) {
                    var root = pages[i][j].root;
                    var chord = pages[i][j].chord;
                    var mode = pages[i][j].mode;
                    if (root !== prevRoot || mode !== prevMode) {
                        preferredTpcs = filterTpcs(root, mode);
                    }

                    if (adaptativeMeasure) {
                        beatsByMeasure = signatureForPattern(pages[i][j].notes.length);
                    } else {
                        beatsByMeasure = 4;
                    }

                    for (var k = 0; k < pages[i][j].notes.length; k++, counter++) {
                        if (counter > 0) {
                            cursor.rewindToTick(cur_time); // be sure to move to the next rest, as now defined
                            var success = cursor.next();
                            if (!success) {
                                score.appendMeasures(1);
                                cursor.rewindToTick(cur_time);

                                if (newLine) {
                                    var measure = cursor.measure;
                                    console.log("Delayed change of ending bar line");
                                    addDoubleLineBar(measure, score);
                                }

                                cursor.next();
                            }
                        }

                        cursor.setDuration(1, 4); // quarter
                        var note = cursor.element;

                        var delta = pages[i][j].notes[k];
                        var pitch = instru.cpitch + delta;
                        var sharp_mode = true;
                        var f = _chords[root][mode];
                        if (f !== undefined)
                            sharp_mode = f;

                        var target = {
                            "pitch": pitch,
                            "concertPitch": false,
                            "sharp_mode": f
                        };

                        //cur_time = note.parent.tick; // getting note's segment's tick
                        cur_time = cursor.segment.tick;

                        note = NoteHelper.restToNote(note, target);

                        // Adding the chord's name
                        if (prevChord !== chord.symb || prevRoot !== root) {
                            var csymb = newElement(Element.HARMONY);
                            var rtxt = _chords[root].root.replace(/♯/gi, '#').replace(/♭/gi, "b");

                            // chord's roots
                            if (!rtxt.includes("/")) {
                                csymb.text = rtxt;
                            } else {
                                var parts = rtxt.split("/");
                                if (parts[0].includes("#")) {
                                    if (sharp_mode)
                                        csymb.text = parts[0];
                                    else
                                        csymb.text = parts[1]
                                } else {
                                    if (sharp_mode)
                                        csymb.text = parts[1];
                                    else
                                        csymb.text = parts[0]
                                }
                            }

                            // chord's type
                            csymb.text += chord.symb;

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
                            console.log("Adapting measure to " + beatsByMeasure + "/4");
                            var ts = newElement(Element.TIMESIG);
                            ts.timesig = fraction(beatsByMeasure, 4);
                            cursor.add(ts);
                            //cursor.rewindToTick(cur_time); // be sure to move to the next rest, as now defined
                            //cursor.next();
                            prevBeatsByM = beatsByMeasure;
                        }

                        //debugNote(delta, note);

                        prevRoot = root;
                        prevChord = chord.symb;
                        prevMode = mode;
                        prevPage = i;
                        newLine = false;

                    }

                    // Fill with rests until end of measure
                    if (chkStrictLayout.checked) {
                        var fill = pages[i][j].notes.length % beatsByMeasure;
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

    function extendPattern(pattern) {
        var extpattern = pattern;
        var basesteps = pattern.notes;
        var scale = pattern.chord.scale;
        var loopAt = pattern.loopAt;

        extpattern.representation = (pattern.name && pattern.name!=="")?pattern.name:patternToString(pattern.notes, pattern.loopAt);

        extpattern["subpatterns"] = [];

        // first the original pattern
        extpattern["subpatterns"].push(basesteps);

        if (loopAt.type == 0) {
            console.log("Looping patterns : no loop requested");
            return extpattern;
        }

        // looping patterns

        if ((loopAt.type > 0) && (Math.abs(loopAt.shift) < basesteps.length) && (loopAt.shift != 0)) {
            // 1) Regular loopAt mode, where we loop from the current pattern, restarting the pattern (and looping)
            // from the next step of it : A-B-C, B-C-A, C-A-B
            console.log("Looping patterns : regular mode");

            // octave up or down ? Is the pattern going up or going down ?
            var pattdir = 1;
            if (basesteps[0] > basesteps[basesteps.length - 1])
                pattdir = -1; // first is higher than last, the pattern is going down
            else if (basesteps[0] == basesteps[basesteps.length - 1])
                pattdir = 0; // first is equal to last, the pattern is staying flat


            // We'll tweak the original pattern one to have flowing logically among the subpatterns
            if (pattdir < 0) {
                // En mode decreasing, je monte toute la pattern d'une octave
                var octaveup = [];
                for (var i = 0; i < basesteps.length; i++) {
                    basesteps[i] = basesteps[i] + 12;
                }
            } else if ((loopAt.shift < 0) && (pattdir > 0)) {
                // En mode increasing mais reverse, je monte que la 1ère pattern
                var octaveup = [];
                for (var i = 0; i < basesteps.length; i++) {
                    octaveup[i] = basesteps[i] + 12;
                }
                extpattern["subpatterns"][0] = octaveup;
            }

            var e2e = false;
            var e2edir = 0;
            if ((Math.abs(basesteps[0] - basesteps[basesteps.length - 1]) == 12) || (basesteps[0] == basesteps[basesteps.length - 1])) {
                //
                e2e = true;
                e2edir = (basesteps[basesteps.length - 1] - basesteps[0]) / 12; // -1: C4->C3, 0: C4->C4, 1: C4->C5
                basesteps = [].concat(basesteps); // clone basesteps to not alter the gloable pattern
                basesteps.pop(); // Remove the last step
            }

            var debug = 0;
            var from = (loopAt.shift > 0) ? 0 : basesteps.length; // delta in index of the pattern for the regular loopAt mode
            while (debug < 999) {
                debug++;

                // Building next start point
                from += loopAt.shift;
                console.log("Regular Looping at " + from);

                // Have we reached the end ?
                if ((loopAt.shift > 0) && (from > 0) && ((from % basesteps.length) == 0))
                    break;
                else if ((loopAt.shift < 0) && (from == 0))
                    break;

                var p = [];
                for (var j = 0; j < basesteps.length; j++) {
                    var idx = (from + j) % basesteps.length
                    var octave = Math.floor((from + j) / basesteps.length);
                    // octave up or down ? Is the pattern going up or going down ?
                    octave *= pattdir;

                    console.log(">should play " + basesteps[idx] + " but I'm playing " + (basesteps[idx] + octave * 12) + " (" + octave + ")");
                    p.push(basesteps[idx] + octave * 12);
                }
                if (e2e) {
                    // We re-add the first note
                    p.push(p[0] + 12 * e2edir);
                }

                extpattern["subpatterns"].push(p);
            }
        } else if (loopAt.type < 0) {
            // 2) Scale loopAt mode, we decline the pattern along the scale (up/down, by degree/Triad)
            var shift = loopAt.shift; //Math.abs(loopAt) * (-1);
            console.log("Looping patterns : scale mode (" + shift + ")");
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
                    extpattern["subpatterns"].push(shifted);
                    if (counter > 99) // security
                        break;
                }
            }

        }

        return extpattern;

    }

    function shiftPattern(pattern, scale, step) {
        var pdia = [];
        // 1) convert a chromatic pattern into a diatonic pattern
        for (var ip = 0; ip < pattern.length; ip++) {
            // for every step of the pattern we look for its diatonic equivalent.
            // And a delta. For a b5, while in major scale, we will retrieve a degree of "4" + a delta of 1 semitone
            var p = pattern[ip];
            var o = Math.floor(p / 12);
            p = p % 12;
            var d = undefined;
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

            pdia.push(d);
            console.log("[shift " + step + "] 1)[" + ip + "]" + p + "->" + debugDia(d));
        }

        // 2) shift the diatonic pattern by the amount of steps
        for (var ip = 0; ip < pdia.length; ip++) {
            var d = pdia[ip];
            d.degree += step;
            d.octave += Math.floor(d.degree / 7); // degrees are ranging from 0->6, 7 is 0 at the nexy octave //scale.length);
            d.degree = d.degree % 7; //scale.length;
            pdia[ip] = d;
            console.log("[shift " + step + "] 2)[" + ip + "]->" + debugDia(d));
        }

        // 3) Convert back to a chromatic scale
        var pshift = [];
        for (var ip = 0; ip < pdia.length; ip++) {
            var d = pdia[ip];
            if (d.degree >= scale.length) {
                // We are beyond the scale, let's propose some value
                d.semi += (d.degree - scale.length + 1) * 1; // 1 semi-tone by missing degree
                d.degree = scale.length - 1;
                if ((scale[d.degree] + d.semi) >= 12)
                    d.semi = 11;
            }
            var s = scale[d.degree] + 12 * d.octave + d.semi;
            pshift.push(s);
            console.log("[shift " + step + "] 3)[" + ip + "]" + debugDia(d) + "->" + s);
        }

        return pshift;

    }

    function signatureForPattern(count) {
        if ((count % 4) == 0)
            return 4;
        else if ((count % 3) == 0)
            return 3;
        else if ((count % 5) == 0)
            return 5;
        else
            return count;
    }

    function patternToString(pattern, loopAt) {
        var str = "";
        for (var i = 0; i < pattern.length; i++) {
            if (i > 0)
                str += "/";
            var d = _degrees[pattern[i]];
            d = d.replace("(", "");
            d = d.replace(")", "");
            str += d;
        }

        if (loopAt.type != 0) {
            str += " - ";
            str += loopAt["short"];
        }

        return str;
    }

    function debugDia(d) {
        return "{degree:" + d.degree + ",semi:" + d.semi + ",octave:" + d.octave + "}";
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

    /**
     * Changes a ending measure bar line to a double one.
     * !! If the measure is the last one of the score, adding a new measure after will override this change.
     */
    function addDoubleLineBar(measure, score) {
        // The ending line bar for ameasure added by the API is viewable only after the measure addition is enclosed in its own startCmd/endCmd
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

    function toClipboard(index) {
        console.log("To Clipboard for pattern " + index);
        clipboard = getPattern(index);
    }

    function fromClipboard(index) {
        console.log("From Clipboard for pattern " + index + "(clipboard is " + ((clipboard !== undefined) ? "defined" : "undefined") + ")");
        if (clipboard === undefined)
            return;
        setPattern(index, clipboard);
    }

    function clearPattern(index) {
        setPattern(index, undefined)
    }

    function getPattern(index) {
        var steps = [];
        for (var i = 0; i < _max_steps; i++) {
            var note = patterns[index * _max_steps + i].note;
            if (note !== '') {
                var d = _degrees.indexOf(note);
                if (d > -1)
                    steps.push(d);
            } else
                break;
        }

        var mode = idLoopingMode.itemAt(index).currentIndex;
        mode = _loops[mode].id;

        var scale = idChordType.itemAt(index).editText;
		
		var name= idPattName.itemAt(index).text;

        var p = new patternClass(steps, mode, scale,name);

        console.log(p.label);

        return p;

    }

    function setPattern(index, pattern) {
        console.log("Setting pattern " + index);

        for (var i = 0; i < _max_steps; i++) {
            var ip = index * _max_steps + i;
            var note = (pattern !== undefined && (i < pattern.steps.length)) ? _degrees[pattern.steps[i]] : '';
            // setting  only the 'note' field the doesn't work because the binding is not that intelligent...
            var sn = patterns[ip];
            sn.note = note;
            // ..one must reassign explicitely the whole object in the combobox to trigger the binding's update
            idStepNotes.itemAt(ip).item.step = sn;

        }

        var scale = '';
        if ((pattern !== undefined) && (pattern.scale !== undefined)) {
            scale = pattern.scale;
        }
        idChordType.itemAt(index).editText = scale;

        var modeidx = 0;
        if ((pattern !== undefined) && (pattern.loopMode !== undefined)) {
            console.log("pasting mode " + pattern.loopMode);
            for (var i = 0; i < _loops.length; i++) {
                if (_loops[i].id === pattern.loopMode) {
                    modeidx = i;
                    break;
                }
            }
        }
		
        console.log("pasting mode index " + modeidx);
        idLoopingMode.itemAt(index).currentIndex = modeidx;

		var name=(pattern && pattern.name)?pattern.name:"";
		idPattName.itemAt(index).text=name;	


    }

    function savePattern(index) {
        var p = getPattern(index);
        var i = findInLibrary(p);
        if (i < 0) { // pattern not found in library
            console.log("Pattern " + p.label + " added to the library");
            library.push(p);
            resetL = !resetL;
            saveLibrary();
        } else {
            console.log("Pattern " + p.label + " not added to the library - already present");
        }
    }

    function deletePattern(pattern) {
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

    function applyWorkout(workout) {
        // patterns
        var m = (workout !== undefined) ? Math.min(_max_patterns, workout.patterns.length) : 0;

        for (var i = 0; i < m; i++) {
            setPattern(i, workout.patterns[i]);
        }

        for (var i = m; i < _max_patterns; i++) {
            setPattern(i, undefined);
        }

        // roots, if defined in the workout
        if (workout !== undefined && workout.roots !== undefined) {
            m = Math.min(_max_roots, workout.roots.length);

            for (var i = 0; i < m; i++) {
                steproots[i] = _roots[workout.roots[i]];
            }

            for (var i = m; i < _max_patterns; i++) {
                steproots[i] = '';
            }

        }

        // options, if defined in the workout
        if (workout !== undefined && workout.bypattern !== undefined) {
            chkByPattern.checkState = (workout.bypattern === "true") ? Qt.Checked : Qt.Unchecked;

        }
        if (workout !== undefined && workout.invert !== undefined) {
            chkInvert.checkState = (workout.invert === "true") ? Qt.Checked : Qt.Unchecked;
        }

        workoutName = (workout !== undefined) ? workout.name : undefined;

    }

    function buildWorkout(label) {

        var pp = [];
        for (var i = 0; i < _max_patterns; i++) {
            var p = getPattern(i);
            if (p.steps.length == 0)
                break;
            pp.push(p);
        }

        var workout = new workoutClass(label, pp);

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
        workouts.push(workout);
        resetL = !resetL;
        saveLibrary();
        workoutName = workout.name;
    }

    /**
     * Simply adds that workout on top of the workouts list. No verification of duplicates is performed.
     */
    function replaceWorkout(oldWorkout, newWorkout) {
        for (var i = 0; i < workouts.length; i++) {
            console.log(workouts[i].name + " (" + workouts[i].hash + ") <> " + oldWorkout.name + " (" + oldWorkout.hash + ")");
            if (workouts[i].hash == oldWorkout.hash) {
                console.log("REPLACING THIS ONE");
                workouts[i] = newWorkout;
                break;
            }
        }
        resetL = !resetL;
        saveLibrary();
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

        var allpresets = lib.patterns;

        for (var i = 0; i < allpresets.length; i++) {
            var pp = allpresets[i];
            var p = new patternClassRaw(pp);
            library.push(p);
        }
        console.log("Library loaded");

        var allworkouts = lib.workouts;
        for (var i = 0; i < allworkouts.length; i++) {
            var pp = allworkouts[i];
            var p = new workoutClassRaw(pp);
            workouts.push(p);
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
            workouts: workouts
        };

        var t = JSON.stringify(lib) + "\n";
        console.log(t);

        if (libraryFile.write(t)) {
            console.log("Library saved");
        } else {
            console.log("Error while saving the library");
        }
    }

    property bool reset: true
    property bool resetP: true
    property bool resetL: true

    GridLayout {
        anchors.fill: parent
        anchors.margins: 25
        columnSpacing: 10
        rowSpacing: 10
        columns: 2

        GridLayout { // un small element within the fullWidth/fullHeight where we paint the repeater
            //anchors.verticalCenter : parent.verticalCenter
            id: idNoteGrid
            rows: _max_patterns + 1
            columns: _max_steps + 2
            columnSpacing: 0
            rowSpacing: 0

            //Layout.column : 0
            //Layout.row : 0
            Layout.columnSpan: 2

            Layout.alignment: Qt.AlignCenter
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

            Repeater {
                id: idNoteLabels
                model: _max_steps

                Label {
                    Layout.row: 0
                    Layout.column: index + 1
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                    Layout.rightMargin: 2
                    Layout.leftMargin: 2
                    Layout.bottomMargin: 5
                    text: (index + 1)
                }
            }
            Repeater {
                id: idStepNotes
                model: getPatterns(resetP)

                Loader {
                    id: loaderNotes
                    property int stepIndex: index % _max_steps
                    property int patternIndex: Math.floor(index / _max_steps)
                    Layout.row: 1 + patternIndex
                    Layout.column: 1 + stepIndex
                    Binding {
                        target: loaderNotes.item
                        property: "step"
                        value: patterns[patternIndex * _max_steps + stepIndex]
                    }
                    sourceComponent: stepComponent
                }

            }

            Label {
                Layout.row: 0
                Layout.column: _max_steps + 2
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                Layout.rightMargin: 2
                Layout.leftMargin: 2
                Layout.bottomMargin: 5
                text: "Repeat"
            }

            Repeater {
                id: idLoopingMode
                model: _max_patterns

                ComboBox {
                    //Layout.fillWidth : true
                    id: lstLoop
                    model: _loops

                    //clip: true
                    //focus: true
                    Layout.row: index + 1
                    Layout.column: _max_steps + 2
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                    Layout.rightMargin: 2
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 80

                    delegate: ItemDelegate { // requiert QuickControls 2.2
                        contentItem: Image {
                            height: 25
                            width: 25
                            source: "./workoutbuilder/" + _loops[index].image
                            fillMode: Image.Pad
                            verticalAlignment: Text.AlignVCenter
                            ToolTip.text: _loops[index].label
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
                        source: "./workoutbuilder/" + _loops[lstLoop.currentIndex].image

                        ToolTip.text: _loops[lstLoop.currentIndex].label
                        ToolTip.delay: tooltipShow
                        ToolTip.timeout: tooltipHide
                        ToolTip.visible: hovered

                    }
                }
            }

            Label {
                Layout.row: 0
                Layout.column: _max_steps + 3
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                Layout.rightMargin: 2
                Layout.leftMargin: 2
                Layout.bottomMargin: 5
                text: "Scale"
            }

            Repeater {
                id: idChordType
                model: _max_patterns

                ComboBox {
                    id: ccCT
                    model: _ddChordTypes
                    editable: true
                    Layout.row: index + 1
                    Layout.column: _max_steps + 3
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                    Layout.rightMargin: 2
                    Layout.leftMargin: 2
                    Layout.preferredWidth: 90
                }
            }

            Repeater {
                id: idTools
                model: _max_patterns

                Rectangle {

                    Layout.row: index + 1
                    Layout.column: _max_steps + 4
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
                            imageSource: "download.svg"
                            ToolTip.text: "Set pattern's name"+
							((idPattName.itemAt(index).text!="")?("\n\""+idPattName.itemAt(index).text+"\""):"\n--default--")
							highlighted: (idPattName.itemAt(index).text!="")
                            onClicked: {
                                patternNameInputDialog.index = index;
                                patternNameInputDialog.open();
						
                            }
                        }
                    }
                }
            }

            Repeater {
                id: idPattName
                model: _max_patterns

                Text {
                    id: txtPN
                    text: ""
                    visible: false
                    Layout.row: index + 1
                    Layout.column: _max_steps + 5
                }
            }

        }

        // Presets
        Label {
            //Layout.column : 0
            //Layout.row : 2
            text: "Presets:"

        }

        ComboBox {
            id: lstPresets
            model: presets

            Layout.preferredWidth: 220

            //Layout.column : 1
            //Layout.row : 2

            contentItem: Text {
                text: lstPresets.displayText
                verticalAlignment: Qt.AlignVCenter
            }

            delegate: ItemDelegate { // requiert QuickControls 2.2
                contentItem: Text {
                    text: modelData.name
                    verticalAlignment: Text.AlignVCenter
                }
                highlighted: lstPresets.highlightedIndex === index

            }
            onCurrentIndexChanged: {
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

                rootSchemeName = __preset.name;
            }
        }

        // Roots
        Label {
            //Layout.column : 0
            //Layout.row : 3
            text: "Roots:"
        }
        RowLayout {
            spacing: 5
            Layout.alignment: Qt.AlignLeft
            //Layout.column : 1
            //Layout.row : 3

            Repeater {
                id: idRoot
                model: getRoots(reset)

                Loader {
                    id: loaderRoots
                    Binding {
                        target: loaderRoots.item
                        property: "rootIndex"
                        value: model.index
                    }
                    sourceComponent: rootComponent
                }

            }

        }

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
                checked: true
                ToolTip.text: "All the patterns will be applied on the first root notes. Then the next root note. And so on.\nAlternatively, the first pattern will be applied for all the root notes. Then the next pattern. And so on."
                ToolTip.delay: tooltipShow
                ToolTip.timeout: tooltipHide
                ToolTip.visible: hovered
            }
            CheckBox {
                id: chkInvert
                text: "Invert pattern every two roots"
                checked: false
                enabled: chkByPattern.checked
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

    Component {
        id: stepComponent

        ComboBox {
            id: lstStep
            property var step: {
                "step": 0,
                "pattern": 0,
                "note": ''
            }
            Layout.alignment: Qt.AlignLeft | Qt.QtAlignBottom
            editable: false
            model: _ddNotes
            Layout.preferredHeight: 30
            implicitWidth: 75
            currentIndex: find(step.note, Qt.MatchExactly)
            onCurrentIndexChanged: {
                step.note = model[currentIndex];
            }
        }
    }

    Component {
        id: rootComponent

        ComboBox {
            id: lstRoot
            property var rootIndex
            Layout.alignment: Qt.AlignLeft | Qt.QtAlignBottom
            editable: false
            model: _ddRoots
            currentIndex: find(steproots[rootIndex], Qt.MatchExactly)
            Layout.preferredHeight: 30
            implicitWidth: 90
            onCurrentIndexChanged: {
                steproots[rootIndex] = model[currentIndex]
                    console.log("Root " + rootIndex + ": " + steproots[rootIndex]);
            }

            onActivated: {
                // manual change, resetting the rootSchemeName
                rootSchemeName = undefined;
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
                        target: lstLibrary;
                        model: getPresetsLibrary(resetL)
                    }
                    PropertyChanges {
                        target: btnDelPatt;
                        ToolTip.text: "Delete the selected pattern from the library"
                    }

                },
                State {
                    name: "workout";
                    PropertyChanges {
                        target: lstLibrary;
                        model: getWorkoutsLibrary(resetL)
                    }
                    PropertyChanges {
                        target: btnDelPatt;
                        ToolTip.text: "Delete the selected workout from the library"
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
                                    if (loadWindow.state === "pattern") {
                                        setPattern(loadWindow.index, library[model.index]);
                                    } else {
                                        applyWorkout(workouts[model.index]);
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
                                left: parent.left
                                right: parent.right
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
                            if (loadWindow.state === "pattern") {
                                confirmRemovePatternDialog.pattern = library[lstLibrary.currentIndex];
                                confirmRemovePatternDialog.open();
                            } else {
                                confirmRemovePatternDialog.pattern = workouts[lstLibrary.currentIndex];
                                confirmRemovePatternDialog.open();
                            }
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
                            if (loadWindow.state === "pattern") {
                                setPattern(loadWindow.index, library[lstLibrary.currentIndex]);
                            } else {
                                applyWorkout(workouts[lstLibrary.currentIndex]);
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
        title: "Save workout..."
        //modal: true
        standardButtons: Dialog.Save | Dialog.Cancel

        RowLayout {
            Label {
                text: "Save workout as:"
            }

            TextField {
                id: txtWorkoutName

                //Layout.preferredHeight: 30
                text: ""
                Layout.fillWidth: true
                placeholderText: "Enter new workout's name"
                maximumLength: 255

            }
        }

        onAccepted: {
            var name = txtWorkoutName.text.trim();
            console.log("==> " + name);
            if ("" === name)
                return;
            var workout = buildWorkout(name);
            console.log(workout.label);
            newWorkoutDialog.close();
            var conflict = verifyWorkout(workout, true);
            if (conflict == null) // no conflict
                saveWorkout(workout);
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
                text: "Save workout as:"
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
                txtInputPatternName.text = ((index === -1)) ? "??" :idPattName.itemAt(index).text;
            }
        }

        onAccepted: {
            if (index === -1)
                return;
            var name = txtInputPatternName.text.trim();
            console.log("==> " + name);
            patternNameInputDialog.close();
            idPattName.itemAt(index).text = name;
        }
        onRejected: patternNameInputDialog.close();

    }

    MessageDialog {
        id: confirmReplaceWorkoutDialog
        title: "Save workout..."
        icon: StandardIcon.Question

        standardButtons: StandardButton.Save | StandardButton.Cancel

        property var origworkout: {
            label: "--"
        }
        property var newworkout: {
            label: "--"
        }

        text: "The following workout:\n" + origworkout.label +
        "\nwill be " + ((origworkout.hash == newworkout.hash) ? "renamed into" : "redefined as") + ":\n" +
        newworkout.label + "\n\n.Do you want to proceed ?"

        onAccepted: {
            replaceWorkout(origworkout, newworkout);
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
        text: 'Please confirm the deletion of the following ' +
        ((loadWindow.state === "pattern") ? "pattern" : "workout") +
        ' : <br/>' + ((pattern == null) ? "--" : pattern.label)
        onYes: {
            confirmRemovePatternDialog.close();
            if (loadWindow.state === "pattern") {
                deletePattern(pattern);
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
        text: "Invalid 'zparkingb/notehelper.js' versions.\nExpecting "+ noteHelperVersion + ".\n" + pluginName + " will stop here."
        onAccepted: {
            Qt.quit()
        }
    }

    function getRoots(uglyHack) {
        return steproots;
    }

    function getPatterns(uglyHack) {
        return patterns;
    }

    function getPresetsLibrary(uglyHack) {
        //console.log("Library has " + library.length + " elements");
        return library;
    }

    function getWorkoutsLibrary(uglyHack) {
        //console.log("Library has " + library.length + " elements");
        return workouts;
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

    function patternClass(steps, loopMode, scale, name) {
        this.steps = (steps !== undefined) ? steps : [];
        this.loopMode = loopMode;
        this.scale = scale;
        this.name = (name && (name != null)) ? name : "";

        this.toJSON = function (key) {
            return {
                steps: this.steps,
                loopMode: this.loopMode,
                scale: this.scale,
                name: this.name
            };

        };

        // transient properties
        // label
        var label = "";
        if (steps.length == 0)
            label += "---";
        else
            for (var i = 0; ((i < steps.length) && (steps[i] !== undefined)); i++) {
                if (i > 0)
                    label += "-";
                label += _degrees[steps[i]];
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

        this.hash = hash;

    }

    /**
     * Creation of a pattern from a pattern object containing the *enumerable* fields (ie. the non transient fields)
     */
    function patternClassRaw(raw) {
        patternClass.call(this, raw.steps, raw.loopMode, raw.scale, raw.name);
    }

    function workoutClass(name, patterns, roots, bypattern, invert) {
        this.patterns = (patterns !== undefined) ? patterns : [];
        this.name = ((name !== undefined) && (name.trim() !== "")) ? name.trim() : "???";
        this.roots = roots;
        this.bypattern = bypattern;
        this.invert = invert;

        this.toJSON = function (key) {
            return {
                patterns: this.patterns,
                name: this.name,
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
        var p = raw.patterns;
        var pp = [];
        for (var i = 0; i < p.length; i++) {

            pp.push(new patternClassRaw(p[i]));
        }

        workoutClass.call(this, raw.name, pp, raw["roots"], raw["bypattern"], raw["invert"]);
    }

    FileIO {
        id: libraryFile
        source: librarypath
        onError: {
            console.log(msg);
        }
    }

    function debugO(label, element) {

        var kys = Object.keys(element);
        for (var i = 0; i < kys.length; i++) {
            console.log(label + ": " + kys[i] + "=" + element[kys[i]]);
        }
    }

}
