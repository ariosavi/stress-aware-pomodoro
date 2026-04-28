import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

(:glance)
class Stress_AwarePomodoroGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.clear();

        var height = dc.getHeight();
        var leftPadding = 0;

        var line1Y = 4;
        var line2Y = height / 3;
        var line3Y = (height * 2) / 3;

        var snapshot = PomoState.loadSnapshot();
        var state = snapshot.state;
        var breakDuration = snapshot.breakDuration;
        var isPaused = snapshot.isPaused;
        var sessionCount = snapshot.sessionCount;
        var timeRemaining = snapshot.timeRemaining;

        if (PomoState.isRunningState(state) && !isPaused && snapshot.timerEndEpoch > 0) {
            var liveRemaining = snapshot.timerEndEpoch - Time.now().value();
            timeRemaining = liveRemaining > 0 ? liveRemaining : 0;
        }

        var breakLongMin = Application.Properties.getValue("BreakLongMinutes") as Number;
        var breakExtraLongMin = Application.Properties.getValue("BreakExtraLongMinutes") as Number;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            leftPadding,
            line1Y,
            Graphics.FONT_TINY,
            Lang.format("Pomodoro", []),
            Graphics.TEXT_JUSTIFY_LEFT
        );

        var pomodoroText = "Ready to focus";
        var pomodoroColor = Graphics.COLOR_LT_GRAY;
        var detailText = "Completed: " + sessionCount;

        if (state == 1) {
            pomodoroText = isPaused ? "Focus paused" : "Focus running";
            pomodoroColor = isPaused ? Graphics.COLOR_YELLOW : Graphics.COLOR_GREEN;
            detailText = formatTime(timeRemaining);
        } else if (state == 4) {
            pomodoroText = isPaused ? "Break paused" : "Break time";
            pomodoroColor = isPaused ? Graphics.COLOR_YELLOW : Graphics.COLOR_BLUE;
            detailText = formatTime(timeRemaining);
        } else if (state == 2) {
            pomodoroText = "Analyzing stress";
            pomodoroColor = Graphics.COLOR_ORANGE;
            detailText = "Completed: " + sessionCount;
        } else if (state == 3) {
            if (breakDuration == breakExtraLongMin * 60) {
                pomodoroText = "Long break";
                pomodoroColor = Graphics.COLOR_RED;
            } else if (breakDuration == breakLongMin * 60) {
                pomodoroText = "Break suggested";
                pomodoroColor = Graphics.COLOR_ORANGE;
            } else {
                pomodoroText = "Short break";
                pomodoroColor = Graphics.COLOR_BLUE;
            }
            detailText = formatTime(breakDuration);
        }

        dc.setColor(pomodoroColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            leftPadding,
            line2Y,
            Graphics.FONT_SMALL,
            pomodoroText,
            Graphics.TEXT_JUSTIFY_LEFT
        );

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            leftPadding,
            line3Y,
            Graphics.FONT_TINY,
            detailText,
            Graphics.TEXT_JUSTIFY_LEFT
        );
    }

    private function formatTime(seconds as Number) as String {
        var minutes = seconds / 60;
        var remainder = seconds % 60;
        return Lang.format("$1$:$2$", [minutes.format("%02d"), remainder.format("%02d")]);
    }

}
