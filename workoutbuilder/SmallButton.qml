import QtQuick 2.9
import QtQuick.Controls 2.2

Button {
    id: smbtn
    font.pointSize: 7
    background: Rectangle {
        implicitWidth: 40
        implicitHeight: 20
        color: smbtn.down ? "#C0C0C0" : "#E0E0E0"
        //border.color: "#26282a"
        //border.width: 1
        radius: 4
    }
}
