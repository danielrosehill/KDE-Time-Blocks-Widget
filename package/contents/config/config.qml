import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Clock")
        icon: "clock"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Date")
        icon: "view-calendar"
        source: "configDate.qml"
    }
    ConfigCategory {
        name: i18n("Time Zones")
        icon: "globe"
        source: "configTimezones.qml"
    }
    ConfigCategory {
        name: i18n("Blocks")
        icon: "view-grid"
        source: "configBlocks.qml"
    }
    ConfigCategory {
        name: i18n("Hebrew Calendar")
        icon: "view-calendar-day"
        source: "configHebrew.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "configAppearance.qml"
    }
}
