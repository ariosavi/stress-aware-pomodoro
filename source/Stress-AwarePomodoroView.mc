import Toybox.Graphics;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.WatchUi;

class Stress_AwarePomodoroView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        WatchUi.requestUpdate();
    }

    function onHide() as Void {
        // Never stop timer here! State lives in App and continues running
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var h = dc.getHeight();
        var w = dc.getWidth();
        var cx = w / 2;

        var text = "";
        var subText = "";
        var infoText = "";
        var accentColor = Graphics.COLOR_WHITE;
        
        var app = getApp();

        if (app.state == app.STATE_READY) {
            text = "Ready";
            subText = "Press Start";
            accentColor = Graphics.COLOR_GREEN;
        } else if (app.state == app.STATE_FOCUSING) {
            if (app.isPaused) {
                text = "Paused";
                subText = formatTime(app.timeRemaining);
                infoText = "";
                infoText = "";
                accentColor = Graphics.COLOR_YELLOW;
            } else {
                text = formatTime(app.timeRemaining);
                subText = "Focusing";
                infoText = "Done: " + app.sessionCount;
                accentColor = Graphics.COLOR_GREEN;
            }
        } else if (app.state == app.STATE_ANALYZING) {
            text = "Analyzing";
            subText = "Reading stress";
            accentColor = Graphics.COLOR_ORANGE;
        } else if (app.state == app.STATE_BREAK_PROMPT) {
            if (app.breakDuration == app.BREAK_SHORT) {
                text = "Good job";
                subText = "5m break";
                accentColor = Graphics.COLOR_BLUE;
            } else if (app.breakDuration == app.BREAK_LONG) {
                text = "High stress";
                subText = "10m break";
                accentColor = Graphics.COLOR_RED;
            } else {
                text = "Great work";
                subText = "20m break";
                accentColor = Graphics.COLOR_PURPLE;
            }
            if (app.stressAverage != null) {
                infoText = "Avg stress: " + app.stressAverage;
            } else {
                infoText = "Press Start";
            }
        } else if (app.state == app.STATE_BREAK) {
            if (app.isPaused) {
                text = "Paused";
                subText = formatTime(app.timeRemaining);
                infoText = "";
                accentColor = Graphics.COLOR_YELLOW;
            } else {
                text = formatTime(app.timeRemaining);
                subText = "Break";
                accentColor = Graphics.COLOR_BLUE;
            }
        }

        // Clock at very top
        drawClock(dc, cx, (h * 0.07).toNumber());

        // Progress bar right below clock, only during countdown
        if (app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) {
            drawProgressBar(dc, accentColor, (h * 0.14).toNumber());
        }

        // Title
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.28).toNumber(), Graphics.FONT_LARGE, text, Graphics.TEXT_JUSTIFY_CENTER);

        // Subtitle
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.42).toNumber(), Graphics.FONT_SMALL, subText, Graphics.TEXT_JUSTIFY_CENTER);

        // Additional info for READY state
        var yInfoBase = (h * 0.54).toNumber();
        
        if (app.state == app.STATE_READY) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            
            dc.drawText(cx, yInfoBase, Graphics.FONT_XTINY, "Focus session: 25 min", Graphics.TEXT_JUSTIFY_CENTER);

            var currentStress = getCurrentStress();
            if (currentStress != null) {
                var stressLevel = currentStress.toNumber();
                var stressColor = Graphics.COLOR_LT_GRAY;
                
                if (stressLevel < 30) {
                    stressColor = Graphics.COLOR_GREEN;
                } else if (stressLevel < 60) {
                    stressColor = Graphics.COLOR_YELLOW;
                } else {
                    stressColor = Graphics.COLOR_RED;
                }
                
                dc.setColor(stressColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, yInfoBase + 30, Graphics.FONT_XTINY, "Current stress: " + stressLevel, Graphics.TEXT_JUSTIFY_CENTER);                
            }
        } else {
            // Info text for running/paused states
            if (infoText.length() > 0) {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, yInfoBase, Graphics.FONT_XTINY, infoText, Graphics.TEXT_JUSTIFY_CENTER);
            }
            
            // Always show current stress level when pomodoro is active/paused
            var currentStress = getCurrentStress();
            if (currentStress != null) {
                var stressLevel = currentStress.toNumber();
                var stressColor = Graphics.COLOR_LT_GRAY;
                
                if (stressLevel < 30) {
                    stressColor = Graphics.COLOR_GREEN;
                } else if (stressLevel < 60) {
                    stressColor = Graphics.COLOR_YELLOW;
                } else {
                    stressColor = Graphics.COLOR_RED;
                }
                
                dc.setColor(stressColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, yInfoBase + 30, Graphics.FONT_XTINY, "Stress: " + stressLevel, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    private function drawClock(dc as Dc, cx as Number, y as Number) as Void {
        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, timeString, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawProgressBar(dc as Dc, color as Number, barY as Number) as Void {
        var w = dc.getWidth();
        var barW = (w * 0.55).toNumber();
        var barH = 6;
        var barX = (w - barW) / 2;
        
        var app = getApp();
        var remaining = app.timeRemaining;
        var total = (app.state == app.STATE_FOCUSING) ? app.FOCUS_DURATION : app.breakDuration;
        var progress = 1.0 - (remaining.toFloat() / total.toFloat());
        if (progress < 0) { progress = 0; }
        if (progress > 1) { progress = 1; }

        var fillW = (barW * progress).toNumber();
        if (fillW < 1) { fillW = 1; }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, barH);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, fillW, barH);
    }

    private function formatTime(seconds as Number) as String {
        var m = seconds / 60;
        var s = seconds % 60;
        return Lang.format("$1$:$2$", [m.format("%02d"), s.format("%02d")]);
    }

    function onSelect() as Void {
        var app = getApp();
        if (app.state == app.STATE_READY) {
            app.state = app.STATE_FOCUSING;
            app.timeRemaining = app.FOCUS_DURATION;
            app.isPaused = false;
            app.startTimer();
            app.vibrateStart();
            WatchUi.requestUpdate();
        } else if (app.state == app.STATE_BREAK_PROMPT) {
            app.state = app.STATE_BREAK;
            app.timeRemaining = app.breakDuration;
            app.isPaused = false;
            app.startTimer();
            app.vibrateStart();
            WatchUi.requestUpdate();
        } else if (app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) {
            app.vibratePause();
            if (app.isPaused) {
                app.isPaused = false;
                app.startTimer();
            } else {
                app.isPaused = true;
                app.stopTimer();
            }
            WatchUi.requestUpdate();
        }
    }

    function onBack() as Boolean {
        var app = getApp();
        
        // ✅ ALWAYS let user exit app normally without resetting anything
        // ✅ Timer keeps running perfectly in background
        // ✅ No reset ever happens on back button press!
        return false;
    }

    function onSkip() as Void {
        var app = getApp();
        if (app.state == app.STATE_BREAK_PROMPT || app.state == app.STATE_BREAK) {
            app.resetToReady();
        }
    }

    private function getCurrentStress() as Number? {
        // Garmin stress level updates EVERY 3 MINUTES - this is official value
        var iter = SensorHistory.getStressHistory({:period => 3});
        if (iter == null) {
            return null;
        }
        
        // ✅ IMPORTANT: Garmin returns samples OLDEST FIRST
        // We need to iterate ALL samples to get LATEST most recent value
        // This is exactly what official Garmin widgets show
        var latestStress = null;
        var sample = iter.next();
        while (sample != null) {
            if (sample.data != null) {
                latestStress = sample.data;
            }
            sample = iter.next();
        }
        
        return latestStress;
    }
}