import Toybox.Graphics;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.WatchUi;
import Toybox.System;


class Stress_AwarePomodoroGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var leftPadding = 10;
        
        // Very tight vertical spacing - all fit properly
        var line1Y = 2;
        var line2Y = height / 3;
        var line3Y = (height * 2) / 3;

        // Line 1: Title
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            leftPadding,
            line1Y,
            Graphics.FONT_TINY,
            "Pomodoro",
            Graphics.TEXT_JUSTIFY_LEFT
        );

        // Line 2: Pomodoro status
        var pomodoroText = "Ready to start";
        var pomodoroColor = Graphics.COLOR_GREEN;
        
        dc.setColor(pomodoroColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            leftPadding,
            line2Y,
            Graphics.FONT_SMALL,
            pomodoroText,
            Graphics.TEXT_JUSTIFY_LEFT
        );

        // Line 3: Stress level number
        var stressLevel = -1;
        var iter = SensorHistory.getStressHistory({
            :period => 1,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });
        
        if (iter != null) {
            var sample = iter.next();
            if (sample != null && sample.data != null) {
                stressLevel = sample.data;
            }
        }
        
        var stressText = "Stress: ---";
        var stressColor = 0xAAAAAA;
        
        if (stressLevel >= 0) {
            stressText = Lang.format("Stress: $1$", [stressLevel.toNumber()]);
            
            if (stressLevel < 30) {
                stressColor = Graphics.COLOR_GREEN;
            } else if (stressLevel < 60) {
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
}
