// Wizard progress. Earlier steps stay reachable until the report is sent.
import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

MStepper {
    id: root

    current: BugReport.step
    steps: ["bugReport.stepDescribe", "bugReport.stepShots", "bugReport.stepReview", "bugReport.stepSend"]
    reachable: [root._can(0), root._can(1), root._can(2), root._can(3)]
    onActivated: (index) => BugReport.goTo(index)

    function _can(index) {
        return BugReport.step < 3 && index < 3
            && (index <= BugReport.step || BugReport.title.trim().length > 0);
    }
}
