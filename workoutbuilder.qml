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
/* Parking B - MuseScore - Workout builder plugin
/* v1.1.0
/* ChangeLog:
/* 	- 1.0.0: Initial release
/*  - 1.1.0: Copy/Paste, Library of patterns
/**********************************************/
MuseScore {
    menuPath: "Plugins.Workout builder"
    description: "This plugin builds chordscale workouts based on patterns defined by the user."
    version: "1.1.0"

    pluginType: "dialog"
    requiresScore: false
    width: 1350
    height: 600

    id: mainWindow

    readonly property var librarypath: { {
            var f = Qt.resolvedUrl("workoutbuilder/workoutbuilder.library");
            f = f.slice(8); // remove the "file:///" added by Qt.resolveUrl and not understood by the FileIO API
            return f;
        }
    }
    onRun: {

        //console.log(Qt.resolvedUrl("MuseJazz.mss"));
        console.log(librarypath);
        console.log(libraryFile.source);

        loadLibrary();

        //		console.log(FileIO.homePath() + "/MuseJazz.mss");
        //		console.log(rootPath() + "/MuseJazz.mss");

    }

    property int _Cpitch: 48

    property int _max_patterns: 8
    property int _max_steps: 12
    property int _max_roots: 12
    property var _degrees: ['1', 'b2', '2', 'm3', 'M3', '4', 'b5', '5', 'm6', 'M6', 'm7', 'M7',
        '(8)', 'b9', '9', '#9', 'b11', '11', '#11', '(12)', 'b13', '13', '#13', '(14)']

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
            "label": "Repeat at every triade (ascending)",
            "short": "Triade up",
            "image": "triadeup.png",
            "shift": 2,
            "id": "S3+"

        }, {
            "type": -1,
            "label": "Repeat at every triade (descending)",
            "short": "Triade down",
            "image": "triadedown.png",
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
            "scale": [0, 2, 4, 5, 7, 9, 11]
        },
        "Min": {
            "symb": "-",
            "scale": [0, 2, 3, 5, 7, 8, 10]
        },
        "Maj7": {
            "symb": "t7",
            "scale": [0, 2, 4, 5, 7, 9, 11]
        },
        "Dom7": {
            "symb": "7",
            "scale": [0, 2, 4, 5, 7, 9, 10]
        },
        "Min7": {
            "symb": "-7",
            "scale": [0, 2, 3, 5, 7, 8, 10]
        },
        "Bepop": {
            "symb": "-7",
            "scale": [0, 2, 4, 5, 7, 9, 10, 11]
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
            "major": false, // we consider C as a flat scale, sothat a m7 is displayed as Bb instead of A#
            "minor": false
        }, {
            "root": 'Db/C#',
            "major": false,
            "minor": true
        }, {
            "root": 'D',
            "major": true,
            "minor": false
        }, {
            "root": 'Eb/D#',
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
            "root": 'F#/Gb',
            "major": true,
            "minor": true
        }, {
            "root": 'G',
            "major": true,
            "minor": false
        }, {
            "root": 'Ab/G#',
            "major": false,
            "minor": true
        }, {
            "root": 'A',
            "major": true,
            "minor": true
        }, {
            "root": 'Bb/A#',
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
                "chord": cSymb
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

        // Building the notes and their order
        var page = -1;
        if (chkByPattern.checked) {
            // We sort by patterns. By pattern, repeat over each root
            for (var p = 0; p < patts.length; p++) {
                var pp = extendPattern(patts[p]);
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
                    // On ne change pas de "page" entre root sauf si la pattern est "loopée", dans quel cas on change à chaque root.
                    if ((pp["subpatterns"].length > 1) && ((roots.length == 1) || (r < (roots.length - 1)))) {
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
                for (var p = 0; p < patts.length; p++) {
                    console.log("By R, patterns: " + p + "/" + (patts.length - 1) + "; roots:" + r + "/" + (roots.length - 1) + " => " + page);

                    var pp = extendPattern(patts[p]);
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

                    // On ne change pas de "page" entre pattern sauf si la pattern est "loopée", dans quel cas on change à chaque pattern.
                    if ((pp["subpatterns"].length > 1) && ((patts.length == 1) || (p < (patts.length - 1)))) {
                        console.log("page++ (SP)");
                        page++;
                    } else {
                        console.log("no page++ (SP) : " + (pp["subpatterns"].length) + "//" + p + "/" + (patts.length - 1));

                    }

                }

            }

        }

        // Debug
        for (var i = 0; i < pages.length; i++) {
            console.log("[" + i + "]" + pages[i]);
            //if (pages[i]===undefined) continue; // ne devrait plus arriver
            for (var j = 0; j < pages[i].length; j++) {
                for (var k = 0; k < pages[i][j].notes.length; k++) {
                    console.log(i + ") [" + pages[i][j].root + "/" + pages[i][j].mode + "] " + pages[i][j].notes[k]);
                }
            }
        }

        // Push all this to the score
        //var score = newScore("Workout", "saxophone", 1);
        var score = newScore("Workout", "bass-flute", 1); // transposing instruments (a.o. the saxophone) are buggy (???)
        //var cs=eval("Sid.chordStyle");
        //console.log("CHORD STYLE:" + score.styles.value(cs));
        var numerator = 4;
        var denominator = 4;

        score.addText("title", "Chordscale workouts");
        //score.style.setValue("chordStyle", "jazz");
        score.style.setValue("chordDescriptionFile", "chords_jazz.xml");
        score.style.setValue("chordStyle", "std");
        score.style.setValue("chordDescriptionFile", "chords_std.xml");

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
        var preferredTpcs = NoteHelper.tpcs;
        var prevPage = -1;

        for (var i = 0; i < pages.length; i++) {
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

                    for (var k = 0; k < pages[i][j].notes.length; k++, counter++) {
                        if (counter > 0) {
                            cursor.rewindToTick(cur_time); // be sure to move to the next rest, as now defined
                            var success = cursor.next();
                            if (!success) {
                                score.appendMeasures(1);
                                cursor.rewindToTick(cur_time);
                                cursor.next();
                            }
                        }
                        cursor.setDuration(1, 4); // quarter
                        var note = cursor.element;

                        var delta = pages[i][j].notes[k];
                        var pitch = _Cpitch + delta;
                        var tpc = 14; // One default value. The one of the C natural.

                        for (var t = 0; t < preferredTpcs.length; t++) {
                            var d = (delta < 0) ? (delta + 12) : delta
                            if (preferredTpcs[t].pitch == (d % 12)) {
                                tpc = preferredTpcs[t].tpc;
                                break;
                            }
                        }

                        var target = {
                            "pitch": pitch,
                            //"tpc1" : tpc,  // undefined to force the representation
                            "tpc2": tpc
                        };

                        //cur_time = note.parent.tick; // getting note's segment's tick
                        cur_time = cursor.segment.tick;

                        note = NoteHelper.restToNote(note, target);

                        // Adding the chord's name
                        if (prevChord !== chord.symb || prevRoot !== root) {
                            var csymb = newElement(Element.HARMONY);
                            var rtxt = _chords[root].root;

                            // chord's roots
                            if (!rtxt.includes("/")) {
                                csymb.text = rtxt;
                            } else {
                                var parts = rtxt.split("/");
                                var sharp_mode = true;
                                var f = _chords[root][mode];
                                if (f !== undefined)
                                    sharp_mode = f;
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
                        if ((i !== prevPage) || ((k == 0) && (j > 0) && (pages[i][j].representation != pages[i][j - 1].representation))) {
                            var ptext = newElement(Element.STAFF_TEXT);
                            var t = "";
                            ptext.text = pages[i][j].representation;
                            cursor.add(ptext);

                        }

                        //debugNote(delta, note);

                        prevRoot = root;
                        prevChord = chord.symb;
                        prevMode = mode;
                        prevPage = i;

                    }

                    // Fill with rests until end of measure
                    var fill = pages[i][j].notes.length % 4;
                    if (fill > 0) {
                        //fill = 4 - fill;
                        console.log("Going to fill from :" + fill);
                        for (var f = fill; f < 4; f++) {
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

                if (i < (pages.length - 1)) {
                    // if there is another part ("page") after this one, add a  linebreak
                    console.log("<BR>");
                    var lbreak = newElement(Element.LAYOUT_BREAK);
                    lbreak.layoutBreakType = 1;
                    cursor.rewindToTick(cur_time); // rewing to the last note
                    cursor.add(lbreak);
                } else {
                    console.log("NO <BR>");

                }

        }

        score.endCmd();

    }

    function extendPattern(pattern) {
        var extpattern = pattern;
        var basesteps = pattern.notes;
        var scale = pattern.chord.scale;
        var loopAt = pattern.loopAt;

        extpattern.representation = patternToString(pattern.notes, pattern.loopAt);

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
            // 2) Scale loopAt mode, we decline the pattern along the scale (up/down, by degree/triade)
            var shift = loopAt.shift; //Math.abs(loopAt) * (-1);
            console.log("Looping patterns : scale mode (" + shift + ")");
            if (shift > 0) {
                for (var i = shift; i < scale.length; i += shift) {
                    console.log("Looping patterns : scale mode at " + i);
                    var shifted = shiftPattern(basesteps, scale, i);
                    extpattern["subpatterns"].push(shifted);
                }
            } else {
                // We are decresing, so we'll tweak the original pattern one actave up
                var octaveup = [];
                for (var i = 0; i < basesteps.length; i++) {
                    octaveup[i] = basesteps[i] + 12;
                }
                extpattern["subpatterns"][0] = octaveup;

                // Building the other ones
                var counter = 0;
                var dia = [];
                shift = Math.abs(shift);
                // we compute III V VII
                for (var i = shift; i < scale.length; i += shift) {
                    console.log("Adding " + i + " (" + scale[i] + ")");
                    dia.push(i);
                }
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
            //console.log("1)[" + ip + "]" + p + "->" + debugDia(d));
        }

        // 2) shift the diatonic pattern by the amount of steps
        for (var ip = 0; ip < pdia.length; ip++) {
            var d = pdia[ip];
            d.degree += step;
            d.octave += Math.floor(d.degree / scale.length);
            d.degree = d.degree % scale.length;
            pdia[ip] = d;
            //console.log("2)[" + ip + "]->" + debugDia(d));
        }

        // 3) Convert back to a chromatic scale
        var pshift = [];
        for (var ip = 0; ip < pdia.length; ip++) {
            var d = pdia[ip];
            var s = scale[d.degree] + 12 * d.octave + d.semi;
            pshift.push(s);
            //console.log("3)[" + ip + "]" + debugDia(d) + "->" + s);
        }

        return pshift;

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

        console.log(_chords[root].root + " " + mode + " => sharp: " + sharp_mode);

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

        var p = new patternClass(steps, mode, scale);

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
            if (p.label === pattern.label) {
                return i;
            }
        }
        return -1;
    }

    function applyWorkout(workout) {
		// patterns
        var m = Math.min(_max_patterns, workout.patterns.length);

        for (var i = 0; i < m; i++) {
            setPattern(i, workout.patterns[i]);
        }

        for (var i = m; i < _max_patterns; i++) {
            setPattern(i, undefined);
        }

		// roots, if defined in the workout
        if (workout.roots !== undefined) {
            m = Math.min(_max_roots, workout.roots.length);

            for (var i = 0; i < m; i++) {
                steproots[i] = _roots[workout.roots[i]];
            }

            for (var i = m; i < _max_patterns; i++) {
                        steproots[i] = '';
            }

        }

		// options, if defined in the workout
        if (workout.bypattern !== undefined) {
            chkByPattern.checkState = (workout.bypattern === "true") ? Qt.Checked : Qt.Unchecked;

        }
        if (workout.invert !== undefined) {
            chkInvert.checkState = (workout.invert === "true") ? Qt.Checked : Qt.Unchecked;
        }

    }

    function saveWorkout(label) {
        var pp = [];
        for (var i = 0; i < _max_patterns; i++) {
            var p = getPattern(i);
            if (p.steps.length == 0)
                break;
            pp.push(p);
        }

        var workout = new workoutClass(label, pp);

        workouts.push(workout);
        resetL = !resetL;
        saveLibrary();
    }

    function deleteWorkout(workout) {}

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
        console.log("Library loaded");

        resetL = !resetL;
    }

    function saveLibrary() {

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
                    }
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
            }
            CheckBox {
                id: chkInvert
                text: "Invert pattern every two roots"
                checked: false
                enabled: chkByPattern.checked
            }
            /*CheckBox {
            id : chkPageBreak
            checked : false
            text : "Page break after each group"
            }*/
            Item {
                Layout.fillWidth: true
            }
            ImageButton {
                imageSource: "upload.svg"
                ToolTip.text: "Load workout"
                imageHeight: 25
                imagePadding: (buttonBox.contentItem.height - imageHeight) / 2
                onClicked: {
                    applyWorkout(workouts[workouts.length - 1]);
                }

            }
            ImageButton {
                imageSource: "download.svg"
                ToolTip.text: "Save workout"
                imageHeight: 25
                imagePadding: (buttonBox.contentItem.height - imageHeight) / 2
                onClicked: {
                    saveWorkout("aaa");
                }

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
            Item {
                Layout.fillWidth: true
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
            implicitWidth: 80
            onCurrentIndexChanged: {
                steproots[rootIndex] = model[currentIndex]
                    console.log("Root " + rootIndex + ": " + steproots[rootIndex]);
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
                text: 'Workout Builder ' + version
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

                    model: getPresetsLibrary(resetL) //__library
                    //delegate: presetComponent
                    clip: true
                    focus: true

                    delegate: Text {
                        readonly property ListView __lv: ListView.view
                        text: library[model.index].label;
                        padding: 4

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton

                            onDoubleClicked: {
                                setPattern(loadWindow.index, library[model.index]);
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
                    enabled: lstLibrary.currentIndex >= 0
                    ToolTip.text: "Delete the selected pattern"
                    imageHeight: 25
                    imagePadding: (libButtonBox.contentItem.height - imageHeight) / 2
                    onClicked: {
                        confirmRemovePatternDialog.pattern = library[lstLibrary.currentIndex];
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
                        setPattern(loadWindow.index, library[lstLibrary.currentIndex]);
                        loadWindow.hide();
                    }
                    onRejected: loadWindow.hide()

                }
            }
        }
    }

    MessageDialog {
        id: missingStuffDialog
        icon: StandardIcon.Warning
        standardButtons: StandardButton.Ok
        title: 'Cannot proceed'
        text: 'At least one pattern and one root note must be defined to create the score/'
    }

    MessageDialog {
        id: confirmRemovePatternDialog
        icon: StandardIcon.Warning
        standardButtons: StandardButton.Yes | StandardButton.No
        title: 'Confirm '
        property var pattern: null
        text: 'Please confirm the deletion of the following pattern : <br/>' + ((pattern == null) ? "--" : pattern.label)
        onYes: {
            deletePattern(pattern);
        }
        onNo: confirmRemovePatternDialog.close();
    }

    function getRoots(uglyHack) {
        return steproots;
    }

    function getPatterns(uglyHack) {
        return patterns;
    }

    function getPresetsLibrary(uglyHack) {
        console.log("Library has " + library.length + " elements");
        return library;
    }

    property var presets: [{
            "name": '',
            "root": 0,
            "roots": []
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

    function patternClass(steps, loopMode, scale) {
        this.steps = steps;
        this.loopMode = loopMode;
        this.scale = scale;
        Object.defineProperty(this, "label", {
            get: function () {
                var label = "";
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
                return label;
            },

            enumerable: true
        });

    }

    /**
     * Creation of a pattern from a pattern object containing the *enumerable* fields (ie. the non transient fields)
     */
    function patternClassRaw(raw) {
        patternClass.call(this, raw.steps, raw.loopMode, raw.scale);
    }

    function workoutClass(label, patterns, roots, bypattern, invert) {
        this.patterns = patterns;
        this.label = label;
        this.roots = roots;
        this.bypattern = bypattern;
        this.invert = invert;
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

        workoutClass.call(this, raw.label, pp, raw["roots"], raw["bypattern"], raw["invert"]);
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
