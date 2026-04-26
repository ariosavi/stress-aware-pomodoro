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

            menu.addItem("Settings", :settings);

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

            menu.addItem("Settings", :settings);
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

    private function openSettingsMenu() as Void {
        var menu = new WatchUi.Menu();
        menu.setTitle("Settings");

        menu.addItem("Focus Duration", :focus_duration);
        menu.addItem("Short Break", :short_break);
        menu.addItem("Long Break", :long_break);
        menu.addItem("Extra Long Break", :extra_long_break);
        menu.addItem("Sessions Before Long", :sessions_before_long);
        menu.addItem("Stress Threshold", :stress_threshold);
        menu.addItem("Vibration", :vibration);
        menu.addItem("Sound Alerts", :sound_alerts);
        menu.addItem("Back to App", :back_to_app);

        WatchUi.pushView(menu, new SettingsMenuDelegate(), WatchUi.SLIDE_UP);
    }

    private function getVibrationLabel(level as Number) as String {
        switch(level) {
            case 0: return "None";
            case 1: return "Normal";
            case 2: return "Long";
            default: return "Normal";
        }
    }

    function onMenuItem(menuItem as Symbol) as Boolean {
        var app = getApp();

        switch(menuItem) {
            case :start:
                if (app.state == app.STATE_READY) {
                    app.state = app.STATE_FOCUSING;
                    app.timeRemaining = app.focusDurationMinutes * 60;
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

            case :settings:
                openSettingsMenu();
                return true;

            case :exit:
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return true;
        }

        WatchUi.requestUpdate();
        return true;
    }
}

class SettingsMenuDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(menuItem as Symbol) as Void {
        switch(menuItem) {
            case :focus_duration:
                openOptionSettingMenu("Focus Duration", "FocusDurationMinutes", 
                    [15, 20, 25, 30, 45, 60], ["15m", "20m", "25m", "30m", "45m", "60m"]);
                break;
            case :short_break:
                openOptionSettingMenu("Short Break", "BreakShortMinutes", 
                    [3, 5, 7, 10], ["3m", "5m", "7m", "10m"]);
                break;
            case :long_break:
                openOptionSettingMenu("Long Break", "BreakLongMinutes", 
                    [8, 10, 15, 20], ["8m", "10m", "15m", "20m"]);
                break;
            case :extra_long_break:
                openOptionSettingMenu("Extra Long Break", "BreakExtraLongMinutes", 
                    [15, 20, 30, 45], ["15m", "20m", "30m", "45m"]);
                break;
            case :sessions_before_long:
                openOptionSettingMenu("Sessions Before Long", "SessionsBeforeLongBreak", 
                    [2, 3, 4, 5, 6], ["2", "3", "4", "5", "6"]);
                break;
            case :stress_threshold:
                openOptionSettingMenu("Stress Threshold", "StressThreshold", 
                    [40, 45, 50, 55, 60, 65, 70], ["40", "45", "50", "55", "60", "65", "70"]);
                break;
            case :vibration:
                openVibrationMenu();
                break;
            case :sound_alerts:
                openSoundMenu();
                break;
            case :back_to_app:
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                break;
        }
    }

    private function openOptionSettingMenu(title as String, propertyKey as String, options as Array, optionLabels as Array or Null) as Void {
        var currentVal = Application.Properties.getValue(propertyKey) as Number;
        var menu = new WatchUi.Menu();
        
        // Find the current option label
        var currentLabel = "";
        if (optionLabels != null) {
            for (var i = 0; i < options.size(); i++) {
                if (options[i] == currentVal) {
                    currentLabel = optionLabels[i];
                    break;
                }
            }
        }
        if (currentLabel.equals("")) {
            currentLabel = currentVal.format("%d");
        }
        menu.setTitle(title + ": " + currentLabel);

        // Add each option as a menu item
        for (var i = 0; i < options.size(); i++) {
            var label = optionLabels != null ? optionLabels[i] : options[i].format("%d");
            var symbol = getOptionSymbol(i);
            menu.addItem(label, symbol);
        }
        menu.addItem("Back", :back);

        WatchUi.pushView(menu, new OptionSettingDelegate(propertyKey, options, optionLabels), WatchUi.SLIDE_UP);
    }

    private function getOptionSymbol(index as Number) as Symbol {
        switch(index) {
            case 0: return :option_0;
            case 1: return :option_1;
            case 2: return :option_2;
            case 3: return :option_3;
            case 4: return :option_4;
            case 5: return :option_5;
            case 6: return :option_6;
            case 7: return :option_7;
            case 8: return :option_8;
            case 9: return :option_9;
            default: return :option_0;
        }
    }

    private function openNumberSettingMenu(title as String, propertyKey as String, minVal as Number, maxVal as Number, defaultVal as Number) as Void {
        var currentVal = Application.Properties.getValue(propertyKey) as Number;
        var menu = new WatchUi.Menu();
        menu.setTitle(title + ": " + currentVal);

        menu.addItem("Increase (+)", :increase);
        menu.addItem("Decrease (-)", :decrease);
        menu.addItem("Back", :back);

        WatchUi.pushView(menu, new NumberSettingDelegate(propertyKey, minVal, maxVal, defaultVal, currentVal, title), WatchUi.SLIDE_UP);
    }

    private function openVibrationMenu() as Void {
        var currentVal = Application.Properties.getValue("VibrationLevel") as Number;
        var menu = new WatchUi.Menu();
        menu.setTitle("Vibration: " + getVibrationLabel(currentVal));

        menu.addItem("None", :vibration_none);
        menu.addItem("Normal", :vibration_normal);
        menu.addItem("Long", :vibration_long);
        menu.addItem("Back", :back);

        WatchUi.pushView(menu, new VibrationSettingDelegate(), WatchUi.SLIDE_UP);
    }

    private function openSoundMenu() as Void {
        var currentVal = Application.Properties.getValue("EnableSound") as Boolean;
        var menu = new WatchUi.Menu();
        menu.setTitle("Sound Alerts: " + (currentVal ? "On" : "Off"));

        menu.addItem("On", :sound_on);
        menu.addItem("Off", :sound_off);
        menu.addItem("Back", :back);

        WatchUi.pushView(menu, new SoundSettingDelegate(), WatchUi.SLIDE_UP);
    }

    private function getVibrationLabel(level as Number) as String {
        switch(level) {
            case 0: return "None";
            case 1: return "Normal";
            case 2: return "Long";
            default: return "Normal";
        }
    }
}

