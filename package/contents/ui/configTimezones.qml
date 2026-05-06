import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page
    spacing: Kirigami.Units.largeSpacing

    property string cfg_extraTimezones
    property string cfg_panelCardOrder
    property string cfg_cardOrder

    function _parse(s) {
        try { const a = JSON.parse(s || "[]"); return Array.isArray(a) ? a : []; } catch (e) { return []; }
    }
    function _serialize(arr) { return JSON.stringify(arr); }
    function _newId() { return "tz_" + Date.now().toString(36) + Math.floor(Math.random() * 1000).toString(36); }

    function loadModel() {
        tzModel.clear();
        const arr = _parse(cfg_extraTimezones);
        for (const e of arr)
            tzModel.append({ id: e.id || _newId(), tzid: e.tzid || "", label: e.label || "" });
    }
    function persist() {
        const out = [];
        for (let i = 0; i < tzModel.count; i++) {
            const it = tzModel.get(i);
            out.push({ id: it.id, tzid: it.tzid, label: it.label });
        }
        cfg_extraTimezones = _serialize(out);
    }
    function _orderHas(orderStr, kind) {
        const parts = (orderStr || "").split(",").map(s => s.trim()).filter(s => s.length);
        return parts.indexOf(kind) !== -1;
    }
    function _insertAfter(orderStr, anchor, kind) {
        const parts = (orderStr || "").split(",").map(s => s.trim()).filter(s => s.length);
        if (parts.indexOf(kind) !== -1) return parts.join(",");
        const idx = parts.indexOf(anchor);
        if (idx === -1) parts.push(kind); else parts.splice(idx + 1, 0, kind);
        return parts.join(",");
    }
    function _removeKind(orderStr, kind) {
        return (orderStr || "").split(",").map(s => s.trim())
            .filter(s => s.length && s !== kind).join(",");
    }

    Component.onCompleted: loadModel()

    ListModel { id: tzModel }

    readonly property var commonZones: [
        { tzid: "America/New_York",     label: "NYC"   },
        { tzid: "America/Los_Angeles",  label: "LA"    },
        { tzid: "America/Chicago",      label: "CHI"   },
        { tzid: "Europe/London",        label: "LDN"   },
        { tzid: "Europe/Paris",         label: "PAR"   },
        { tzid: "Europe/Berlin",        label: "BER"   },
        { tzid: "Asia/Dubai",           label: "DXB"   },
        { tzid: "Asia/Kolkata",         label: "IST"   },
        { tzid: "Asia/Singapore",       label: "SGP"   },
        { tzid: "Asia/Tokyo",           label: "TYO"   },
        { tzid: "Asia/Hong_Kong",       label: "HKG"   },
        { tzid: "Australia/Sydney",     label: "SYD"   }
    ]

    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: i18n("Add additional time zones to display alongside Local and UTC. Each one renders as its own block; once added, you can reorder it on the Blocks page (it appears as <i>tz: LABEL</i>).")
        opacity: 0.8
    }

    GroupBox {
        Layout.fillWidth: true
        title: i18n("Add a time zone")

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Label { text: i18n("Label:") }
                TextField {
                    id: newLabel
                    Layout.preferredWidth: 90
                    placeholderText: i18n("e.g. NYC")
                }
                Label { text: i18n("IANA TZ:") }
                TextField {
                    id: newTzid
                    Layout.fillWidth: true
                    placeholderText: i18n("e.g. America/New_York")
                }
                Button {
                    text: i18n("Add")
                    enabled: newLabel.text.length > 0 && newTzid.text.length > 0
                    onClicked: {
                        const id = page._newId();
                        tzModel.append({ id: id, tzid: newTzid.text.trim(), label: newLabel.text.trim() });
                        page.persist();
                        // Auto-insert into tray order right after utc-time
                        const kind = "tz:" + id;
                        cfg_panelCardOrder = page._insertAfter(cfg_panelCardOrder, "utc-time", kind);
                        cfg_cardOrder = page._insertAfter(cfg_cardOrder, "utc-time", kind);
                        newLabel.text = "";
                        newTzid.text = "";
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Label { text: i18n("Quick pick:"); opacity: 0.75 }
                ComboBox {
                    id: quickPick
                    Layout.fillWidth: true
                    model: page.commonZones.map(z => z.label + " — " + z.tzid)
                    onActivated: function (idx) {
                        const z = page.commonZones[idx];
                        newLabel.text = z.label;
                        newTzid.text = z.tzid;
                    }
                }
            }
        }
    }

    Label {
        text: i18n("Configured time zones")
        font.bold: true
        visible: tzModel.count > 0
    }

    ListView {
        id: tzView
        Layout.fillWidth: true
        Layout.preferredHeight: contentHeight
        model: tzModel
        spacing: 2
        interactive: false
        clip: false
        visible: tzModel.count > 0

        delegate: Rectangle {
            width: tzView.width
            height: 40
            radius: 4
            color: index % 2 ? Kirigami.Theme.alternateBackgroundColor : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: Kirigami.Units.smallSpacing

                TextField {
                    Layout.preferredWidth: 90
                    text: model.label
                    onEditingFinished: {
                        tzModel.setProperty(index, "label", text);
                        page.persist();
                    }
                }
                TextField {
                    Layout.fillWidth: true
                    text: model.tzid
                    onEditingFinished: {
                        tzModel.setProperty(index, "tzid", text);
                        page.persist();
                    }
                }
                Button {
                    text: i18n("↑")
                    enabled: index > 0
                    onClicked: { tzModel.move(index, index - 1, 1); page.persist(); }
                }
                Button {
                    text: i18n("↓")
                    enabled: index < tzModel.count - 1
                    onClicked: { tzModel.move(index, index + 1, 1); page.persist(); }
                }
                Button {
                    text: i18n("Remove")
                    onClicked: {
                        const removedKind = "tz:" + model.id;
                        tzModel.remove(index);
                        page.persist();
                        cfg_panelCardOrder = page._removeKind(cfg_panelCardOrder, removedKind);
                        cfg_cardOrder = page._removeKind(cfg_cardOrder, removedKind);
                    }
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: i18n("Tip: IANA names look like <i>America/New_York</i>, <i>Europe/Berlin</i>, <i>Asia/Tokyo</i>. The label is what shows under the time.")
        opacity: 0.7
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
    }

    Item { Layout.fillHeight: true }
}
