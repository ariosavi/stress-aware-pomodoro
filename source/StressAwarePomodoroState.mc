using Toybox.Application;
using Toybox.Lang;
using Toybox.Math;
using Toybox.SensorHistory;

module PomoState {

(:background, :glance) const POMO_STATE_READY = 0;
(:background, :glance) const POMO_STATE_FOCUSING = 1;
(:background, :glance) const POMO_STATE_ANALYZING = 2;
(:background, :glance) const POMO_STATE_BREAK_PROMPT = 3;
(:background, :glance) const POMO_STATE_BREAK = 4;

(:background, :glance) const KEY_STATE = "app_state_state";
(:background, :glance) const KEY_TIME_REMAINING = "app_state_time_remaining";
(:background, :glance) const KEY_BREAK_DURATION = "app_state_break_duration";
(:background, :glance) const KEY_STRESS_AVERAGE = "app_state_stress_average";
(:background, :glance) const KEY_IS_PAUSED = "app_state_is_paused";
(:background, :glance) const KEY_SESSION_COUNT = "app_state_session_count";
(:background, :glance) const KEY_TIMER_END_EPOCH = "app_state_timer_end_epoch";
(:background, :glance) const KEY_PHASE_DURATION = "app_state_phase_duration";

(:background, :glance)
class Snapshot {
    var state = POMO_STATE_READY;
    var timeRemaining = 0;
    var breakDuration = 0;
    var stressAverage;
    var isPaused = false;
    var sessionCount = 0;
    var timerEndEpoch = 0;
    var phaseDuration = 0;
}

(:background, :glance)
function newSnapshot() as Snapshot {
    return new Snapshot();
}

(:background, :glance)
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

    return snapshot;
}

(:background, :glance)
function saveSnapshot(snapshot as Snapshot) as Void {
    Application.Storage.setValue(KEY_STATE, snapshot.state);
    Application.Storage.setValue(KEY_TIME_REMAINING, snapshot.timeRemaining);
    Application.Storage.setValue(KEY_BREAK_DURATION, snapshot.breakDuration);
    Application.Storage.setValue(KEY_STRESS_AVERAGE, snapshot.stressAverage);
    Application.Storage.setValue(KEY_IS_PAUSED, snapshot.isPaused);
    Application.Storage.setValue(KEY_SESSION_COUNT, snapshot.sessionCount);
    Application.Storage.setValue(KEY_TIMER_END_EPOCH, snapshot.timerEndEpoch);
    Application.Storage.setValue(KEY_PHASE_DURATION, snapshot.phaseDuration);
}

(:background, :glance)
function isRunningState(state) {
    return state == POMO_STATE_FOCUSING || state == POMO_STATE_BREAK;
}

(:background, :glance)
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
    return snapshot;
}

function skipBreakSnapshot(snapshot as Snapshot) as Snapshot {
    snapshot.state = POMO_STATE_READY;
    snapshot.timeRemaining = 0;
    snapshot.breakDuration = 0;
    snapshot.stressAverage = null;
    snapshot.isPaused = false;
    // sessionCount is intentionally preserved
    snapshot.timerEndEpoch = 0;
    snapshot.phaseDuration = 0;
    return snapshot;
}

(:background)
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
    }

    return snapshot;
}

(:background)
function calculateAverageStress(periodMinutes) {
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
}

}
