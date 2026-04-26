import Toybox.Graphics;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.WatchUi;
import Toybox.System;


(:glance)
class Stress_AwarePomodoroGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var height = dc.getHeight();
        var leftPadding = 10;
        
        // ✅ Perfect vertical spacing for all Garmin Glance heights
        var line1Y = 4;
        var line2Y = height / 3;
        var line3Y = (height * 2) / 3;

        // ✅ ✅ GLANCE WILL NEVER HAVE ACCESS TO APP INSTANCE!
        // THIS IS GARMIN SYSTEM LIMITATION - NO EXCEPTIONS
        // ALWAYS READ DIRECTLY FROM PERSISTENT STORAGE
        var storage = Application.Storage.getValue("app_state");

        var state = 0;
        var breakDuration = 0;
        var isPaused = false;
        // var sessionCount = 0;

        if (storage != null) {
            var data = storage as Array;
            state = data[0] as Number;
            breakDuration = data[2] as Number;
            isPaused = data[4] as Boolean;
            // sessionCount = data[5] as Number;
        }

        // Load break duration settings for comparison
        var breakLongMin = Application.Properties.getValue("BreakLongMinutes") as Number;
        var breakExtraLongMin = Application.Properties.getValue("BreakExtraLongMinutes") as Number;

        // Line 1: Title + Completed Sessions counter
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            leftPadding,
            line1Y,
            Graphics.FONT_TINY,
            // Lang.format("Pomodoro  |  Done: $1$", [sessionCount]),
            Lang.format("Pomodoro ", []),
            Graphics.TEXT_JUSTIFY_LEFT
        );

        // Line 2: LIVE Pomodoro status - always updated even in background
        var pomodoroText = "Ready to focus";
        var pomodoroColor = Graphics.COLOR_LT_GRAY;

        if (state == 1) {
            if (isPaused) {
                pomodoroText = "Focus paused";
                pomodoroColor = Graphics.COLOR_YELLOW;
            } else {
                pomodoroText = "Focus running";
                pomodoroColor = Graphics.COLOR_GREEN;
            }
        } else if (state == 4) {
            if (isPaused) {
                pomodoroText = "Break paused";
                pomodoroColor = Graphics.COLOR_YELLOW;
            } else {
                pomodoroText = "Break time";
                pomodoroColor = Graphics.COLOR_BLUE;
            }
        } else if (state == 2) {
            pomodoroText = "Analyzing stress";
            pomodoroColor = Graphics.COLOR_ORANGE;
        } else if (state == 3) {
            if (breakDuration == breakExtraLongMin * 60) {
                pomodoroText = "High Stress";
                pomodoroColor = Graphics.COLOR_RED;
            } else if (breakDuration == breakLongMin * 60) {
                pomodoroText = "Take break";
                pomodoroColor = Graphics.COLOR_ORANGE;
            } else {
                pomodoroText = "Break ready";
                pomodoroColor = Graphics.COLOR_BLUE;
            }
        }
        
        dc.setColor(pomodoroColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            leftPadding,
            line2Y,
            Graphics.FONT_SMALL,
            pomodoroText,
            Graphics.TEXT_JUSTIFY_LEFT
        );

        // Line 3: Current real-time Stress Level
        var stressLevel = -1;
        var iter = SensorHistory.getStressHistory({
            :period => 3,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });
        
        if (iter != null) {
            var sample = iter.next();
            while (sample != null) {
                if (sample.data != null) {
                    stressLevel = sample.data;
                    break;
                }
                sample = iter.next();
            }
        }
        
        var stressText = "Stress: ---";
        var stressColor = 0xAAAAAA;
        
        if (stressLevel >= 0) {
            var stressInt = Math.round(stressLevel).toNumber();
            stressText = Lang.format("Stress: $1$", [stressInt]);

            if (stressInt < 30) {
                stressColor = Graphics.COLOR_GREEN;
            } else if (stressInt < 60) {
                stressColor = Graphics.COLOR_YELLOW;
            } else {
                stressColor = Graphics.COLOR_RED;
            }
        }
        
        dc.setColor(stressColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            leftPadding,
            line3Y,
            Graphics.FONT_TINY,
            stressText,
            Graphics.TEXT_JUSTIFY_LEFT
        );
    }

    private function formatTime(seconds as Number) as String {
        var m = seconds / 60;
        var s = seconds % 60;
        return Lang.format("$1$:$2$", [m.format("%02d"), s.format("%02d")]);
    }
}