import QtQuick 2.9
import QtQuick.Controls 2.2
import MuseScore 3.0
import QtQuick.Window 2.2
import QtQuick.Dialogs 1.2
import QtQuick.Controls.Styles 1.4
import QtQuick.Layouts 1.1
import FileIO 3.0

MuseScore {
	menuPath : "Plugins.Workout builder"
	description : "Description goes here"
	version : "1.0"

	pluginType : "dialog"
	requiresScore : true
	width : 800
	height : 600

	id : mainWindow
	onRun : {

		console.log("steps: " + stepnotes.length);
		console.log("labels: " + labels.length);
		console.log("roots: " + steproots.length);

	}

	property int _max_steps : 8
	property int _max_notes : 24
	property int _max_roots : 12
	property var _raw_labels : ['1', 'b2', '2', 'm3', 'M3', '4', 'b5', '5', 'm6', 'M6', 'm7', 'M7',
		'(8)', 'b9', '9', '#9', 'b11', '11', '#11', '(12)', 'b13', '13', '#13', '(14)']

	property var _roots : ['C', 'C#/Db', 'D', 'D#/Eb', 'E', 'F', 'F#/Gb', 'G', 'G#/Ab', 'A', 'A#/Bb', 'B', '']

	property var stepnotes : { {

			var sn = [];

			for (var i = 0; i < _max_steps; i++) {
				for (var j = 0; j < _max_notes; j++) {
					var _sn = {
						"step" : i,
						"note" : j,
						"played" : false,
						"in_chord" : false
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

	property var labels : { {

			var lb = [];
			for (var j = 0; j < _max_notes; j++) {
				var _l = _raw_labels[j % 24];
				lb.push(_l);
			}

			return lb;
		}
	}

	property bool reset : true

	ColumnLayout {
		anchors.fill : parent
		anchors.margins : 25
		spacing : 10

		Grid { // un small element within the fullWidth/fullHeight where we paint the repeater
			//anchors.verticalCenter : parent.verticalCenter
			id : idNoteGrid
			rows : _max_steps + 1
			columns : _max_notes
			columnSpacing : -5
			rowSpacing : -5

			Layout.alignment : Qt.AlignCenter
			//Layout.preferredWidth : _max_notes * 20
			//Layout.preferredHeight : (_max_steps + 1) * 20

			Repeater {
				id : idNoteLabels
				model : labels

				Label {
					Layout.alignment : Qt.AlignVCenter | Qt.AlignRight
					Layout.rightMargin : 2
					Layout.leftMargin : 2
					text : modelData
				}
			}
			Repeater {
				id : idStepNotes
				model : stepnotes

				Loader {
					id : loaderNotes
					Binding {
						target : loaderNotes.item
						property : "stepnote"
						value : stepnotes[model.index]
					}
					sourceComponent : stepComponent
				}

			}
		}

		RowLayout {
			Label {
				text : "Options:"
			}

			CheckBox {
				id : chkInvert
				text : "Invert pattern at each repetition"
			}

		}

		RowLayout {
			Label {
				text : "Presets:"
			}

			ComboBox {
				id : lstPresets
				model : presets

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
		}

		Flow { // Les roots
			//rows : 1
			//columns : 6
			//columnSpacing : 5
			spacing : 5
			Layout.alignment : Qt.AlignHCenter
			Layout.preferredWidth : idNoteGrid.implicitWidth

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

		Item {
			Layout.fillHeight : true
		}

		RowLayout {
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
					var basesteps = [];
					for (var i = 0; i < _max_steps; i++) {
						for (var j = 0; j < _max_notes; j++) {
							var sn = stepnotes[i * _max_notes + j];
							if (sn.played) {
								basesteps.push(sn);
								break;
							}
						}
					}

					for (var i = 0; i < basesteps.length; i++) {
						console.log("S:" + basesteps[i].note);
					}

					var notes = [];
					for (var i = 0; i < _max_roots; i++) {
						var txt = steproots[i];
						console.log("Next Root: " + txt);
						if (txt === '' || txt === undefined)
							continue;
						var r = -1;
						for (var j = 0; j < _roots.length; j++) {
							if (txt === _roots[j]) {
								r = j;
								break;
							}
						}
						console.log("-- => " + r);
						if (r == -1)
							continue;

						if (!chkInvert.checked || ((i % 2) == 0)) {
							console.log("-- => normal");
							for (var j = 0; j < basesteps.length; j++) {
								notes.push(r + basesteps[j].note);
							}
						} else {
							console.log("-- => reverse");
							for (var j = basesteps.length - 1; j >= 0; j--) {
								notes.push(r + basesteps[j].note);
							}
						}

					}

					for (var i = 0; i < notes.length; i++) {
						console.log("N:" + notes[i]);
					}

					// Qt.quit();

				}
				onRejected : Qt.quit()

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
			model : _roots
			currentIndex : find(steproots[rootIndex], Qt.MatchExactly)
			Layout.preferredHeight : 30
			implicitWidth : 80
			onCurrentIndexChanged : {
				steproots[rootIndex] = model[currentIndex]
					console.log("Root " + rootIndex + ": " + steproots[rootIndex]);
			}
		}
	}

	Component {
		id : stepComponent

		CheckBox {
			id : chkSN

			property var stepnote

			checked : stepnote.played
			tristate : false

			MouseArea {
				anchors.fill : parent
				onClicked : {
					parent.checked = !(parent.checked);
					stepnote.played = parent.checked;
					console.log("Step: " + stepnote.step + ", note: " + _raw_labels[stepnote.note % 24] + ", played: " + stepnote.played);
				}
			}
			Layout.alignment : Qt.AlignVCenter | Qt.AlignHCenter
			Layout.rightMargin : 2
			Layout.leftMargin : 2

			indicator : Rectangle {
				implicitWidth : 16
				implicitHeight : implicitWidth
				x : chkSN.leftPadding + 2
				y : parent.height / 2 - height / 2
				border.color : "grey"

				Rectangle {
					width : parent.implicitWidth / 2
					height : parent.implicitWidth / 2
					x : parent.implicitWidth / 4
					y : parent.implicitWidth / 4
					color : "grey"
					visible : chkSN.checked
				}
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
