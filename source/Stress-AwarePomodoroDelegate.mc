import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Application;

/**
 * Menu context constants for differentiating menu states.
 * Determines Exit option position and content.
 */
module MenuContext {
    const CONTEXT_SELECT = 0;                    // SELECT button: Exit shown last
    const CONTEXT_BACK = 1;                      // BACK button: Exit shown first
    const CONTEXT_BACK_DURING_TIMER = 2;         // BACK during active timer: No Exit
}

/**
 * Builder pattern for constructing menus with consistent structure.
 * Encapsulates menu item logic for clean, maintainable code.
 */
class MenuBuilder {
    private var title as String = "Menu";
    private var items as Array = [];
    private var symbols as Array = [];
    private var canShowExit as Boolean = true;

    /**
     * Sets the menu title.
     */
    function setTitle(menuTitle as String) as MenuBuilder {
        title = menuTitle;
        return self;
    }

    /**
     * Adds the Exit item (subject to availability constraints).
     */
    function addExitItem() as MenuBuilder {
        if (canShowExit) {
            items.add("Exit");
            symbols.add(:exit);
        }
        return self;
    }

    /**
     * Adds a generic menu item.
     */
    function addItem(label as String, symbol as Symbol) as MenuBuilder {
        items.add(label);
        symbols.add(symbol);
        return self;
    }

    /**
     * Adds Settings menu item.
     */
    function addSettingsItem() as MenuBuilder {
        items.add("Settings");
        symbols.add(:settings);
        return self;
    }

    /**
     * Adds conditional items based on app state.
     * Includes: Start/Resume/Pause, Reset, Start Break, Skip Break.
     */
    function addConditionalItems(app as Stress_AwarePomodoroApp) as MenuBuilder {
        // Start Pomodoro (when ready)
        if (app.state == app.STATE_READY) {
            items.add("Start Pomodoro");
            symbols.add(:start);
        }

        // Start Break (after focus session)
        if (app.state == app.STATE_BREAK_PROMPT) {
            items.add("Start Break");
            symbols.add(:start_break);
        }

        // Pause/Resume (during active session)
        if ((app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) && !app.isPaused) {
            items.add("Pause");
            symbols.add(:pause);
        }

        if ((app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) && app.isPaused) {
            items.add("Resume");
            symbols.add(:resume);
        }

        // Reset (when not ready, or when ready but has completed sessions)
        if (app.state != app.STATE_READY || app.sessionCount > 0) {
            items.add("Reset");
            symbols.add(:reset);
        }

        // Skip Break (during break prompt or break)
        if (app.state == app.STATE_BREAK_PROMPT || app.state == app.STATE_BREAK) {
            items.add("Skip Break");
            symbols.add(:skip_break);
        }

        // Disable Exit if timer is actively running
        var timerRunning = (app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) && !app.isPaused;
        canShowExit = !timerRunning;

        return self;
    }

    /**
     * Builds and returns the WatchUi.Menu with all configured items.
     */
    function build() as WatchUi.Menu {
        var menu = new WatchUi.Menu();
        menu.setTitle(title);

        for (var i = 0; i < items.size(); i++) {
            menu.addItem(items[i], symbols[i]);
        }

        return menu;
    }
}

/**
 * Main behavior delegate for the Pomodoro app view.
 * Handles SELECT and BACK button events to open context-aware menus.
 */
class Stress_AwarePomodoroDelegate extends WatchUi.BehaviorDelegate {

    function initialize(view as Stress_AwarePomodoroView) {
        BehaviorDelegate.initialize();
    }

    /**
     * SELECT button: Opens menu with standard item order (Exit last if shown).
     */
    function onSelect() as Boolean {
        openMenu(MenuContext.CONTEXT_SELECT);
        return true;
    }

