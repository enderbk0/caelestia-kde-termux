import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.Services

Scope {
    id: root

    required property var lock

    readonly property alias passwd: passwd
    readonly property alias fprint: fprint
    readonly property alias howdy: howdy
    property string lockMessage
    property string state
    property string fprintState
    property string howdyState
    property string buffer

    signal flashMsg

    function handleKey(event: KeyEvent): void {
        // No PAM on Termux — plain Enter unlocks
        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            root.lock.unlock();
        } else if (event.key === Qt.Key_Backspace) {
            buffer = buffer.slice(0, -1);
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            buffer += event.text;
        }
    }

    // Stub — PAM not available on Termux
    QtObject {
        id: passwd
        property bool active: false
        function start(): void {}
        function abort(): void {}
        function respond(response: string): void {}
    }

    QtObject {
        id: fprint
        property bool available: false
        property int tries: 0
        property int errorTries: 0
        function checkAvail(): void {}
        function start(): void {}
        function abort(): void {}
    }

    QtObject {
        id: howdy
        property bool available: false
        property int tries: 0
        property int errorTries: 0
        readonly property bool canAttempt: false
        function checkAvail(): void {}
        function start(): void {}
        function abort(): void {}
    }
}
