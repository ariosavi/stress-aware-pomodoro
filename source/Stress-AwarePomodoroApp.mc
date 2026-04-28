import Toybox.Application;
import Toybox.Attention;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

(:background, :glance)
class Stress_AwarePomodoroApp extends Application.AppBase {

    public var state as Number = PomoState.POMO_STATE_READY;
    public var timer as Timer.Timer?;
    public var timeRemaining as Number = 0;
    public var breakDuration as Number = 0;
    public var stressAverage as Number?;
    public var isPaused as Boolean = false;
    public var sessionCount as Number = 0;
    public var timerEndEpoch as Number = 0;
    public var currentPhaseDuration as Number = 0;

    public var focusDurationMinutes as Number = 25;
    public var breakShortMinutes as Number = 5;
    public var breakLongMinutes as Number = 10;
    public var breakExtraLongMinutes as Number = 15;
    public var sessionsBeforeLongBreak as Number = 4;
    public var stressThreshold as Number = 50;
    public var vibrationLevel as Number = 1;
    public var enableSound as Boolean = true;

    public const STATE_READY = PomoState.POMO_STATE_READY;
    public const STATE_FOCUSING = PomoState.POMO_STATE_FOCUSING;
    public const STATE_ANALYZING = PomoState.POMO_STATE_ANALYZING;
    public const STATE_BREAK_PROMPT = PomoState.POMO_STATE_BREAK_PROMPT;
    public const STATE_BREAK = PomoState.POMO_STATE_BREAK;

    function initialize() {
        AppBase.initialize();
        loadSettings();
        applySnapshot(PomoState.loadSnapshot());
        syncCountdownFromClock();
    }

    function onStart(state as Dictionary?) as Void {
        loadSettings();
        applySnapshot(PomoState.loadSnapshot());
        syncCountdownFromClock();
        recoverExpiredCountdown();
        restartUiTimerIfNeeded();
    }

    function onStop(state as Dictionary?) as Void {
        syncCountdownFromClock();
        saveState();
        stopUiTimer();
    }

    function onSettingsChanged() as Void {
        loadSettings();
        saveState();
        WatchUi.requestUpdate();
    }