    /**
     * BACK button: Opens menu with Exit as first item (if available).
     * If timer is actively running, opens a special "pause to exit" menu.
     */
    function onBack() as Boolean {
        var app = getApp();
        var timerRunning = (app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) && !app.isPaused;
        
        if (timerRunning) {
            openMenu(MenuContext.CONTEXT_BACK_DURING_TIMER);
        } else {
            openMenu(MenuContext.CONTEXT_BACK);
        }
        return true;
    }

    /**
     * Opens the appropriate menu based on context.
     * Consolidates all menu variations into a single, unified system.
     */
    private function openMenu(context as Number) as Void {
        var menu = new WatchUi.Menu();
        var app = getApp();
        var menuBuilder = new MenuBuilder();

        if (context == MenuContext.CONTEXT_BACK_DURING_TIMER) {
            // Timer actively running: User must pause before exiting
            menuBuilder.setTitle("Pause to Exit");
            menuBuilder.addItem("Pause", :pause);
            menuBuilder.addItem("Reset", :reset);
            menuBuilder.addItem("Settings", :settings);
        } else if (context == MenuContext.CONTEXT_BACK) {
            // BACK button: Exit is first (pre-selected)
            menuBuilder.setTitle("Menu");
            menuBuilder.addExitItem();
            menuBuilder.addConditionalItems(app);
            menuBuilder.addSettingsItem();
        } else {
            // SELECT button: Exit is last (if shown)
            menuBuilder.setTitle("Menu");
            menuBuilder.addConditionalItems(app);
            menuBuilder.addSettingsItem();
            menuBuilder.addExitItem();
        }

        // Build the menu and push it onto the view stack
        menu = menuBuilder.build();
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
         menu.addItem("Display Seconds", :display_seconds);
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
                    app.beginFocusSession();
                }
                break;

            case :start_break:
                if (app.state == app.STATE_BREAK_PROMPT) {
                    app.beginBreakSession();
                }
                break;

            case :pause:
                if ((app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) && !app.isPaused) {
                    app.pauseActiveTimer();
                }
                break;

            case :resume:
                if ((app.state == app.STATE_FOCUSING || app.state == app.STATE_BREAK) && app.isPaused) {
                    app.resumeActiveTimer();
                }
                break;

            case :reset:
                app.resetToReady();
                break;

            case :skip_break:
                if (app.state == app.STATE_BREAK_PROMPT || app.state == app.STATE_BREAK) {
                    app.skipBreak();
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
                    [5, 10, 15, 20, 25, 30, 40, 45, 50, 60], ["5m", "10m", "15m", "20m", "25m", "30m", "40m", "45m", "50m", "60m"]);
                break;
            case :short_break:
                openOptionSettingMenu("Short Break", "BreakShortMinutes", 
                    [1, 3, 5, 7, 10], ["1m", "3m", "5m", "7m", "10m"]);
                break;
            case :long_break:
                openOptionSettingMenu("Long Break", "BreakLongMinutes", 
                    [5, 8, 10, 15, 20], ["5m", "8m", "10m", "15m", "20m"]);
                break;
            case :extra_long_break:
                openOptionSettingMenu("Extra Long Break", "BreakExtraLongMinutes", 
                    [10, 15, 20, 30, 45, 60], ["10m", "15m", "20m", "30m", "45m", "60m"]);
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
            case :display_seconds:
                openDisplaySecondsMenu();
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

    private function openDisplaySecondsMenu() as Void {
        var currentVal = Application.Properties.getValue("DisplaySeconds") as Boolean;
        var menu = new WatchUi.Menu();
        menu.setTitle("Display Seconds: " + (currentVal ? "On" : "Off"));

        menu.addItem("On", :display_seconds_on);
        menu.addItem("Off", :display_seconds_off);
        menu.addItem("Back", :back);

        WatchUi.pushView(menu, new DisplaySecondsSettingDelegate(), WatchUi.SLIDE_UP);
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

class DisplaySecondsSettingDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        var value = false;

        if (item == :display_seconds_on) {
            value = true;
        } else if (item == :display_seconds_off) {
            value = false;
        } else if (item == :back) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return;
        }

        Application.Properties.setValue("DisplaySeconds", value);
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
