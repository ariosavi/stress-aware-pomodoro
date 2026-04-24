import Toybox.Application;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Attention;
import Toybox.SensorHistory;

class Stress_AwarePomodoroApp extends Application.AppBase {

    // Global state - PERSISTS even when view is hidden/app is in background
    public var state as Number;
    public var timer as Timer.Timer?;
    public var timeRemaining as Number;
    public var breakDuration as Number;
    public var stressAverage as Number?;
    public var isPaused as Boolean;
    public var sessionCount as Number;

    // Constants
    public const STATE_READY = 0;
    public const STATE_FOCUSING = 1;
    public const STATE_ANALYZING = 2;
    public const STATE_BREAK_PROMPT = 3;
    public const STATE_BREAK = 4;

    public const FOCUS_DURATION = 25 * 60;
    public const BREAK_SHORT = 5 * 60;
    public const BREAK_LONG = 10 * 60;
    public const BREAK_EXTRA_LONG = 20 * 60;
    public const SESSIONS_BEFORE_LONG_BREAK = 4;

    function initialize() {
        AppBase.initialize();
        
        // Initialize global state once when app starts
        state = STATE_READY;
        timeRemaining = 0;
        breakDuration = 0;
        stressAverage = null;
        timer = null;
        isPaused = false;
        sessionCount = 0;
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new Stress_AwarePomodoroView();
        return [view, new Stress_AwarePomodoroDelegate(view)];
    }

    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new Stress_AwarePomodoroGlanceView()];
    }

    // GLOBAL TIMER LOGIC - runs at app level
    function startTimer() as Void {
        if (timer == null) {
            timer = new Timer.Timer();
        }
        timer.start(method(:onTimerTick), 1000, true);
    }

    function stopTimer() as Void {
        if (timer != null) {
            timer.stop();
        }
    }

    function onTimerTick() as Void {
        timeRemaining = timeRemaining - 1;
        if (timeRemaining <= 0) {
            stopTimer();
            if (state == STATE_FOCUSING) {
                transitionToAnalyzing();
            } else if (state == STATE_BREAK) {
                transitionToReady();
            }
        } else {
            WatchUi.requestUpdate();
        }
    }

    function transitionToAnalyzing() as Void {
        state = STATE_ANALYZING;
        vibrateComplete();
        vibrateComplete();
        sessionCount = sessionCount + 1;

        var avg = calculateAverageStress();
        stressAverage = avg;

        if (sessionCount % SESSIONS_BEFORE_LONG_BREAK == 0) {
            breakDuration = BREAK_EXTRA_LONG;
        } else if (avg != null && avg >= 50) {
            breakDuration = BREAK_LONG;
        } else {
            breakDuration = BREAK_SHORT;
        }

        state = STATE_BREAK_PROMPT;
        WatchUi.requestUpdate();
    }

    function transitionToReady() as Void {
        vibrateComplete();
        state = STATE_READY;
        timeRemaining = 0;
        stressAverage = null;
        isPaused = false;
        WatchUi.requestUpdate();
    }

    function resetToReady() as Void {
        stopTimer();
        state = STATE_READY;
        timeRemaining = 0;
        stressAverage = null;
        isPaused = false;
        WatchUi.requestUpdate();
    }

    public function vibrateStart() as Void {
        // Short single vibration for START
        Attention.vibrate([new Attention.VibeProfile(40, 80)]);
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_ALERT_LO);
        }
    }
    
    public function vibratePause() as Void {
        // Double short vibration for PAUSE
        Attention.vibrate([
            new Attention.VibeProfile(30, 60),
            new Attention.VibeProfile(0, 60),
            new Attention.VibeProfile(30, 60)
        ]);
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }
    }
    
    public function vibrateComplete() as Void {
        // Long vibration for SESSION END
        Attention.vibrate([new Attention.VibeProfile(60, 350)]);
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }
    }

    private function calculateAverageStress() as Number? {
        // Get last 27 minutes (9 samples x 3min) to cover exactly full focus session
        var iter = SensorHistory.getStressHistory({:period => 27});
        if (iter == null) {
            return null;
        }

        var sum = 0;
        var count = 0;
        var sample = iter.next();
        while (sample != null) {
            if (sample.data != null) {
                sum = sum + sample.data;
                count = count + 1;
            }
            sample = iter.next();
        }

        if (count == 0) {
            return null;
        }
        return sum / count;
    }
}

function getApp() as Stress_AwarePomodoroApp {
    return Application.getApp() as Stress_AwarePomodoroApp;
}
