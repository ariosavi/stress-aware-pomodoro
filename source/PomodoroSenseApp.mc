import Toybox.Application;
import Toybox.Attention;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

(:background)
class PomodoroSenseApp extends Application.AppBase {

    public var state as Number = PomoState.POMO_STATE_READY;
    public var timer as Timer.Timer?;
    public var timeRemaining as Number = 0;
    public var breakDuration as Number = 0;
    public var stressAverage as Number?;
    public var isPaused as Boolean = false;
    public var sessionCount as Number = 0;
    public var timerEndEpoch as Number = 0;
    public var currentPhaseDuration as Number = 0;
    public var alertPending as Boolean = false;

    public var focusDurationMinutes as Number = 25;
    public var breakShortMinutes as Number = 5;
    public var breakLongMinutes as Number = 10;
    public var breakExtraLongMinutes as Number = 15;
    public var sessionsBeforeLongBreak as Number = 4;
    public var stressThreshold as Number = 50;
    public var vibrationLevel as Number = 1;
    public var enableSound as Boolean = true;
    public var displaySeconds as Boolean = true;
    public var bodyBatteryAtStart as Number?;
    public var hrAverage as Number?;

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

        if (alertPending) {
            alertPending = false;
            saveState();
            vibrateComplete();
        }

        restartUiTimerIfNeeded();
    }

    function onStop(state as Dictionary?) as Void {
        syncCountdownFromClock();
        saveState();
        stopUiTimer();
        scheduleBackgroundDeadline();
    }

    function onSettingsChanged() as Void {
        // Check if user selected "Delete All Data" option
        var clearHistoryValue = Application.Properties.getValue("ClearHistory") as Number;
        if (clearHistoryValue != null && clearHistoryValue == 1) {
            // Clear session history
            PomoState.clearSessionHistory();
            // Reset the value back to 0 (No Action)
            Application.Properties.setValue("ClearHistory", 0);
        }
        
        loadSettings();
        saveState();
        WatchUi.requestUpdate();
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        var snapshot = PomoState.loadSnapshot();

        applySnapshot(snapshot);
        syncCountdownFromClock();

        var shouldAlert = (data instanceof Lang.Boolean && data == true)
                       || snapshot.alertPending;

        if (shouldAlert) {
            alertPending = false;
            saveState();
            vibrateComplete();
        }

        restartUiTimerIfNeeded();
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new PomodoroSenseView();
        return [view, new PomodoroSenseDelegate(view)];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new PomodoroSenseServiceDelegate()];
    }

    function beginFocusSession() as Void {
        var snapshot = exportSnapshot();
        snapshot = PomoState.startCountdown(snapshot, STATE_FOCUSING, focusDurationMinutes * 60, Time.now().value());
        snapshot.bodyBatteryAtStart = getCurrentBodyBattery();
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
        snapshot.bodyBatteryAtStart = getCurrentBodyBattery();
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
        if (vibrationLevel == 0 || !(Attention has :vibrate)) { return; }
        var duration = (vibrationLevel == 1) ? 80 : 120;
        Attention.vibrate([new Attention.VibeProfile(40, duration)]);
        if (Attention has :playTone && enableSound) {
            Attention.playTone(Attention.TONE_ALERT_LO);
        }
    }

    public function vibratePause() as Void {
        if (vibrationLevel == 0 || !(Attention has :vibrate)) { return; }
        var intensity = (vibrationLevel == 1) ? 30 : 50;
        var duration = (vibrationLevel == 1) ? 60 : 200;
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
        if (vibrationLevel == 0 || !(Attention has :vibrate)) { return; }
        var duration = (vibrationLevel == 1) ? 350 : 500;
        Attention.vibrate([new Attention.VibeProfile(100, duration)]);
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
        displaySeconds = Application.Properties.getValue("DisplaySeconds") as Boolean;
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
        snapshot.alertPending = alertPending;
        snapshot.bodyBatteryAtStart = bodyBatteryAtStart;
        snapshot.hrAverage = hrAverage;
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
        alertPending = snapshot.alertPending;
        bodyBatteryAtStart = snapshot.bodyBatteryAtStart;
        hrAverage = snapshot.hrAverage;
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
        finalizeCountdown(true);
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
        
        // Save session record if we just completed a focus session
        if (state == STATE_FOCUSING) {
            var bodyBatteryAtEnd = getCurrentBodyBattery();
            PomoState.saveSessionRecord(snapshot.stressAverage, snapshot.hrAverage, bodyBatteryAtStart, bodyBatteryAtEnd, focusDurationMinutes);
        }
        
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
            var now = Time.now().value();
            if (timerEndEpoch <= now) {
                return;
            }
            var pollInterval = 5 * 60;
            var nextWakeUp = now + pollInterval;
            if (timerEndEpoch > nextWakeUp) {
                nextWakeUp = timerEndEpoch;
            }
            Background.registerForTemporalEvent(new Time.Moment(nextWakeUp));
        } catch (ex) {
        }
    }

    private function clearBackgroundDeadline() as Void {
        try {
            Background.deleteTemporalEvent();
        } catch (ex) {
        }
    }

    private function getCurrentBodyBattery() as Number? {
        try {
            var iter = Toybox.SensorHistory.getBodyBatteryHistory({:period => 1});
            var sample = iter.next();
            if (sample != null && sample.data != null) {
                return sample.data;
            }
        } catch (ex) {
        }
        return null;
    }
}

function getApp() as PomodoroSenseApp {
    return Application.getApp() as PomodoroSenseApp;
}