    function onBackgroundData(data) as Void {
        applySnapshot(PomoState.loadSnapshot());
        syncCountdownFromClock();
        restartUiTimerIfNeeded();
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new Stress_AwarePomodoroView();
        return [view, new Stress_AwarePomodoroDelegate(view)];
    }

    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new Stress_AwarePomodoroGlanceView()];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new Stress_AwarePomodoroServiceDelegate()];
    }

    function beginFocusSession() as Void {
        var snapshot = exportSnapshot();
        snapshot = PomoState.startCountdown(snapshot, STATE_FOCUSING, focusDurationMinutes * 60, Time.now().value());
        applySnapshot(snapshot);
        saveState();
        scheduleBackgroundDeadline();
        startUiTimer();
        vibrateStart();
        WatchUi.requestUpdate();
    }

    function beginBreakSession() as Void {
        var snapshot = exportSnapshot();
        snapshot = PomoState.startCountdown(snapshot, STATE_BREAK, breakDuration, Time.now().value());
        snapshot.breakDuration = breakDuration;
        applySnapshot(snapshot);
        saveState();
        scheduleBackgroundDeadline();
        startUiTimer();
        vibrateStart();
        WatchUi.requestUpdate();
    }

    function pauseActiveTimer() as Void {
        var snapshot = exportSnapshot();
        snapshot = PomoState.pauseCountdown(snapshot, Time.now().value());
        applySnapshot(snapshot);
        saveState();
        clearBackgroundDeadline();
        stopUiTimer();
        vibratePause();
        WatchUi.requestUpdate();
    }

    function resumeActiveTimer() as Void {
        var snapshot = exportSnapshot();
        snapshot = PomoState.resumeCountdown(snapshot, Time.now().value());
        applySnapshot(snapshot);
        saveState();
        scheduleBackgroundDeadline();
        startUiTimer();
        vibratePause();
        WatchUi.requestUpdate();
    }

    function resetToReady() as Void {
        var snapshot = exportSnapshot();
        snapshot = PomoState.resetSnapshot(snapshot);
        applySnapshot(snapshot);
        saveState();
        clearBackgroundDeadline();
        stopUiTimer();
        WatchUi.requestUpdate();
    }

    function skipBreak() as Void {
        var snapshot = exportSnapshot();
        snapshot = PomoState.skipBreakSnapshot(snapshot);
        applySnapshot(snapshot);
        saveState();
        clearBackgroundDeadline();
        stopUiTimer();
        WatchUi.requestUpdate();
    }

    function saveState() as Void {
        PomoState.saveSnapshot(exportSnapshot());
    }

    public function vibrateStart() as Void {
        if (vibrationLevel == 0) { return; }
        var duration = (vibrationLevel == 1) ? 80 : 120;
        Attention.vibrate([new Attention.VibeProfile(40, duration)]);
        if (Attention has :playTone && enableSound) {
            Attention.playTone(Attention.TONE_ALERT_LO);
        }
    }

    public function vibratePause() as Void {
        if (vibrationLevel == 0) { return; }
        var intensity = (vibrationLevel == 1) ? 30 : 50;
        var duration = (vibrationLevel == 1) ? 60 : 90;
        Attention.vibrate([
            new Attention.VibeProfile(intensity, duration),
            new Attention.VibeProfile(0, duration),
            new Attention.VibeProfile(intensity, duration)
        ]);
        if (Attention has :playTone && enableSound) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }
    }

    public function vibrateComplete() as Void {
        if (vibrationLevel == 0) { return; }
        var duration = (vibrationLevel == 1) ? 350 : 500;
        Attention.vibrate([new Attention.VibeProfile(60, duration)]);
        if (Attention has :playTone && enableSound) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }
    }

    private function loadSettings() as Void {
        focusDurationMinutes = Application.Properties.getValue("FocusDurationMinutes") as Number;
        breakShortMinutes = Application.Properties.getValue("BreakShortMinutes") as Number;
        breakLongMinutes = Application.Properties.getValue("BreakLongMinutes") as Number;
        breakExtraLongMinutes = Application.Properties.getValue("BreakExtraLongMinutes") as Number;
        sessionsBeforeLongBreak = Application.Properties.getValue("SessionsBeforeLongBreak") as Number;
        stressThreshold = Application.Properties.getValue("StressThreshold") as Number;
        vibrationLevel = Application.Properties.getValue("VibrationLevel") as Number;
        enableSound = Application.Properties.getValue("EnableSound") as Boolean;
    }

    private function exportSnapshot() as PomoState.Snapshot {
        var snapshot = PomoState.newSnapshot();
        snapshot.state = state;
        snapshot.timeRemaining = timeRemaining;
        snapshot.breakDuration = breakDuration;
        snapshot.stressAverage = stressAverage;
        snapshot.isPaused = isPaused;
        snapshot.sessionCount = sessionCount;
        snapshot.timerEndEpoch = timerEndEpoch;
        snapshot.phaseDuration = currentPhaseDuration;
        return snapshot;
    }

    private function applySnapshot(snapshot as PomoState.Snapshot) as Void {
        state = snapshot.state;
        timeRemaining = snapshot.timeRemaining;
        breakDuration = snapshot.breakDuration;
        stressAverage = snapshot.stressAverage;
        isPaused = snapshot.isPaused;
        sessionCount = snapshot.sessionCount;
        timerEndEpoch = snapshot.timerEndEpoch;
        currentPhaseDuration = snapshot.phaseDuration;
    }

    private function syncCountdownFromClock() as Void {
        var snapshot = exportSnapshot();
        snapshot = PomoState.syncCountdown(snapshot, Time.now().value());
        applySnapshot(snapshot);
    }

    private function recoverExpiredCountdown() as Void {
        if (!PomoState.isRunningState(state) || isPaused) {
            return;
        }

        syncCountdownFromClock();
        if (timeRemaining > 0) {
            return;
        }

        finalizeCountdown(false);
    }

    private function restartUiTimerIfNeeded() as Void {
        if (PomoState.isRunningState(state) && !isPaused) {
            startUiTimer();
        } else {
            stopUiTimer();
        }
    }

    private function startUiTimer() as Void {
        if (timer == null) {
            timer = new Timer.Timer();
        }
        timer.start(method(:handleTimerTick), 1000, true);
    }

    private function stopUiTimer() as Void {
        if (timer != null) {
            timer.stop();
        }
    }

    public function handleTimerTick() as Void {
        syncCountdownFromClock();
        if (timeRemaining <= 0 && PomoState.isRunningState(state) && !isPaused) {
            finalizeCountdown(true);
            return;
        }

        saveState();
        WatchUi.requestUpdate();
    }

    private function finalizeCountdown(shouldAlert as Boolean) as Void {
        clearBackgroundDeadline();
        stopUiTimer();

        var snapshot = exportSnapshot();
        snapshot = PomoState.completeCountdown(snapshot);
        applySnapshot(snapshot);
        saveState();

        if (shouldAlert) {
            vibrateComplete();
            if (state == STATE_BREAK_PROMPT) {
                vibrateComplete();
            }
        }

        WatchUi.requestUpdate();
    }

    private function scheduleBackgroundDeadline() as Void {
        if (!PomoState.isRunningState(state) || isPaused || timerEndEpoch <= 0) {
            clearBackgroundDeadline();
            return;
        }

        try {
            Background.registerForTemporalEvent(new Time.Moment(timerEndEpoch));
        } catch (ex) {
            System.println("Unable to schedule background event: " + ex.toString());
        }
    }

    private function clearBackgroundDeadline() as Void {
        try {
            Background.deleteTemporalEvent();
        } catch (ex) {
        }
    }
}

(:background)
class Stress_AwarePomodoroServiceDelegate extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var snapshot = PomoState.loadSnapshot();
        snapshot = PomoState.syncCountdown(snapshot, Time.now().value());

        if (PomoState.isRunningState(snapshot.state)
                && !snapshot.isPaused
                && snapshot.timeRemaining <= 0) {
            snapshot = PomoState.completeCountdown(snapshot);
            PomoState.saveSnapshot(snapshot);
            triggerBackgroundAlert();
        }

        Background.exit([
            snapshot.state,
            snapshot.timeRemaining
        ]);
    }

    private function triggerBackgroundAlert() as Void {
        var vibrationLevel = Application.Properties.getValue("VibrationLevel") as Number;
        var enableSound = Application.Properties.getValue("EnableSound") as Boolean;

        if (vibrationLevel > 0) {
            var duration = (vibrationLevel == 1) ? 350 : 500;
            Attention.vibrate([new Attention.VibeProfile(60, duration)]);
        }

        if (Attention has :playTone && enableSound) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }
    }
}

function getApp() as Stress_AwarePomodoroApp {
    return Application.getApp() as Stress_AwarePomodoroApp;
}
