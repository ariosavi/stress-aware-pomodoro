import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Math;

// ─────────────────────────────────────────────────────────────
//  StatsView  –  5-page statistics screen
//
//  All layout is computed from dc.getWidth() / dc.getHeight()
//  so it adapts to any round Garmin display size.
// ─────────────────────────────────────────────────────────────
class StatsView extends WatchUi.View {

    private var currentPage as Number = 0;
    private const TOTAL_PAGES = 5;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        WatchUi.requestUpdate();
    }

    function onHide() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        switch (currentPage) {
            case 0: drawPageSummary(dc);      break;
            case 1: drawPageStressChart(dc);  break;
            case 2: drawPageHRChart(dc);      break;
            case 3: drawPageBodyBattery(dc);  break;
            case 4: drawPageAllTimeStats(dc); break;
        }

        drawPageIndicator(dc);
    }

    // ── Page-indicator dots at very bottom ───────────────────
    private function drawPageIndicator(dc as Dc) as Void {
        var w      = dc.getWidth();
        var h      = dc.getHeight();
        var gap    = 14;
        var r      = 3;
        var total  = (TOTAL_PAGES - 1) * gap;
        var startX = (w - total) / 2;
        var dotY   = h - 10;

        for (var i = 0; i < TOTAL_PAGES; i++) {
            var dx = startX + i * gap;
            if (i == currentPage) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dx, dotY, r);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dx, dotY, r);
            }
        }
    }

    // ── Shared title ─────────────────────────────────────────
    // Title is drawn in the top 12% of the screen, with a
    // divider line below it.  Returns Y where content starts.
    private function drawTitle(dc as Dc, title as String) as Number {
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;

        // Title centred at 5% from top
        var titleY = (h * 0.05).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, titleY, Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_CENTER);

        // Measure FONT_XTINY height (~20px on most devices) and add safe gap
        var fontH = dc.getFontHeight(Graphics.FONT_XTINY);
        var divY  = titleY + fontH + 6;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(20, divY, w - 20, divY);

        // Content starts 8px below divider
        return divY + 8;
    }

    private function drawNoData(dc as Dc, contentY as Number, msg as String) as Void {
        var w  = dc.getWidth();
        var cx = w / 2;
        var h  = dc.getHeight();
        var cy = contentY + (h - contentY - 30) / 2 - 20;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy,      Graphics.FONT_XTINY, msg,                Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, cy + 22, Graphics.FONT_XTINY, "Complete sessions", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, cy + 44, Graphics.FONT_XTINY, "to see history",    Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawSep(dc as Dc, y as Number, w as Number) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(20, y, w - 20, y);
    }

    // ── Today filter ─────────────────────────────────────────
    private function getTodaysSessions(history as Array) as Array {
        var result = [];
        var today  = Gregorian.info(Toybox.Time.now(), Time.FORMAT_SHORT);
        for (var i = 0; i < history.size(); i++) {
            var s  = history[i] as Dictionary;
            var ts = s.get("timestamp");
            if (ts == null) { continue; }
            var t = Gregorian.info(new Toybox.Time.Moment(ts as Number), Time.FORMAT_SHORT);
            if (t.year == today.year && t.month == today.month && t.day == today.day) {
                result.add(s);
            }
        }
        return result;
    }

    private function getLastNSessions(history as Array, n as Number) as Array {
        var result   = [];
        var startIdx = history.size() >= n ? history.size() - n : 0;
        for (var i = startIdx; i < history.size(); i++) {
            result.add(history[i]);
        }
        return result;
    }

    // ── Generic bar chart ────────────────────────────────────
    // Draws a bar chart filling the available vertical space.
    //
    // dc           – drawing context
    // values[]     – array of Number or null (one per bar)
    // maxVal       – value that corresponds to full bar height
    // colors[]     – per-bar colour (null entries use defColor)
    // defColor     – fallback bar colour
    // yTop         – top of the chart area (from drawTitle return)
    // yBottom      – bottom of the chart area (before value labels)
    // yAxisTopLbl  – string label for the top of the Y axis
    // yAxisBotLbl  – string label for the bottom of the Y axis
    // realValues[] – if not null, shown as the value label instead of values[]
    private function drawBarChart(dc       as Dc,
                                  values   as Array,
                                  maxVal   as Number,
                                  colors   as Array or Null,
                                  defColor as Number,
                                  yTop     as Number,
                                  yBottom  as Number,
                                  yAxisTopLbl as String,
                                  yAxisBotLbl as String,
                                  realValues  as Array or Null) as Void {

        var w       = dc.getWidth();
        var count   = values.size();
        if (count == 0) { return; }

        // Left margin leaves room for Y-axis label, right margin small
        var leftM   = 28;
        var rightM  = 10;
        var chartL  = leftM;
        var chartR  = w - rightM;
        var chartH  = yBottom - yTop;

        // Y-axis border lines
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(chartL, yTop,    chartR, yTop);
        dc.drawLine(chartL, yBottom, chartR, yBottom);

        // Y-axis labels
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(chartL - 2, yTop - 1,       Graphics.FONT_XTINY, yAxisTopLbl, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(chartL - 2, yBottom - 10,   Graphics.FONT_XTINY, yAxisBotLbl, Graphics.TEXT_JUSTIFY_RIGHT);

        // Fixed bar geometry – bars are always the same width regardless of count
        var BAR_W   = 22;   // fixed bar width in pixels
        var BAR_GAP = 25;    // gap between bars
        var slotW   = BAR_W + BAR_GAP;
        var totalBarsW = count * slotW - BAR_GAP;
        // Centre the bar group within the chart area
        var chartW  = chartR - chartL;
        var groupStartX = chartL + (chartW - totalBarsW) / 2;
        if (groupStartX < chartL) { groupStartX = chartL; }

        // Value label row sits just below the chart
        var labelY = yBottom + 5;

        for (var i = 0; i < count; i++) {
            var val  = values[i];
            var barX = groupStartX + i * slotW;
            var barW = BAR_W;

            // Compute bar height
            var barH = 2;
            if (val != null) {
                var v = val as Number;
                if (v > 0) {
                    barH = (v.toFloat() / maxVal * chartH).toNumber();
                    if (barH > chartH) { barH = chartH; }
                    if (barH < 2)      { barH = 2; }
                }
            }
            var barY = yBottom - barH;

            // Colour
            var col = defColor;
            if (val == null) {
                col = Graphics.COLOR_DK_GRAY;
            } else if (colors != null && i < colors.size() && colors[i] != null) {
                col = colors[i] as Number;
            }

            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, barW, barH);

            // Value label
            var lx  = barX + barW / 2;
            var lbl = "";
            if (realValues != null && i < realValues.size()) {
                var rv = realValues[i];
                lbl = rv != null ? (rv as Number).toString() : "-";
            } else {
                lbl = val != null ? (val as Number).toString() : "-";
            }
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lx, labelY, Graphics.FONT_XTINY, lbl, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── PAGE 0 – Today's Summary ──────────────────────────────
    private function drawPageSummary(dc as Dc) as Void {
        var w   = dc.getWidth();
        var cx  = w / 2;
        var y   = drawTitle(dc, "Today's Stats");

        var history       = PomoState.getSessionHistory();
        var todaySessions = getTodaysSessions(history);
        var count         = todaySessions.size();

        if (count == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + 50, Graphics.FONT_XTINY, "No sessions today", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Big session count centred in upper portion
        var bigY = y + 8;
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, bigY, Graphics.FONT_LARGE, count.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        var afterBig = bigY + 50;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, afterBig, Graphics.FONT_XTINY, "Sessions Today", Graphics.TEXT_JUSTIFY_CENTER);

        var sepY = afterBig + 50;
        drawSep(dc, sepY, w);
        var infoY = sepY + 12;

        // Accumulate
        var focusMins = 0;
        var totStress = 0;
        var totHR     = 0;
        var stressCnt = 0;
        var hrCnt     = 0;

        for (var i = 0; i < count; i++) {
            var s = todaySessions[i] as Dictionary;
            var d = s.get("duration");
            if (d != null) { focusMins += d as Number; }
            var sv = s.get("stress");
            if (sv != null) { totStress += sv as Number; stressCnt++; }
            var hv = s.get("hr");
            if (hv != null) { totHR += hv as Number; hrCnt++; }
        }

        var fh    = focusMins / 60;
        var fm    = focusMins % 60;
        var lineH = 40;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, infoY, Graphics.FONT_XTINY,
                    "Focus: " + fh + "h " + fm + "m", Graphics.TEXT_JUSTIFY_CENTER);
        infoY += lineH;

        if (stressCnt > 0) {
            var avg = Math.round(totStress.toFloat() / stressCnt).toNumber();
            var col = avg < 30 ? Graphics.COLOR_GREEN
                    : avg < 60 ? Graphics.COLOR_YELLOW
                    : Graphics.COLOR_RED;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, infoY, Graphics.FONT_XTINY,
                        "Avg Stress: " + avg, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, infoY, Graphics.FONT_XTINY, "Stress: no data", Graphics.TEXT_JUSTIFY_CENTER);
        }
        infoY += lineH;

        if (hrCnt > 0) {
            var avg = Math.round(totHR.toFloat() / hrCnt).toNumber();
            dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, infoY, Graphics.FONT_XTINY,
                        "Avg HR: " + avg + " bpm", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, infoY, Graphics.FONT_XTINY, "HR: no data", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── PAGE 1 – Stress Chart ─────────────────────────────────
    private function drawPageStressChart(dc as Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();

        var contentY = drawTitle(dc, "Stress History");

        var history  = PomoState.getSessionHistory();
        var sessions = getLastNSessions(history, 6);

        if (sessions.size() == 0) {
            drawNoData(dc, contentY, "No stress data yet");
            return;
        }

        var threshold = Application.Properties.getValue("StressThreshold") as Number;

        // Reserve space: fontH for value labels + 20px for page dots
        var fontH    = dc.getFontHeight(Graphics.FONT_XTINY);
        var chartTop = contentY + 4;
        var chartBot = h - fontH - 60;

        var values = [] as Array;
        var colors = [] as Array;

        for (var i = 0; i < sessions.size(); i++) {
            var sv = (sessions[i] as Dictionary).get("stress");
            values.add(sv);
            var col = Graphics.COLOR_GREEN;
            if (sv != null) {
                var v = sv as Number;
                if (v >= threshold) { col = Graphics.COLOR_RED; }
                else if (v >= 60)   { col = Graphics.COLOR_YELLOW; }
            }
            colors.add(col);
        }

        drawBarChart(dc, values, 100, colors, Graphics.COLOR_GREEN,
                     chartTop, chartBot, "100", "0", null);

        // Threshold line
        var chartH = chartBot - chartTop;
        var tY     = chartBot - (threshold * chartH / 100);
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(28, tY, w - 10, tY);
        // threshold label right-aligned at end of line
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 10, tY - 30, Graphics.FONT_XTINY,
                    "" + threshold, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ── PAGE 2 – Heart Rate Chart ─────────────────────────────
    private function drawPageHRChart(dc as Dc) as Void {
        var h  = dc.getHeight();

        var contentY = drawTitle(dc, "Heart Rate");

        var history  = PomoState.getSessionHistory();
        var sessions = getLastNSessions(history, 6);

        if (sessions.size() == 0) {
            drawNoData(dc, contentY, "No HR data yet");
            return;
        }

        // Find actual min/max HR
        var minHR = 999;
        var maxHR = 0;
        for (var i = 0; i < sessions.size(); i++) {
            var hv = (sessions[i] as Dictionary).get("hr");
            if (hv != null) {
                var v = hv as Number;
                if (v < minHR) { minHR = v; }
                if (v > maxHR) { maxHR = v; }
            }
        }
        if (minHR == 999) { minHR = 50; }
        if (maxHR == 0)   { maxHR = 120; }

        var pad   = 8;
        minHR     = minHR - pad;
        maxHR     = maxHR + pad;
        if (minHR < 0) { minHR = 0; }
        var range = maxHR - minHR;
        if (range == 0) { range = 1; }

        var fontH2   = dc.getFontHeight(Graphics.FONT_XTINY);
        var chartTop = contentY + 4;
        var chartBot = h - fontH2 - 60;

        // Normalise to 0-100 for the shared chart function,
        // but pass real BPM values as the label array
        var normValues = [] as Array;
        var realValues = [] as Array;

        for (var i = 0; i < sessions.size(); i++) {
            var hv = (sessions[i] as Dictionary).get("hr");
            if (hv != null) {
                var v   = hv as Number;
                var pct = Math.round(((v - minHR).toFloat() / range) * 100).toNumber();
                if (pct < 0)   { pct = 0; }
                if (pct > 100) { pct = 100; }
                normValues.add(pct);
                realValues.add(v);
            } else {
                normValues.add(null);
                realValues.add(null);
            }
        }

        drawBarChart(dc, normValues, 100, null, Graphics.COLOR_DK_RED,
                     chartTop, chartBot,
                     maxHR.toString(), minHR.toString(),
                     realValues);
    }

    // ── PAGE 3 – Body Battery ─────────────────────────────────
    // Bar = body-battery level AT SESSION START (0-100).
    // A small +/- delta is drawn above each bar.
    private function drawPageBodyBattery(dc as Dc) as Void {
        var w  = dc.getWidth();
        var h  = dc.getHeight();

        var contentY = drawTitle(dc, "Body Battery");

        var history  = PomoState.getSessionHistory();
        var sessions = getLastNSessions(history, 6);

        if (sessions.size() == 0) {
            drawNoData(dc, contentY, "No battery data yet");
            return;
        }

        var startValues = [] as Array;
        var changes     = [] as Array;
        var colors      = [] as Array;
        var hasAny      = false;

        for (var i = 0; i < sessions.size(); i++) {
            var s   = sessions[i] as Dictionary;
            var bsr = s.get("batteryStart");
            var ber = s.get("batteryEnd");

            if (bsr != null) {
                var bs  = Math.round((bsr as Float).toFloat()).toNumber();
                startValues.add(bs);
                hasAny = true;

                // delta
                if (ber != null) {
                    var be = Math.round((ber as Float).toFloat()).toNumber();
                    changes.add(be - bs);
                } else {
                    changes.add(null);
                }

                // colour by start level
                var col = bs >= 50 ? Graphics.COLOR_GREEN
                        : bs >= 25 ? Graphics.COLOR_YELLOW
                        : Graphics.COLOR_RED;
                colors.add(col);
            } else {
                startValues.add(null);
                changes.add(null);
                colors.add(null);
            }
        }

        if (!hasAny) {
            drawNoData(dc, contentY, "No battery data yet");
            return;
        }

        var fontH3   = dc.getFontHeight(Graphics.FONT_XTINY);
        var chartTop = contentY + 4;
        var chartBot = h - fontH3 - 60;
        var chartH   = chartBot - chartTop;

        drawBarChart(dc, startValues, 100, colors, Graphics.COLOR_GREEN,
                     chartTop, chartBot, "100", "0", null);

        // Draw delta above each bar – use same fixed geometry as drawBarChart
        var count   = startValues.size();
        var BAR_W   = 22;
        var BAR_GAP = 25;
        var slotW   = BAR_W + BAR_GAP;
        var chartL  = 28;
        var chartR  = w - 10;
        var chartWW = chartR - chartL;
        var groupStartX = chartL + (chartWW - (count * slotW - BAR_GAP)) / 2;
        if (groupStartX < chartL) { groupStartX = chartL; }

        for (var i = 0; i < count; i++) {
            var sv = startValues[i];
            var ch = changes[i];
            if (sv == null || ch == null) { continue; }

            var startV = sv as Number;
            var chV    = ch as Number;

            var barH = (startV.toFloat() / 100.0 * chartH).toNumber();
            if (barH < 2)      { barH = 2; }
            if (barH > chartH) { barH = chartH; }

            var barY   = chartBot - barH;
            var lx     = groupStartX + i * slotW + BAR_W / 2;
            var deltaY = barY - 30;
            if (deltaY < chartTop + 2) { deltaY = chartTop + 2; }

            var deltaStr = chV > 0 ? "+" + chV : chV.toString();
            var deltaCol = chV >= 0 ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
            dc.setColor(deltaCol, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lx, deltaY, Graphics.FONT_XTINY, deltaStr, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── PAGE 4 – All-Time Stats ───────────────────────────────
    private function drawPageAllTimeStats(dc as Dc) as Void {
        var w  = dc.getWidth();
        var cx = w / 2;

        var y = drawTitle(dc, "All-Time Stats");

        var history       = PomoState.getSessionHistory();
        var totalSessions = history.size();
        var totalMins     = 0;
        var bestStress    = 101;
        var worstStress   = -1;
        var bestHR        = 9999;
        var worstHR       = -1;
        var stressCnt     = 0;
        var hrCnt         = 0;

        for (var i = 0; i < history.size(); i++) {
            var s  = history[i] as Dictionary;
            var d  = s.get("duration");
            if (d != null) { totalMins += d as Number; }
            var sv = s.get("stress");
            if (sv != null) {
                var v = sv as Number;
                stressCnt++;
                if (v < bestStress)  { bestStress  = v; }
                if (v > worstStress) { worstStress = v; }
            }
            var hv = s.get("hr");
            if (hv != null) {
                var v = hv as Number;
                hrCnt++;
                if (v < bestHR)  { bestHR  = v; }
                if (v > worstHR) { worstHR = v; }
            }
        }

        var tH = totalMins / 60;
        var tM = totalMins % 60;

        var nowEpoch = Toybox.Time.now().value();
        var weekAgo  = nowEpoch - 7 * 24 * 60 * 60;
        var weekCnt  = 0;
        for (var i = 0; i < history.size(); i++) {
            var ts = (history[i] as Dictionary).get("timestamp");
            if (ts != null && (ts as Number) >= weekAgo) { weekCnt++; }
        }

        var lineH = 40;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY,
                    "Sessions: " + totalSessions, Graphics.TEXT_JUSTIFY_CENTER);
        y += lineH;
        dc.drawText(cx, y, Graphics.FONT_XTINY,
                    "Total Focus: " + tH + "h " + tM + "m", Graphics.TEXT_JUSTIFY_CENTER);
        y += lineH;
        dc.drawText(cx, y, Graphics.FONT_XTINY,
                    "This Week: " + weekCnt, Graphics.TEXT_JUSTIFY_CENTER);
        y += lineH;

        drawSep(dc, y, w);
        y += 12;

        if (stressCnt > 0) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY,
                        "Best Stress: " + bestStress, Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY,
                        "Worst Stress: " + worstStress, Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY, "Stress: no data", Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
        }

        drawSep(dc, y, w);
        y += 12;

        if (hrCnt > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY,
                        "Best HR: " + bestHR + " bpm", Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
            dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY,
                        "Worst HR: " + worstHR + " bpm", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY, "HR: no data", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── Navigation ────────────────────────────────────────────
    public function nextPage() as Void {
        currentPage = (currentPage + 1) % TOTAL_PAGES;
        WatchUi.requestUpdate();
    }

    public function prevPage() as Void {
        currentPage = currentPage > 0 ? currentPage - 1 : TOTAL_PAGES - 1;
        WatchUi.requestUpdate();
    }
}