class NumberSettingDelegate extends WatchUi.MenuInputDelegate {
    private var propertyKey as String;
    private var minVal as Number;
    private var maxVal as Number;
    private var currentVal as Number;

    function initialize(propKey as String, min as Number, max as Number, def as Number, current as Number, menuTitle as String) {
        MenuInputDelegate.initialize();
        propertyKey = propKey;
        minVal = min;
        maxVal = max;
        currentVal = current;
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :increase) {
            if (currentVal < maxVal) {
                currentVal = currentVal + 1;
                Application.Properties.setValue(propertyKey, currentVal);
                getApp().onSettingsChanged();
            }
        } else if (item == :decrease) {
            if (currentVal > minVal) {
                currentVal = currentVal - 1;
                Application.Properties.setValue(propertyKey, currentVal);
                getApp().onSettingsChanged();
            }
        } else if (item == :back) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }
}

class VibrationSettingDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        var value = -1;

        if (item == :vibration_none) {
            value = 0;
        } else if (item == :vibration_normal) {
            value = 1;
        } else if (item == :vibration_long) {
            value = 2;
        } else if (item == :back) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return;
        }

        if (value >= 0) {
            Application.Properties.setValue("VibrationLevel", value);
            getApp().onSettingsChanged();
        }
        // Stay in the menu after changing - use Back to go back
    }

    private function getVibrationLabel(level as Number) as String {
        switch(level) {
            case 0: return "None";
            case 1: return "Normal";
            case 2: return "Long";
            default: return "Normal";
        }
    }
}

class SoundSettingDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        var value = false;

        if (item == :sound_on) {
            value = true;
        } else if (item == :sound_off) {
            value = false;
        } else if (item == :back) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return;
        }

        Application.Properties.setValue("EnableSound", value);
        getApp().onSettingsChanged();
        // Stay in the menu after changing - use Back to go back
    }
}

class OptionSettingDelegate extends WatchUi.MenuInputDelegate {

    private var propertyKey as String;
    private var options as Array;
    private var optionLabels as Array or Null;

    function initialize(propKey as String, opts as Array, labels as Array or Null) {
        MenuInputDelegate.initialize();
        propertyKey = propKey;
        options = opts;
        optionLabels = labels;
    }

    function onMenuItem(item as Symbol) as Void {
        var value = -1;

        // Check which option was selected
        for (var i = 0; i < options.size(); i++) {
            var symbol = getOptionSymbol(i);
            if (item == symbol) {
                value = options[i];
                break;
            }
        }

        if (item == :back) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return;
        }

        if (value >= 0) {
            Application.Properties.setValue(propertyKey, value);
            getApp().onSettingsChanged();
            // Stay in the menu after changing - use Back to go back
        }
    }

    private function getOptionSymbol(index as Number) as Symbol {
        switch(index) {
            case 0: return :option_0;
            case 1: return :option_1;
            case 2: return :option_2;
            case 3: return :option_3;
            case 4: return :option_4;
            case 5: return :option_5;
            case 6: return :option_6;
            case 7: return :option_7;
            case 8: return :option_8;
            case 9: return :option_9;
            default: return :option_0;
        }
    }

    private function getOptionLabel(value as Number) as String {
        if (optionLabels != null) {
            for (var i = 0; i < options.size(); i++) {
                if (options[i] == value) {
                    return optionLabels[i];
                }
            }
        }
        return value.format("%d");
    }
}