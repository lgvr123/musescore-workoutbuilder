import QtQuick 2.9
import QtQuick.Controls 2.2

Button {
    id: smbtn
	property var imageSource: ""
	property int imageHeight: 20
    font.pointSize: 7
    background: Rectangle {
        implicitWidth: smbtn.imageHeight
        implicitHeight: smbtn.imageHeight
        color: smbtn.down ? "#C0C0C0" : (smbtn.hovered ? "#D0D0D0" : "#E0E0E0")
        //border.color: "#26282a"
        //border.width: 1
        radius: 4
    }
    indicator:
    Image {
        source: smbtn.imageSource
        height: smbtn.imageHeight
        fillMode: Image.PreserveAspectFit // ensure it fits
        mipmap: true // smoothing
        anchors.centerIn: parent
    }

    hoverEnabled: true
    ToolTip.delay: 1000
    ToolTip.timeout: 5000
    ToolTip.visible: hovered

}
