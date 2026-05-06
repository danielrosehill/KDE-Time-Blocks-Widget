import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "../code/Hebcal.js" as Hebcal

PlasmoidItem {
    id: root

    readonly property bool labelsBelow: Plasmoid.configuration.labelPosition === "below"
    readonly property bool isDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
    property var nowLocal: new Date()
    property var nowUtc: new Date()
    property string hebrewDateStr: ""
    property var hebrewParts: ({ hd: "", hm: "", hy: "" })
    property string lastHebrewKey: ""

    function activeDate() {
        return Plasmoid.configuration.dateBoxUseUtc ? nowUtc : nowLocal;
    }
    function activeUtc() {
        return Plasmoid.configuration.dateBoxUseUtc;
    }
    function monthName(d, utc, useLong) {
        const mo = utc ? d.getUTCMonth() : d.getMonth();
        const shortN = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][mo];
        const longN = ["January","February","March","April","May","June","July","August","September","October","November","December"][mo];
        return useLong ? longN : shortN;
    }
    function dayOfMonth(d, utc) {
        return (utc ? d.getUTCDate() : d.getDate()).toString();
    }
    function parseExtraTimezones() {
        try {
            const a = JSON.parse(Plasmoid.configuration.extraTimezones || "[]");
            return Array.isArray(a) ? a : [];
        } catch (e) { return []; }
    }
    function findExtraTz(idOrKind) {
        const id = idOrKind.indexOf("tz:") === 0 ? idOrKind.substring(3) : idOrKind;
        const list = parseExtraTimezones();
        for (const e of list) if (e.id === id) return e;
        return null;
    }
    function fmtTimeInTz(d, tzid) {
        try {
            const opts = {
                timeZone: tzid,
                hour12: !Plasmoid.configuration.use24Hour,
                hour: "2-digit",
                minute: "2-digit"
            };
            if (Plasmoid.configuration.showSeconds) opts.second = "2-digit";
            return new Intl.DateTimeFormat("en-GB", opts).format(d);
        } catch (e) {
            return "?";
        }
    }
    function parseCardOrder() {
        return (Plasmoid.configuration.cardOrder || "").split(",")
            .map(s => s.trim()).filter(s => s.length);
    }
    function parsePanelCardOrder() {
        return (Plasmoid.configuration.panelCardOrder || "").split(",")
            .map(s => s.trim()).filter(s => s.length);
    }
    function needsHebrew() {
        if (Plasmoid.configuration.showHebrewDate) return true;
        const all = parseCardOrder().concat(parsePanelCardOrder());
        for (const k of all) if (k.indexOf("hebrew") === 0) return true;
        return false;
    }

    function _civilKey(d) {
        return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
    }
    function _hebrewLocationReady() {
        return Plasmoid.configuration.hebrewLocationSet
            && (Plasmoid.configuration.hebrewLatitude !== 0.0 || Plasmoid.configuration.hebrewLongitude !== 0.0);
    }
    function _sunsetEnabled() {
        return Plasmoid.configuration.hebrewRolloverMode === "sunset" && _hebrewLocationReady();
    }

    // Resolve the civil date that determines today's Hebrew date (post-sunset → next civil day).
    function _resolveActiveCivilDate(now, cb) {
        if (!_sunsetEnabled()) { cb(new Date(now)); return; }
        const lat = Plasmoid.configuration.hebrewLatitude;
        const lon = Plasmoid.configuration.hebrewLongitude;
        const tzid = Plasmoid.configuration.hebrewTzid;
        Hebcal.fetchSunset(now, lat, lon, tzid, function (ok, sunset, err) {
            if (!ok || !sunset) { cb(new Date(now)); return; }
            if (now.getTime() >= sunset.getTime()) {
                const next = new Date(now);
                next.setDate(next.getDate() + 1);
                cb(next);
            } else {
                cb(new Date(now));
            }
        });
    }

    function _scheduleNextHebrewFlip() {
        const now = new Date();
        if (_sunsetEnabled()) {
            const lat = Plasmoid.configuration.hebrewLatitude;
            const lon = Plasmoid.configuration.hebrewLongitude;
            const tzid = Plasmoid.configuration.hebrewTzid;
            // If today's sunset is still ahead, wait for it; otherwise wait for tomorrow's.
            Hebcal.fetchSunset(now, lat, lon, tzid, function (ok, sunset, err) {
                if (ok && sunset && sunset.getTime() > now.getTime()) {
                    flipTimer.interval = sunset.getTime() - now.getTime() + 1000;
                    flipTimer.restart();
                    return;
                }
                const tomorrow = new Date(now);
                tomorrow.setDate(tomorrow.getDate() + 1);
                Hebcal.fetchSunset(tomorrow, lat, lon, tzid, function (ok2, ss2) {
                    if (ok2 && ss2 && ss2.getTime() > now.getTime()) {
                        flipTimer.interval = ss2.getTime() - now.getTime() + 1000;
                        flipTimer.restart();
                    } else {
                        // Fallback: try again in 6h
                        flipTimer.interval = 6 * 60 * 60 * 1000;
                        flipTimer.restart();
                    }
                });
            });
        } else {
            // Civil midnight tomorrow + 5s safety margin
            const next = new Date(now);
            next.setDate(next.getDate() + 1);
            next.setHours(0, 0, 5, 0);
            flipTimer.interval = Math.max(60 * 1000, next.getTime() - now.getTime());
            flipTimer.restart();
        }
    }

    function refreshHebrewDate() {
        if (!needsHebrew()) { hebrewDateStr = ""; lastHebrewKey = ""; return; }
        _resolveActiveCivilDate(new Date(), function (civilDay) {
            const key = _civilKey(civilDay);
            if (key === lastHebrewKey && hebrewParts.hd) {
                hebrewDateStr = Hebcal.format(hebrewParts, Plasmoid.configuration.hebrewDateWithYear, Plasmoid.configuration.hebrewMonthFirst);
                _scheduleNextHebrewFlip();
                return;
            }
            Hebcal.fetchHebrewDate(civilDay, function (ok, h, err) {
                if (ok) {
                    hebrewParts = h;
                    hebrewDateStr = Hebcal.format(h, Plasmoid.configuration.hebrewDateWithYear, Plasmoid.configuration.hebrewMonthFirst);
                    lastHebrewKey = key;
                }
                _scheduleNextHebrewFlip();
            });
        });
    }

    Component.onCompleted: refreshHebrewDate()
    Connections {
        target: Plasmoid.configuration
        function onShowHebrewDateChanged() { root.refreshHebrewDate(); }
        function onHebrewEnabledChanged() { root.refreshHebrewDate(); }
        function onHebrewDateWithYearChanged() {
            root.hebrewDateStr = Hebcal.format(root.hebrewParts, Plasmoid.configuration.hebrewDateWithYear, Plasmoid.configuration.hebrewMonthFirst);
            root.refreshHebrewDate();
        }
        function onHebrewMonthFirstChanged() {
            root.hebrewDateStr = Hebcal.format(root.hebrewParts, Plasmoid.configuration.hebrewDateWithYear, Plasmoid.configuration.hebrewMonthFirst);
        }
        function onHebrewRolloverModeChanged() { root.refreshHebrewDate(); }
        function onHebrewLocationSetChanged() { root.refreshHebrewDate(); }
        function onHebrewLatitudeChanged() { root.refreshHebrewDate(); }
        function onHebrewLongitudeChanged() { root.refreshHebrewDate(); }
        function onHebrewTzidChanged() { root.refreshHebrewDate(); }
        function onCardOrderChanged() { root.refreshHebrewDate(); }
    }
    Timer {
        id: flipTimer
        repeat: false
        running: false
        onTriggered: root.refreshHebrewDate()
    }

    readonly property string fontFamily: "Inter, Inter Display, system-ui, sans-serif"

    function paletteFor(name) {
        switch (name) {
        case "light":
            return { bg: "#E8E4DC", card: "#FFFFFF", text: "#1A1A1A", label: "#6B6B6B", divider: "#D0CCC4" };
        case "dark":
            return { bg: "#1C1C20", card: "#28282E", text: "#F5F5F5", label: "#9CA0A8", divider: "#3A3A42" };
        case "slate":
            return { bg: "#1E2935", card: "#2D3B4D", text: "#E8EEF5", label: "#94A3B8", divider: "#3D4F66" };
        case "warm":
            return { bg: "#3A2820", card: "#E8C9A8", text: "#2A1410", label: "#7A4F38", divider: "#C9A48B" };
        case "midnight":
            return { bg: "#0B1426", card: "#1A2540", text: "#E2E8F0", label: "#7DD3FC", divider: "#334155" };
        default:
            return null;
        }
    }

    readonly property var palette: {
        const p = paletteFor(Plasmoid.configuration.desktopPalette);
        if (p) return p;
        return {
            bg: Kirigami.Theme.backgroundColor,
            card: Qt.lighter(Kirigami.Theme.backgroundColor, 1.15),
            text: Kirigami.Theme.textColor,
            label: Qt.darker(Kirigami.Theme.textColor, 1.4),
            divider: Qt.darker(Kirigami.Theme.textColor, 1.6)
        };
    }

    function fmtTime(d, utc) {
        const pad = n => n.toString().padStart(2, "0");
        let h = utc ? d.getUTCHours() : d.getHours();
        const m = utc ? d.getUTCMinutes() : d.getMinutes();
        const s = utc ? d.getUTCSeconds() : d.getSeconds();
        let suffix = "";
        if (!Plasmoid.configuration.use24Hour) {
            suffix = h >= 12 ? " PM" : " AM";
            h = h % 12; if (h === 0) h = 12;
        }
        let str = pad(h) + ":" + pad(m);
        if (Plasmoid.configuration.showSeconds) str += ":" + pad(s);
        return str + suffix;
    }

    function localTzAbbrev() {
        try {
            const parts = new Intl.DateTimeFormat(undefined, { timeZoneName: "short" }).formatToParts(nowLocal);
            const tz = parts.find(p => p.type === "timeZoneName");
            if (tz && tz.value && !/^GMT/i.test(tz.value)) return tz.value;
        } catch (e) {}
        return utcOffsetString();
    }

    function utcOffsetString() {
        const off = -nowLocal.getTimezoneOffset();
        const sign = off >= 0 ? "+" : "-";
        const a = Math.abs(off);
        const h = Math.floor(a / 60);
        const m = a % 60;
        return "UTC" + sign + h + (m ? ":" + m.toString().padStart(2, "0") : "");
    }

    function dateBoxWeekday(d, utc) {
        const wd = utc ? d.getUTCDay() : d.getDay();
        return ["Sun","Mon","Tues","Wed","Thurs","Fri","Sat"][wd];
    }

    function dateBoxMonthDay(d, utc) {
        const mo = utc ? d.getUTCMonth() : d.getMonth();
        const day = utc ? d.getUTCDate() : d.getDate();
        return ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][mo] + " " + day;
    }

    // Date line for the combined date card: respects gregorianDateFormat.
    function dateBoxDateLine(d, utc) {
        const fmt = Plasmoid.configuration.gregorianDateFormat;
        const day = (utc ? d.getUTCDate() : d.getDate()).toString();
        if (fmt === "day") return day;
        const mo = monthName(d, utc, Plasmoid.configuration.monthLong);
        if (fmt === "day-month") return day + " " + mo;
        return mo + " " + day; // month-day (legacy)
    }

    // Resolve a configured time-color preset to an actual color, given a
    // fallback (theme/palette default). "muted" darkens the fallback.
    function resolveTimeColor(name, fallback, customHex) {
        switch (name) {
            case "white":  return "#FFFFFF";
            case "yellow": return "#F2C94C";
            case "muted":  return Qt.rgba(fallback.r, fallback.g, fallback.b, 0.85);
            case "custom": return (customHex && customHex.length > 0) ? customHex : fallback;
            case "default":
            default:       return fallback;
        }
    }
    function timeColorFor(kind, fallback) {
        if (kind === "local-time") return resolveTimeColor(Plasmoid.configuration.localTimeColor, fallback, Plasmoid.configuration.localTimeCustomColor);
        if (kind === "utc-time")   return resolveTimeColor(Plasmoid.configuration.utcTimeColor, fallback, Plasmoid.configuration.utcTimeCustomColor);
        return fallback;
    }

    Timer {
        interval: Plasmoid.configuration.showSeconds ? 500 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const d = new Date();
            root.nowLocal = d;
            root.nowUtc = d;
        }
    }

    preferredRepresentation: fullRepresentation

    fullRepresentation: Loader {
        Layout.minimumWidth: item ? item.Layout.minimumWidth : 100
        Layout.minimumHeight: item ? item.Layout.minimumHeight : 40
        Layout.preferredWidth: item ? item.Layout.preferredWidth : 200
        Layout.preferredHeight: item ? item.Layout.preferredHeight : 60
        sourceComponent: root.isDesktop ? desktopView : panelView
    }

    // ---------- PANEL VIEW (compact, theme colors, driven by panelCardOrder) ----------
    Component {
        id: panelView

        Item {
            id: panelItem
            readonly property int fsTime: Kirigami.Theme.defaultFont.pixelSize + 2
            readonly property int fsLabel: Math.max(8, fsTime - 4)
            readonly property color tColor: Kirigami.Theme.textColor
            readonly property color lColor: Qt.darker(tColor, 1.3)
            readonly property var blocks: root.parsePanelCardOrder()

            Layout.minimumWidth: content.implicitWidth + Kirigami.Units.smallSpacing * 2
            Layout.minimumHeight: content.implicitHeight + Kirigami.Units.smallSpacing
            Layout.preferredWidth: Layout.minimumWidth
            Layout.preferredHeight: Layout.minimumHeight

            ColumnLayout {
                id: content
                anchors.centerIn: parent
                spacing: 2

                RowLayout {
                    spacing: Plasmoid.configuration.spacing
                    Layout.alignment: Qt.AlignHCenter
                    layoutDirection: Plasmoid.configuration.localOnRight ? Qt.RightToLeft : Qt.LeftToRight

                    Repeater {
                        model: panelItem.blocks

                        delegate: RowLayout {
                            id: panelBlockRow
                            spacing: Plasmoid.configuration.spacing
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                visible: index > 0 && Plasmoid.configuration.showDivider
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                Layout.preferredHeight: panelItem.fsTime + 8
                                Layout.topMargin: 3
                                Layout.bottomMargin: 3
                                Layout.leftMargin: Math.floor(Plasmoid.configuration.spacing / 2)
                                Layout.rightMargin: Math.floor(Plasmoid.configuration.spacing / 2)
                                color: panelItem.lColor
                                opacity: 0.5
                            }

                            ColumnLayout {
                                id: panelBlock
                                spacing: 0
                                Layout.alignment: Qt.AlignVCenter

                                readonly property string kind: modelData
                            readonly property bool isCombinedDate: kind === "date-combined"
                            readonly property bool isExtraTz: kind.indexOf("tz:") === 0
                            readonly property bool isTimeBlock: kind === "local-time" || kind === "utc-time" || isExtraTz
                            readonly property bool isWeekdayDay: kind === "weekday-day"
                            readonly property bool isHebrewMulti:
                                   kind === "hebrew-day-month"
                                || kind === "hebrew-day-month-year"
                                || kind === "hebrew-month-day"
                                || kind === "hebrew-month-day-year"
                            readonly property bool weekdayTop: Plasmoid.configuration.dateBoxLayout !== "date-top"
                            readonly property bool singleLineDate: Plasmoid.configuration.gregorianDateStyle === "single-line"
                            readonly property var dbDate: Plasmoid.configuration.dateBoxUseUtc ? nowUtc : nowLocal
                            readonly property bool dbUtc: Plasmoid.configuration.dateBoxUseUtc

                            function primaryFor(k) {
                                const d = root.activeDate();
                                const utc = root.activeUtc();
                                if (k.indexOf("tz:") === 0) {
                                    const e = root.findExtraTz(k);
                                    return e ? fmtTimeInTz(nowLocal, e.tzid) : "?";
                                }
                                switch (k) {
                                    case "local-time": return fmtTime(nowLocal, false);
                                    case "utc-time": return fmtTime(nowUtc, true);
                                    case "weekday": return dateBoxWeekday(d, utc);
                                    case "gregorian-date":
                                        return monthName(d, utc, Plasmoid.configuration.monthLong) + " " + dayOfMonth(d, utc);
                                    case "month": return monthName(d, utc, Plasmoid.configuration.monthLong);
                                    case "day": return dayOfMonth(d, utc);
                                    case "hebrew-day": return root.hebrewParts.hd ? String(root.hebrewParts.hd) : "—";
                                    case "hebrew-month": return root.hebrewParts.hm || "…";
                                    case "hebrew-year": return root.hebrewParts.hy ? String(root.hebrewParts.hy) : "…";
                                    case "hebrew-day-month":
                                        return (root.hebrewParts.hd && root.hebrewParts.hm)
                                            ? (root.hebrewParts.hd + " " + root.hebrewParts.hm) : "…";
                                    case "hebrew-day-month-year":
                                        return (root.hebrewParts.hd && root.hebrewParts.hm && root.hebrewParts.hy)
                                            ? (root.hebrewParts.hd + " " + root.hebrewParts.hm + " " + root.hebrewParts.hy) : "…";
                                    case "hebrew-month-day":
                                        return (root.hebrewParts.hm && root.hebrewParts.hd)
                                            ? (root.hebrewParts.hm + " " + root.hebrewParts.hd) : "…";
                                    case "hebrew-month-day-year":
                                        return (root.hebrewParts.hm && root.hebrewParts.hd && root.hebrewParts.hy)
                                            ? (root.hebrewParts.hm + " " + root.hebrewParts.hd + " " + root.hebrewParts.hy) : "…";
                                    default: return "";
                                }
                            }
                            function labelFor(k) {
                                if (k === "local-time")
                                    return Plasmoid.configuration.autoLocalLabel ? localTzAbbrev() : Plasmoid.configuration.localLabel;
                                if (k === "utc-time") return Plasmoid.configuration.utcLabel;
                                if (k.indexOf("tz:") === 0) {
                                    const e = root.findExtraTz(k);
                                    return e ? e.label : "";
                                }
                                return "";
                            }

                            // Time block: big primary + label (inline or below)
                            RowLayout {
                                visible: panelBlock.isTimeBlock
                                spacing: 4
                                Layout.alignment: Qt.AlignHCenter
                                Text {
                                    text: panelBlock.primaryFor(panelBlock.kind)
                                    color: timeColorFor(panelBlock.kind, panelItem.tColor)
                                    font.family: root.fontFamily
                                    font.pixelSize: panelItem.fsTime
                                    font.bold: true
                                }
                                Text {
                                    visible: Plasmoid.configuration.showLabels && !labelsBelow
                                    text: panelBlock.labelFor(panelBlock.kind)
                                    color: panelItem.lColor
                                    font.family: root.fontFamily
                                    font.pixelSize: panelItem.fsLabel
                                }
                            }
                            Text {
                                visible: panelBlock.isTimeBlock && Plasmoid.configuration.showLabels && labelsBelow
                                Layout.alignment: Qt.AlignHCenter
                                text: {
                                    const lbl = panelBlock.labelFor(panelBlock.kind);
                                    if (panelBlock.kind === "local-time" && Plasmoid.configuration.showUtcOffset)
                                        return lbl + " (" + utcOffsetString() + ")";
                                    return lbl;
                                }
                                color: panelItem.lColor
                                font.family: root.fontFamily
                                font.pixelSize: panelItem.fsLabel
                            }

                            // Combined Gregorian date block: weekday + date stacked, plus optional Hebrew row
                            ColumnLayout {
                                visible: panelBlock.isCombinedDate
                                spacing: 0

                                readonly property string wd: dateBoxWeekday(panelBlock.dbDate, panelBlock.dbUtc)
                                readonly property string md: dateBoxDateLine(panelBlock.dbDate, panelBlock.dbUtc)

                                Text {
                                    visible: panelBlock.singleLineDate
                                    Layout.alignment: Qt.AlignHCenter
                                    text: parent.wd + " " + parent.md
                                    color: panelItem.tColor
                                    font.family: root.fontFamily
                                    font.pixelSize: panelItem.fsLabel
                                    font.bold: true
                                }
                                Text {
                                    visible: !panelBlock.singleLineDate
                                    Layout.alignment: Qt.AlignHCenter
                                    text: panelBlock.weekdayTop ? parent.wd : parent.md
                                    color: panelItem.tColor
                                    font.family: root.fontFamily
                                    font.pixelSize: panelItem.fsLabel
                                    font.bold: panelBlock.weekdayTop
                                }
                                Text {
                                    visible: !panelBlock.singleLineDate
                                    Layout.alignment: Qt.AlignHCenter
                                    text: panelBlock.weekdayTop ? parent.md : parent.wd
                                    color: panelItem.tColor
                                    font.family: root.fontFamily
                                    font.pixelSize: panelItem.fsLabel
                                    font.bold: !panelBlock.weekdayTop
                                }
                                Text {
                                    visible: Plasmoid.configuration.showHebrewDate && root.hebrewDateStr.length > 0
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.hebrewDateStr
                                    color: panelItem.lColor
                                    font.family: root.fontFamily
                                    font.pixelSize: panelItem.fsLabel
                                    font.weight: Font.Medium
                                }
                            }

                            // Multi-part Hebrew block: two stacked lines, date-sized, ordered per hebrewMonthFirst.
                            // Year (when present) is appended to the month line so we always render exactly two lines.
                            ColumnLayout {
                                visible: panelBlock.isHebrewMulti
                                spacing: 0

                                readonly property bool withYear: panelBlock.kind === "hebrew-day-month-year" || panelBlock.kind === "hebrew-month-day-year"
                                readonly property bool monthOnTop: Plasmoid.configuration.hebrewMonthFirst
                                readonly property string dayLine: root.hebrewParts.hd ? String(root.hebrewParts.hd) : "…"
                                readonly property string monthLine: {
                                    const m = root.hebrewParts.hm || "…";
                                    return withYear && root.hebrewParts.hy ? (m + " " + root.hebrewParts.hy) : m;
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: parent.monthOnTop ? parent.monthLine : parent.dayLine
                                    color: panelItem.tColor
                                    font.family: root.fontFamily
                                    font.pixelSize: panelItem.fsLabel
                                    font.bold: parent.monthOnTop
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: parent.monthOnTop ? parent.dayLine : parent.monthLine
                                    color: panelItem.tColor
                                    font.family: root.fontFamily
                                    font.pixelSize: panelItem.fsLabel
                                    font.bold: !parent.monthOnTop
                                }
                            }

                            // Weekday + day-of-month stacked (no month name)
                            ColumnLayout {
                                visible: panelBlock.isWeekdayDay
                                spacing: 0
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: dateBoxWeekday(panelBlock.dbDate, panelBlock.dbUtc)
                                    color: panelItem.tColor
                                    font.family: root.fontFamily
                                    font.pixelSize: panelItem.fsLabel
                                    font.bold: true
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: dayOfMonth(panelBlock.dbDate, panelBlock.dbUtc)
                                    color: panelItem.tColor
                                    font.family: root.fontFamily
                                    font.pixelSize: panelItem.fsLabel
                                    font.bold: true
                                }
                            }

                            // Single-value date kinds (weekday, gregorian-date, month, day, hebrew-day/month/year)
                            Text {
                                visible: !panelBlock.isTimeBlock && !panelBlock.isCombinedDate && !panelBlock.isHebrewMulti && !panelBlock.isWeekdayDay
                                Layout.alignment: Qt.AlignHCenter
                                text: panelBlock.primaryFor(panelBlock.kind)
                                color: panelItem.tColor
                                font.family: root.fontFamily
                                font.pixelSize: panelItem.fsLabel
                                font.bold: true
                            }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- DESKTOP VIEW (cards driven by cardOrder, autoscale) ----------
    Component {
        id: desktopView

        Item {
            id: deskItem
            readonly property var pal: root.palette
            readonly property bool useCards: Plasmoid.configuration.desktopCards
            readonly property bool vertical: Plasmoid.configuration.desktopOrientation === "vertical"
            readonly property var cards: root.parseCardOrder()
            readonly property int cardCount: Math.max(1, cards.length)

            readonly property int outerPad: Plasmoid.configuration.desktopShowContainer
                ? Math.max(5, Math.floor(Math.min(deskItem.width, deskItem.height) * 0.025))
                : 0
            readonly property int gap: Plasmoid.configuration.spacing > 0
                ? Plasmoid.configuration.spacing
                : Math.max(10, Math.floor(Math.min(deskItem.width, deskItem.height) * 0.05))

            readonly property real cardW: vertical
                ? deskItem.width - outerPad * 2
                : (deskItem.width - outerPad * 2 - gap * (cardCount - 1)) / cardCount
            readonly property real cardH: vertical
                ? (deskItem.height - outerPad * 2 - gap * (cardCount - 1)) / cardCount
                : deskItem.height - outerPad * 2

            // Primary text size — width-bound assumes ~5 chars; HorizontalFit
            // on each Text scales down for longer strings, so this is just the cap.
            readonly property int fsTime: Math.max(14, Math.floor(Math.min(
                cardW / 3.0,
                cardH * 0.46
            )))
            readonly property int fsLabel: Math.max(11, Math.floor(fsTime * 0.42))
            readonly property int fsDate: Math.max(12, Math.floor(fsTime * 0.55))
            readonly property int cardRadius: Math.max(8, Math.floor(fsTime * 0.22))
            readonly property int containerRadius: cardRadius + 6

            Layout.minimumWidth: 240
            Layout.minimumHeight: 110
            Layout.preferredWidth: 560
            Layout.preferredHeight: 220

            // Container background (optional)
            Rectangle {
                anchors.fill: parent
                radius: deskItem.containerRadius
                visible: deskItem.useCards && Plasmoid.configuration.desktopShowContainer
                color: deskItem.pal.bg
            }

            GridLayout {
                id: cardGrid
                anchors.fill: parent
                anchors.margins: deskItem.outerPad
                rowSpacing: deskItem.gap
                columnSpacing: deskItem.gap
                rows: deskItem.vertical ? deskItem.cardCount : 1
                columns: deskItem.vertical ? 1 : deskItem.cardCount
                layoutDirection: (Plasmoid.configuration.localOnRight && !deskItem.vertical) ? Qt.RightToLeft : Qt.LeftToRight

                Repeater {
                    model: deskItem.cards

                    delegate: Rectangle {
                        id: card
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: deskItem.cardRadius
                        color: deskItem.useCards ? deskItem.pal.card : "transparent"

                        readonly property string kind: modelData
                        readonly property bool isCombinedDate: kind === "date-combined"
                        readonly property bool isWeekdayDay: kind === "weekday-day"
                        readonly property bool isHebrewCombined: kind === "hebrew-day-month"
                            || kind === "hebrew-day-month-year"
                            || kind === "hebrew-month-day"
                            || kind === "hebrew-month-day-year"
                        readonly property bool isExtraTz: kind.indexOf("tz:") === 0
                        readonly property bool isTimeBlock: kind === "local-time" || kind === "utc-time" || isExtraTz

                        // For non-combined blocks: a single primary value
                        readonly property string primary: {
                            const d = root.activeDate();
                            const utc = root.activeUtc();
                            if (kind.indexOf("tz:") === 0) {
                                const e = root.findExtraTz(kind);
                                return e ? fmtTimeInTz(nowLocal, e.tzid) : "?";
                            }
                            switch (kind) {
                                case "local-time": return fmtTime(nowLocal, false);
                                case "utc-time": return fmtTime(nowUtc, true);
                                case "weekday": return dateBoxWeekday(d, utc);
                                case "gregorian-date":
                                    return monthName(d, utc, Plasmoid.configuration.monthLong) + " " + dayOfMonth(d, utc);
                                case "month": return monthName(d, utc, Plasmoid.configuration.monthLong);
                                case "day": return dayOfMonth(d, utc);
                                case "hebrew-day": return root.hebrewParts.hd ? String(root.hebrewParts.hd) : "—";
                                case "hebrew-month": return root.hebrewParts.hm || "…";
                                case "hebrew-year": return root.hebrewParts.hy ? String(root.hebrewParts.hy) : "…";
                                case "hebrew-day-month":
                                    return (root.hebrewParts.hd && root.hebrewParts.hm)
                                        ? (root.hebrewParts.hd + " " + root.hebrewParts.hm) : "…";
                                case "hebrew-day-month-year":
                                    return (root.hebrewParts.hd && root.hebrewParts.hm && root.hebrewParts.hy)
                                        ? (root.hebrewParts.hd + " " + root.hebrewParts.hm + " " + root.hebrewParts.hy) : "…";
                                case "hebrew-month-day":
                                    return (root.hebrewParts.hm && root.hebrewParts.hd)
                                        ? (root.hebrewParts.hm + " " + root.hebrewParts.hd) : "…";
                                case "hebrew-month-day-year":
                                    return (root.hebrewParts.hm && root.hebrewParts.hd && root.hebrewParts.hy)
                                        ? (root.hebrewParts.hm + " " + root.hebrewParts.hd + " " + root.hebrewParts.hy) : "…";
                                default: return "";
                            }
                        }
                        readonly property string secondary: {
                            if (kind.indexOf("tz:") === 0) {
                                const e = root.findExtraTz(kind);
                                return e ? e.label : "";
                            }
                            switch (kind) {
                                case "local-time":
                                    const lbl = Plasmoid.configuration.autoLocalLabel ? localTzAbbrev() : Plasmoid.configuration.localLabel;
                                    return Plasmoid.configuration.showUtcOffset ? lbl + " (" + utcOffsetString() + ")" : lbl;
                                case "utc-time": return Plasmoid.configuration.utcLabel;
                                default: return "";
                            }
                        }

                        // Weekday + day-of-month stacked (desktop card)
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Math.max(6, Math.floor(deskItem.fsTime * 0.18))
                            spacing: Math.max(2, Math.floor(deskItem.fsTime * 0.06))
                            visible: card.isWeekdayDay
                            Item { Layout.fillHeight: true }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: dateBoxWeekday(root.activeDate(), root.activeUtc())
                                color: deskItem.pal.text
                                font.family: root.fontFamily
                                font.pixelSize: deskItem.fsDate
                                font.bold: true
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 10
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: dayOfMonth(root.activeDate(), root.activeUtc())
                                color: deskItem.pal.text
                                font.family: root.fontFamily
                                font.pixelSize: deskItem.fsDate
                                font.bold: true
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 10
                            }
                            Item { Layout.fillHeight: true }
                        }

                        // Simple block: primary + optional secondary
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Math.max(6, Math.floor(deskItem.fsTime * 0.18))
                            spacing: Math.max(2, Math.floor(deskItem.fsTime * 0.06))
                            visible: !card.isCombinedDate && !card.isWeekdayDay

                            Item { Layout.fillHeight: true }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: card.primary
                                color: deskItem.pal.text
                                font.family: root.fontFamily
                                font.pixelSize: deskItem.fsTime
                                font.bold: true
                                font.letterSpacing: card.isTimeBlock ? -0.5 : 0
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 10
                                elide: Text.ElideNone
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: deskItem.fsLabel
                                Text {
                                    anchors.fill: parent
                                    visible: card.secondary.length > 0 && Plasmoid.configuration.showLabels
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: card.secondary
                                    color: deskItem.pal.label
                                    font.family: root.fontFamily
                                    font.pixelSize: deskItem.fsLabel
                                    font.weight: Font.Medium
                                    font.letterSpacing: 2
                                    fontSizeMode: Text.HorizontalFit
                                    minimumPixelSize: 8
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }

                        // Combined date card: stacked weekday/date + optional Hebrew
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Math.max(6, Math.floor(deskItem.fsTime * 0.18))
                            spacing: Math.max(2, Math.floor(deskItem.fsTime * 0.06))
                            visible: card.isCombinedDate

                            readonly property bool weekdayTop: Plasmoid.configuration.dateBoxLayout !== "date-top"
                            readonly property bool singleLine: Plasmoid.configuration.gregorianDateStyle === "single-line"
                            readonly property bool showHeb: Plasmoid.configuration.showHebrewDate && root.hebrewDateStr.length > 0
                            readonly property string wd: dateBoxWeekday(root.activeDate(), root.activeUtc())
                            readonly property string md: dateBoxDateLine(root.activeDate(), root.activeUtc())

                            Item { Layout.fillHeight: true }
                            Text {
                                visible: parent.singleLine
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: parent.wd + " " + parent.md
                                color: deskItem.pal.text
                                font.family: root.fontFamily
                                font.pixelSize: deskItem.fsDate
                                font.bold: true
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 10
                            }
                            Text {
                                visible: !parent.singleLine
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: parent.weekdayTop ? parent.wd : parent.md
                                color: deskItem.pal.text
                                font.family: root.fontFamily
                                font.pixelSize: deskItem.fsDate
                                font.bold: parent.weekdayTop
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 10
                            }
                            Text {
                                visible: !parent.singleLine
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: parent.weekdayTop ? parent.md : parent.wd
                                color: deskItem.pal.text
                                font.family: root.fontFamily
                                font.pixelSize: deskItem.fsDate
                                font.bold: !parent.weekdayTop
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 10
                            }
                            Text {
                                visible: parent.showHeb
                                Layout.fillWidth: true
                                Layout.topMargin: Math.max(2, Math.floor(deskItem.fsTime * 0.08))
                                horizontalAlignment: Text.AlignHCenter
                                text: root.hebrewDateStr
                                color: deskItem.pal.label
                                font.family: root.fontFamily
                                font.pixelSize: Math.max(11, Math.floor(deskItem.fsDate * 0.75))
                                font.weight: Font.Medium
                                fontSizeMode: Text.HorizontalFit
                                minimumPixelSize: 9
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }
    }
}
