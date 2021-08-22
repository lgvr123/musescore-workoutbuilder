import QtQuick 2.9
import QtQuick.Controls 2.2

Button {
    id: smbtn
    property var imageSource: ""
    property int imageHeight: 18
    property int imagePadding: 3
    font.pointSize: 7
    implicitWidth: imageHeight + imagePadding * 2
    implicitHeight: imageHeight + imagePadding * 2
    background: Rectangle {
        implicitWidth: smbtn.width
        implicitHeight: smbtn.height

        color: smbtn.down ? "#C0C0C0" : (smbtn.hovered ? "#D0D0D0" : "transparent" /*"#E0E0E0"*/)
        //border.color: "red"
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
