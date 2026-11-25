// Process watchdogs for Brightness.qml (line-cap split).
import Quickshell
import QtQuick
import "../Commons"

Item {
    id: root

    property var getProc: null
    property var listProc: null
    property var setProc: null

    signal getTimedOut
    signal listTimedOut
    signal setTimedOut

    function armGet(on: bool) {
        if (on) getWatch.restart(); else getWatch.stop();
    }
    function armList(on: bool) {
        if (on) listWatch.restart(); else listWatch.stop();
    }
    function armSet(on: bool) {
        if (on) setWatch.restart(); else setWatch.stop();
    }

    Timer {
        id: getWatch
        interval: Motion.processWatchMs
        repeat: false
        onTriggered: {
            if (root.getProc && root.getProc.running)
                root.getTimedOut();
        }
    }
    Timer {
        id: listWatch
        interval: Motion.followWatchMs
        repeat: false
        onTriggered: {
            if (root.listProc && root.listProc.running)
                root.listTimedOut();
        }
    }
    Timer {
        id: setWatch
        interval: Motion.processWatchMs
        repeat: false
        onTriggered: {
            if (root.setProc && root.setProc.running)
                root.setTimedOut();
        }
    }
}
