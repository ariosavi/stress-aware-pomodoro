using Toybox.Application;
using Toybox.Lang;
using Toybox.Math;
using Toybox.SensorHistory;

module PomoState {

const POMO_STATE_READY = 0;
const POMO_STATE_FOCUSING = 1;
const POMO_STATE_ANALYZING = 2;
const POMO_STATE_BREAK_PROMPT = 3;
const POMO_STATE_BREAK = 4;

const KEY_STATE = "app_state_state";
const KEY_TIME_REMAINING = "app_state_time_remaining";
const KEY_BREAK_DURATION = "app_state_break_duration";
const KEY_STRESS_AVERAGE = "app_state_stress_average";
const KEY_IS_PAUSED = "app_state_is_paused";
const KEY_SESSION_COUNT = "app_state_session_count";
const KEY_TIMER_END_EPOCH = "app_state_timer_end_epoch";
const KEY_PHASE_DURATION = "app_state_phase_duration";
const KEY_ALERT_PENDING = "app_state_alert_pending";
const KEY_BODY_BATTERY_AT_START = "app_state_body_battery_at_start";
const KEY_HR_AVERAGE = "app_state_hr_average";
const KEY_SESSION_HISTORY = "app_session_history";
const KEY_SESSION_HISTORY_INDEX = "app_session_history_index";
const MAX_HISTORY_RECORDS = 100;

class Snapshot {
    var state = POMO_STATE_READY;
    var timeRemaining = 0;
    var breakDuration = 0;
    var stressAverage;
    var isPaused = false;
    var sessionCount = 0;
    var timerEndEpoch = 0;
    var phaseDuration = 0;
    var alertPending = false;
    var bodyBatteryAtStart;
    var hrAverage;
}

function newSnapshot() as Snapshot {
    return new Snapshot();
}

function loadSnapshot() as Snapshot {
    var snapshot = new Snapshot();

    var storedState = Application.Storage.getValue(KEY_STATE);
    if (storedState != null) {
        snapshot.state = storedState;
    }

    var storedTimeRemaining = Application.Storage.getValue(KEY_TIME_REMAINING);
    if (storedTimeRemaining != null) {
        snapshot.timeRemaining = storedTimeRemaining;
    }

    var storedBreakDuration = Application.Storage.getValue(KEY_BREAK_DURATION);
    if (storedBreakDuration != null) {
        snapshot.breakDuration = storedBreakDuration;
    }

    var storedStressAverage = Application.Storage.getValue(KEY_STRESS_AVERAGE);
    if (storedStressAverage != null) {
        snapshot.stressAverage = storedStressAverage;
    }

    var storedPaused = Application.Storage.getValue(KEY_IS_PAUSED);
    if (storedPaused != null) {
        snapshot.isPaused = storedPaused;
    }

    var storedSessionCount = Application.Storage.getValue(KEY_SESSION_COUNT);
    if (storedSessionCount != null) {
        snapshot.sessionCount = storedSessionCount;
    }

    var storedTimerEndEpoch = Application.Storage.getValue(KEY_TIMER_END_EPOCH);
    if (storedTimerEndEpoch != null) {
        snapshot.timerEndEpoch = storedTimerEndEpoch;
    }

    var storedPhaseDuration = Application.Storage.getValue(KEY_PHASE_DURATION);
    if (storedPhaseDuration != null) {
        snapshot.phaseDuration = storedPhaseDuration;
    }

    var storedAlertPending = Application.Storage.getValue(KEY_ALERT_PENDING);
    if (storedAlertPending != null) {
        snapshot.alertPending = storedAlertPending;
    }

    var storedBodyBatteryAtStart = Application.Storage.getValue(KEY_BODY_BATTERY_AT_START);
    if (storedBodyBatteryAtStart != null) {
        snapshot.bodyBatteryAtStart = storedBodyBatteryAtStart;
    }

    var storedHrAverage = Application.Storage.getValue(KEY_HR_AVERAGE);
    if (storedHrAverage != null) {
        snapshot.hrAverage = storedHrAverage;
    }

    return snapshot;
}

function saveSnapshot(snapshot as Snapshot) as Void {
    Application.Storage.setValue(KEY_STATE, snapshot.state);
    Application.Storage.setValue(KEY_TIME_REMAINING, snapshot.timeRemaining);
    Application.Storage.setValue(KEY_BREAK_DURATION, snapshot.breakDuration);
    Application.Storage.setValue(KEY_STRESS_AVERAGE, snapshot.stressAverage);
    Application.Storage.setValue(KEY_IS_PAUSED, snapshot.isPaused);
    Application.Storage.setValue(KEY_SESSION_COUNT, snapshot.sessionCount);
    Application.Storage.setValue(KEY_TIMER_END_EPOCH, snapshot.timerEndEpoch);
    Application.Storage.setValue(KEY_PHASE_DURATION, snapshot.phaseDuration);
    Application.Storage.setValue(KEY_ALERT_PENDING, snapshot.alertPending);
    Application.Storage.setValue(KEY_BODY_BATTERY_AT_START, snapshot.bodyBatteryAtStart);
    Application.Storage.setValue(KEY_HR_AVERAGE, snapshot.hrAverage);
}

function isRunningState(state) {
    return state == POMO_STATE_FOCUSING || state == POMO_STATE_BREAK;
}

function syncCountdown(snapshot as Snapshot, nowEpoch) as Snapshot {
    if (!isRunningState(snapshot.state) || snapshot.isPaused || snapshot.timerEndEpoch <= 0) {
        return snapshot;
    }

    var remaining = snapshot.timerEndEpoch - nowEpoch;
    if (remaining < 0) {
        remaining = 0;
    }

    snapshot.timeRemaining = remaining;
    return snapshot;
}

function startCountdown(snapshot as Snapshot, nextState, durationSeconds, nowEpoch) as Snapshot {
    snapshot.state = nextState;
    snapshot.timeRemaining = durationSeconds;
    snapshot.isPaused = false;
    snapshot.timerEndEpoch = nowEpoch + durationSeconds;
    snapshot.phaseDuration = durationSeconds;

    if (nextState != POMO_STATE_BREAK) {
        snapshot.breakDuration = 0;
    }

    return snapshot;
}

function pauseCountdown(snapshot as Snapshot, nowEpoch) as Snapshot {
    snapshot = syncCountdown(snapshot, nowEpoch);
    snapshot.isPaused = true;
    snapshot.timerEndEpoch = 0;
    return snapshot;
}

function resumeCountdown(snapshot as Snapshot, nowEpoch) as Snapshot {
    snapshot.isPaused = false;
    snapshot.timerEndEpoch = nowEpoch + snapshot.timeRemaining;
    snapshot.phaseDuration = snapshot.timeRemaining;
    return snapshot;
}

function resetSnapshot(snapshot as Snapshot) as Snapshot {
    snapshot.state = POMO_STATE_READY;
    snapshot.timeRemaining = 0;
    snapshot.breakDuration = 0;
    snapshot.stressAverage = null;
    snapshot.isPaused = false;
    snapshot.sessionCount = 0;
    snapshot.timerEndEpoch = 0;
    snapshot.phaseDuration = 0;
    snapshot.bodyBatteryAtStart = null;
    snapshot.hrAverage = null;
    return snapshot;
}

function skipBreakSnapshot(snapshot as Snapshot) as Snapshot {
    snapshot.state = POMO_STATE_READY;
    snapshot.timeRemaining = 0;
    snapshot.breakDuration = 0;
    snapshot.stressAverage = null;
    snapshot.isPaused = false;
    snapshot.timerEndEpoch = 0;
    snapshot.phaseDuration = 0;
    snapshot.bodyBatteryAtStart = null;
    snapshot.hrAverage = null;
    return snapshot;
}

function completeCountdown(snapshot as Snapshot) as Snapshot {
    var previousState = snapshot.state;

    snapshot.timeRemaining = 0;
    snapshot.timerEndEpoch = 0;
    snapshot.isPaused = false;
    snapshot.phaseDuration = 0;

    if (previousState == POMO_STATE_FOCUSING) {
        var focusDurationMinutes = Application.Properties.getValue("FocusDurationMinutes");
        var breakShortMinutes = Application.Properties.getValue("BreakShortMinutes");
        var breakLongMinutes = Application.Properties.getValue("BreakLongMinutes");
        var breakExtraLongMinutes = Application.Properties.getValue("BreakExtraLongMinutes");
        var sessionsBeforeLongBreak = Application.Properties.getValue("SessionsBeforeLongBreak");
        var stressThreshold = Application.Properties.getValue("StressThreshold");

        snapshot.sessionCount = snapshot.sessionCount + 1;
        snapshot.stressAverage = calculateAverageStress(focusDurationMinutes);
        snapshot.hrAverage = calculateAverageHeartRate(focusDurationMinutes);
        snapshot.breakDuration = breakShortMinutes * 60;

        if (snapshot.sessionCount % sessionsBeforeLongBreak == 0) {
            snapshot.breakDuration = breakExtraLongMinutes * 60;
        } else if (snapshot.stressAverage != null && snapshot.stressAverage >= stressThreshold) {
            snapshot.breakDuration = breakLongMinutes * 60;
        }

        snapshot.state = POMO_STATE_BREAK_PROMPT;
    } else if (previousState == POMO_STATE_BREAK) {
        snapshot.state = POMO_STATE_READY;
        snapshot.breakDuration = 0;
        snapshot.stressAverage = null;
        snapshot.hrAverage = null;
    }

    return snapshot;
}

// Calculate average heart rate for the given period (in minutes)
function calculateAverageHeartRate(periodMinutes) {
    try {
        var iter = SensorHistory.getHeartRateHistory({:period => periodMinutes});
        var sum = 0.0;
        var count = 0;
        var sample = iter.next();

        while (sample != null) {
            var hr = sample.data;
            if (hr != null) {
                sum = sum + hr.toFloat();
                count = count + 1;
            }
            sample = iter.next();
        }

        if (count == 0) {
            return null;
        }

        return Math.round(sum / count).toNumber();
    } catch (ex) {
        return null;
    }
}

function calculateAverageStress(periodMinutes) {
    try {
        var iter = SensorHistory.getStressHistory({:period => periodMinutes});
        var sum = 0.0;
        var count = 0;
        var sample = iter.next();

        while (sample != null) {
            var stress = sample.data;
            if (stress != null) {
                sum = sum + stress.toFloat();
                count = count + 1;
            }
            sample = iter.next();
        }

        if (count == 0) {
            return null;
        }

        return Math.round(sum / count).toNumber();
    } catch (ex) {
        return null;
    }
}

// Save a session record to history
function saveSessionRecord(stressAverage, hrAverage, bodyBatteryAtStart, bodyBatteryAtEnd, focusDurationMinutes) as Void {
    try {
        var history = getSessionHistory();
        
        // Create new record
        var record = {
            "timestamp" => Toybox.Time.now().value(),
            "stress" => stressAverage,
            "hr" => hrAverage,
            "batteryStart" => bodyBatteryAtStart,
            "batteryEnd" => bodyBatteryAtEnd,
            "duration" => focusDurationMinutes
        };
        
        history.add(record);
        
        // Keep only last MAX_HISTORY_RECORDS
        if (history.size() > MAX_HISTORY_RECORDS) {
            history = history.slice(history.size() - MAX_HISTORY_RECORDS, history.size());
        }
        
        Application.Storage.setValue(KEY_SESSION_HISTORY, history);
    } catch (ex) {
    }
}

// Load session history
function getSessionHistory() as Toybox.Lang.Array {
    var history = Application.Storage.getValue(KEY_SESSION_HISTORY);
    if (history == null) {
        history = [];
    }
    return history;
}

// Clear all session history
function clearSessionHistory() as Void {
    try {
        Application.Storage.setValue(KEY_SESSION_HISTORY, []);
    } catch (ex) {
    }
}

}


