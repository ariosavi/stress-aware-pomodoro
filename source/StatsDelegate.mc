import Toybox.Lang;
import Toybox.WatchUi;

class StatsDelegate extends WatchUi.BehaviorDelegate {
    private var view as StatsView;

    function initialize(statsView as StatsView) {
        BehaviorDelegate.initialize();
        view = statsView;
    }

    function onUp() as Boolean {
        view.prevPage();
        return true;
    }

    function onDown() as Boolean {
        view.nextPage();
        return true;
    }

    function onSwipeUp() as Boolean {
        view.nextPage();
        return true;
    }

    function onSwipeDown() as Boolean {
        view.prevPage();
        return true;
    }

    function onBack() as Boolean {
        // Normal back behavior - always exit stats view
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Boolean {
        view.nextPage();
        return true;
    }
}
