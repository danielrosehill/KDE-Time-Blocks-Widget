import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page
    spacing: Kirigami.Units.largeSpacing

    property alias cfg_hebrewEnabled: hebrewEnabled.checked
    property alias cfg_showHebrewDate: showHebrewDate.checked
    property alias cfg_hebrewDateWithYear: hebrewDateWithYear.checked
    property alias cfg_hebrewMonthFirst: hebrewMonthFirst.checked
    property double cfg_hebrewLatitude
    property double cfg_hebrewLongitude
    property string cfg_hebrewTzid
    property alias cfg_hebrewLocationSet: hebrewLocationSet.checked
    property string cfg_hebrewRolloverMode

    readonly property bool active: hebrewEnabled.checked
    readonly property bool locationMissing: !cfg_hebrewLocationSet || (cfg_hebrewLatitude === 0.0 && cfg_hebrewLongitude === 0.0)

    // Sunset is the only supported rollover mode; force it on whenever this page is shown.
    Component.onCompleted: cfg_hebrewRolloverMode = "sunset"

    Kirigami.FormLayout {
        Layout.fillWidth: true

        CheckBox {
            id: hebrewEnabled
            Kirigami.FormData.label: i18n("Hebrew calendar:")
            text: i18n("Enable Hebrew date options")
        }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Formatting") }

        CheckBox {
            id: showHebrewDate
            enabled: page.active
            Kirigami.FormData.label: i18n("Inside date card:")
            text: i18n("Include Hebrew date row")
        }
        CheckBox {
            id: hebrewMonthFirst
            enabled: page.active
            text: i18n("Month first (Iyyar 13)")
        }
        CheckBox {
            id: hebrewDateWithYear
            enabled: page.active
            text: i18n("Include Hebrew year")
        }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Location") }

        CheckBox {
            id: hebrewLocationSet
            enabled: page.active
            Kirigami.FormData.label: i18n("Location set:")
            text: i18n("Use the coordinates below")
        }
        SpinBox {
            id: latitudeSpin
            enabled: page.active && hebrewLocationSet.checked
            Kirigami.FormData.label: i18n("Latitude:")
            from: -9000
            to: 9000
            stepSize: 1
            value: Math.round(page.cfg_hebrewLatitude * 100)
            onValueModified: page.cfg_hebrewLatitude = value / 100.0
            textFromValue: function (v) { return (v / 100.0).toFixed(2); }
            valueFromText: function (t) { return Math.round(parseFloat(t) * 100); }
            editable: true
        }
        SpinBox {
            id: longitudeSpin
            enabled: page.active && hebrewLocationSet.checked
            Kirigami.FormData.label: i18n("Longitude:")
            from: -18000
            to: 18000
            stepSize: 1
            value: Math.round(page.cfg_hebrewLongitude * 100)
            onValueModified: page.cfg_hebrewLongitude = value / 100.0
            textFromValue: function (v) { return (v / 100.0).toFixed(2); }
            valueFromText: function (t) { return Math.round(parseFloat(t) * 100); }
            editable: true
        }
        TextField {
            id: tzidField
            enabled: page.active && hebrewLocationSet.checked
            Kirigami.FormData.label: i18n("Timezone (IANA):")
            placeholderText: i18n("e.g. Asia/Jerusalem")
            text: page.cfg_hebrewTzid
            onEditingFinished: page.cfg_hebrewTzid = text
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        }
        RowLayout {
            Layout.fillWidth: true
            Button {
                enabled: page.active
                text: i18n("Use system timezone")
                onClicked: {
                    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || "";
                    if (tz.length) {
                        tzidField.text = tz;
                        page.cfg_hebrewTzid = tz;
                    }
                }
            }
            Button {
                enabled: page.active
                text: i18n("Use Jerusalem")
                onClicked: {
                    latitudeSpin.value = Math.round(31.78 * 100);
                    longitudeSpin.value = Math.round(35.22 * 100);
                    page.cfg_hebrewLatitude = 31.78;
                    page.cfg_hebrewLongitude = 35.22;
                    tzidField.text = "Asia/Jerusalem";
                    page.cfg_hebrewTzid = "Asia/Jerusalem";
                    hebrewLocationSet.checked = true;
                }
            }
        }

    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        type: Kirigami.MessageType.Warning
        visible: page.active && page.locationMissing
        text: i18n("Set your location above so the Hebrew date can flip at sunset. Until a location is set, the date will fall back to civil midnight.")
    }
    Kirigami.InlineMessage {
        Layout.fillWidth: true
        type: Kirigami.MessageType.Information
        visible: page.active && !page.locationMissing
        text: i18n("Hebrew date flips at sunset. Sunset times are fetched once per day from hebcal.com using the coordinates above.")
    }
}
