import QtQuick 2.9
import QtQuick.Controls 2.2

// v1.1.0: including textRole
// v1.1.1: bugfix on textRole
// v1.1.2: MS4 bugfix

ComboBox {
    id: control

    //model: []
	
	//textRole: "text"

    delegate: ItemDelegate { // requiert QuickControls 2.2
        width: control.width
        contentItem: Text {
            text: modelData[textRole]
            anchors.verticalCenter: parent.verticalCenter
        }
        highlighted: control.highlightedIndex === index
    }

    contentItem: Text {

        text: (control.model && control.model[control.currentIndex])?control.model[control.currentIndex][textRole]:"--"
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 10
        rightPadding: 10
        topPadding: 5
        bottomPadding: 5
        verticalAlignment: Text.AlignVCenter
    }

    FontMetrics {
        id: fontMetric
        font.family: control.contentItem.font.family

    }

    Binding on implicitWidth {
        value: computeWidth(model)
    }
	
	popup.implicitWidth: computeWidth(model)


    function computeWidth(mdl) {
        if (mdl == null) {
            return 200; // returning a default value in case of no model (yet)
        }



        var longest = "";
        for (var i = 0; i < mdl.length; i++) {
            var txt = mdl[i].text;
            if (txt.length > longest.length)
                longest = txt;
        }
        var pwidth = fontMetric.boundingRect(longest).width;
        pwidth += control.contentItem.rightPadding + control.contentItem.leftPadding;
        pwidth += control.indicator.width

        return Math.max(pwidth,10);  // returning minimum 10
    }

}