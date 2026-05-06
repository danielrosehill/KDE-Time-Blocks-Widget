import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page
    spacing: Kirigami.Units.largeSpacing

    property string cfg_panelCardOrder
    property string cfg_cardOrder
    property string cfg_extraTimezones

    function _parseExtraTz() {
        try { const a = JSON.parse(cfg_extraTimezones || "[]"); return Array.isArray(a) ? a : []; } catch (e) { return []; }
    }
    readonly property var extraTzBlocks: {
        const out = [];
        const list = _parseExtraTz();
        for (const e of list) out.push({ kind: "tz:" + e.id, label: i18n("Time zone: %1 (%2)", e.label, e.tzid) });
        return out;
    }

    readonly property var standardBlocks: [
        { kind: "local-time",            label: i18n("Local time (HH:MM)") },
        { kind: "utc-time",              label: i18n("UTC time (HH:MM)") },
        { kind: "date-combined",         label: i18n("Date card (weekday + date + Hebrew)") },
        { kind: "weekday-day",           label: i18n("Weekday + day (Thurs / 30)") },
        { kind: "weekday",               label: i18n("Weekday (Thurs)") },
        { kind: "gregorian-date",        label: i18n("Gregorian date (Apr 30)") },
        { kind: "month",                 label: i18n("Month (April)") },
        { kind: "day",                   label: i18n("Day of month (30)") }
    ]
    readonly property var hebrewBlocks: [
        { kind: "hebrew-day-month",      label: i18n("Hebrew: 13 Iyyar") },
        { kind: "hebrew-day-month-year", label: i18n("Hebrew: 13 Iyyar 5786") },
        { kind: "hebrew-month-day",      label: i18n("Hebrew: Iyyar 13") },
        { kind: "hebrew-month-day-year", label: i18n("Hebrew: Iyyar 13 5786") },
        { kind: "hebrew-day",            label: i18n("Hebrew day (13)") },
        { kind: "hebrew-month",          label: i18n("Hebrew month (Iyyar)") },
        { kind: "hebrew-year",           label: i18n("Hebrew year (5786)") }
    ]
    readonly property var allBlocks: standardBlocks.concat(extraTzBlocks).concat(hebrewBlocks)

    Label {
        text: i18n("Choose which blocks appear in each layout, and drag to reorder. The same widget renders the Tray list when docked in a panel and the Desktop list when free-floating on the desktop.")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        opacity: 0.8
    }

    GroupBox {
        Layout.fillWidth: true
        title: i18n("Tray presets")

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Label {
                text: i18n("One-click tray layouts. Applies to the Tray list below.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                opacity: 0.75
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Button {
                    text: i18n("Preset 1: separated (Local · UTC · Thurs · 30 · 13 Iyyar)")
                    onClicked: cfg_panelCardOrder = "local-time,utc-time,weekday,day,hebrew-day-month"
                }
                Button {
                    text: i18n("Preset 2: combined (Local · UTC · Thurs/30 · 13 Iyyar)")
                    onClicked: cfg_panelCardOrder = "local-time,utc-time,weekday-day,hebrew-day-month"
                }
                Button {
                    text: i18n("Preset 3: no Hebrew (Local · UTC · Thurs/30)")
                    onClicked: cfg_panelCardOrder = "local-time,utc-time,weekday-day"
                }
            }
        }
    }

    BlockList {
        Layout.fillWidth: true
        title: i18n("Tray blocks (panel)")
        subtitle: i18n("Compact blocks shown when the widget is docked in the system tray / panel.")
        orderString: cfg_panelCardOrder
        allBlocks: page.allBlocks
        hebrewBlocks: page.hebrewBlocks
        onOrderChanged: function (newOrder) { cfg_panelCardOrder = newOrder; }
    }

    Kirigami.Separator { Layout.fillWidth: true }

    BlockList {
        Layout.fillWidth: true
        title: i18n("Desktop blocks")
        subtitle: i18n("Each enabled block is a separate card on the desktop.")
        orderString: cfg_cardOrder
        allBlocks: page.allBlocks
        hebrewBlocks: page.hebrewBlocks
        onOrderChanged: function (newOrder) { cfg_cardOrder = newOrder; }
    }
}
