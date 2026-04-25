import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

class Stress_AwarePomodoroDelegate extends WatchUi.BehaviorDelegate {

    function initialize(view as Stress_AwarePomodoroView) {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        // ✅ Open menu with first item selected by default
        openMenu(0);
        return true;
    }

    function onBack() as Boolean {
        // ✅ Open menu with EXIT item pre-selected when BACK button is pressed
        openMenu(-1);
        return true;
    }
    
    private function openMenu(selectedIndex as Number) as Void {
        var menu = new WatchUi.Menu();
        var app = getApp();

        if (selectedIndex == -1) {
            // ✅ For BACK button: add EXIT first so it will be selected by default
            menu.addItem("Exit", :exit);
            
            if (app.state == app.STATE_BREAK_PROMPT || app.state == app.STATE_BREAK) {
                menu.addItem("Skip Break", :skip_break);
            }
            
            if (app.state != app.STATE_READY) {
                menu.addItem("Reset", :reset);
            }

            if ((app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) && app.isPaused) {
                menu.addItem("Resume", :resume);
            }

            if ((app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) && !app.isPaused) {
                menu.addItem("Pause", :pause);
            }

            if (app.state == app.STATE_READY) {
                menu.addItem("Start Pomodoro", :start);
            }
        } else {
            // ✅ For SELECT button: normal order, first item selected by default
            if (app.state == app.STATE_READY) {
                menu.addItem("Start Pomodoro", :start);
            }

            if ((app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) && !app.isPaused) {
                menu.addItem("Pause", :pause);
            }

            if ((app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) && app.isPaused) {
                menu.addItem("Resume", :resume);
            }

            if (app.state != app.STATE_READY) {
                menu.addItem("Reset", :reset);
            }

            if (app.state == app.STATE_BREAK_PROMPT || app.state == app.STATE_BREAK) {
                menu.addItem("Skip Break", :skip_break);
            }

            menu.addItem("Exit", :exit);
        }

        WatchUi.pushView(menu, new PomodoroMenuDelegate(), WatchUi.SLIDE_UP);
    }
}

class PomodoroMenuDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }
    
    function onBack() as Boolean {
        // ✅ Same behavior for back button inside menu
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onMenuItem(menuItem as Symbol) as Boolean {
        var app = getApp();

        switch(menuItem) {
            case :start:
                if (app.state == app.STATE_READY) {
                    app.state = app.STATE_FOCUSING;
                    app.timeRemaining = app.FOCUS_DURATION;
                    app.isPaused = false;
                    app.startTimer();
                    app.vibrateStart();
                }
                break;

            case :pause:
                if ((app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) && !app.isPaused) {
                    app.isPaused = true;
                    app.stopTimer();
                    app.vibratePause();
                    app.saveState();
                }
                break;

            case :resume:
                if ((app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) && app.isPaused) {
                    app.isPaused = false;
                    app.startTimer();
                    app.vibratePause();
                    app.saveState();
                }
                break;

            case :reset:
                app.resetToReady();
                break;

            case :skip_break:
                if (app.state == app.STATE_BREAK_PROMPT || app.state == app.STATE_BREAK) {
                    app.resetToReady();
                }
                break;

            case :exit:
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return true;
        }

        WatchUi.requestUpdate();

        return true;
    }
}