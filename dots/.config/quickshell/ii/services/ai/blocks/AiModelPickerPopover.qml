pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

/**
 * The model list, grouped by provider.
 *
 * Every model says what it can do before it is picked — reasoning, images,
 * attachments, server-side search, tools — and how much it can hold, so
 * choosing does not mean remembering. A model whose key is missing is shown
 * rather than hidden: not knowing why a model is absent is worse than seeing
 * it greyed with a reason.
 */
Item {
    id: root

    signal picked(modelId: string)

    property string query: ""

    readonly property var badgeDefs: [
        {
            key: "thinking",
            symbol: "neurology",
            label: Translation.tr("Thinks")
        },
        {
            key: "vision",
            symbol: "visibility",
            label: Translation.tr("Reads images")
        },
        {
            key: "attachments",
            symbol: "attach_file",
            label: Translation.tr("Takes attachments")
        },
        {
            key: "builtinSearch",
            symbol: "travel_explore",
            label: Translation.tr("Searches the web")
        },
        {
            key: "tools",
            symbol: "service_toolbox",
            label: Translation.tr("Calls tools")
        }
    ]

    function matches(model, provider, needle: string): bool {
        if (needle.length === 0)
            return true;
        return model.title.toLowerCase().includes(needle) || model.value.toLowerCase().includes(needle) || provider.name.toLowerCase().includes(needle);
    }

    function hasKey(model): bool {
        if (!model?.requires_key)
            return true;
        return (Ai.apiKeys[model.key_id]?.length ?? 0) > 0;
    }

    function formatContext(tokens: int): string {
        if (tokens >= 1000000)
            return Translation.tr("%1M context").arg((tokens / 1000000).toFixed(tokens % 1000000 === 0 ? 0 : 1));
        if (tokens >= 1000)
            return Translation.tr("%1K context").arg(Math.round(tokens / 1000));
        return "";
    }

    /**
     * Headers and models in one flat list, so a single view draws both.
     *
     * A group folded by its header keeps only the header, and says how many
     * models it is hiding. A search folds nothing: a match that stayed hidden
     * behind a header would read as no match at all.
     */
    readonly property var rows: {
        const needle = root.query.trim().toLowerCase();
        const folded = needle.length > 0 ? [] : Ai.collapsedModelGroups;
        const rows = [];

        if (needle.length === 0) {
            const recent = Ai.recentModelIds;
            if (recent.length > 0) {
                const recentFolded = folded.includes("recent");
                rows.push({
                    kind: "header",
                    groupId: "recent",
                    label: Translation.tr("Recently used"),
                    collapsed: recentFolded,
                    count: recent.length
                });
                for (let i = 0; !recentFolded && i < recent.length; i++) {
                    rows.push({
                        kind: "model",
                        model: Ai.catalog.models[recent[i]]
                    });
                }
            }
        }

        const providerIds = Ai.providerIds;
        for (let i = 0; i < providerIds.length; i++) {
            const provider = Ai.providers[providerIds[i]];
            if (!provider)
                continue;
            const models = Array.from(provider.models).filter(model => root.matches(model, provider, needle));
            if (models.length === 0)
                continue;
            const providerFolded = folded.includes(providerIds[i]);
            rows.push({
                kind: "header",
                groupId: providerIds[i],
                label: provider.name,
                symbol: provider.materialIcon,
                iconSource: provider.icon,
                collapsed: providerFolded,
                count: models.length
            });
            for (let j = 0; !providerFolded && j < models.length; j++) {
                rows.push({
                    kind: "model",
                    model: models[j]
                });
            }
        }
        return rows;
    }

    property real maxListHeight: 340
    implicitHeight: searchBox.implicitHeight + 8 + Math.max(48, Math.min(modelListView.contentHeight, root.maxListHeight))

    component CapabilityBadge: Item {
        id: badge

        property string symbol: ""
        property string label: ""

        implicitWidth: Appearance.font.pixelSize.normal
        implicitHeight: Appearance.font.pixelSize.normal

        MaterialSymbol {
            anchors.centerIn: parent
            text: badge.symbol
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }

        MouseArea {
            id: badgeMouseArea
            anchors.fill: parent
            hoverEnabled: true
        }

        StyledToolTip {
            text: badge.label
            extraVisibleCondition: false
            alternativeVisibleCondition: badgeMouseArea.containsMouse
        }
    }

    Rectangle {
        id: searchBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: 36
        radius: height / 2
        color: Appearance.colors.colLayer2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 8

            MaterialSymbol {
                text: "search"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colSubtext
            }

            StyledTextInput {
                id: searchInput
                Layout.fillWidth: true
                onTextChanged: root.query = text
                Component.onCompleted: forceActiveFocus()

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text.length === 0
                    text: Translation.tr("Search models")
                    color: Appearance.colors.colSubtext
                    font: searchInput.font
                }
            }

            RippleButton {
                visible: searchInput.text.length > 0
                implicitWidth: 26
                implicitHeight: 26
                buttonRadius: height / 2
                colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: searchInput.clear()

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer2
                }
            }
        }
    }

    StyledListView {
        id: modelListView
        anchors {
            top: searchBox.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        spacing: 2
        model: root.rows

        delegate: Item {
            id: rowItem
            required property var modelData

            width: modelListView.width
            implicitHeight: rowItem.modelData.kind === "header" ? headerLoader.implicitHeight : modelLoader.implicitHeight

            Loader {
                id: headerLoader
                anchors.left: parent.left
                anchors.right: parent.right
                active: rowItem.modelData.kind === "header"
                visible: active

                sourceComponent: RippleButton {
                    id: headerButton

                    topPadding: 8
                    bottomPadding: 2
                    leftPadding: 4
                    rightPadding: 4
                    buttonRadius: Appearance.rounding.small
                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    onClicked: Ai.toggleModelGroupCollapsed(rowItem.modelData.groupId)

                    contentItem: RowLayout {
                        spacing: 6

                        Loader {
                            active: (rowItem.modelData.iconSource ?? "").length > 0
                            visible: active
                            sourceComponent: CustomIcon {
                                source: rowItem.modelData.iconSource
                                width: Appearance.font.pixelSize.normal
                                height: Appearance.font.pixelSize.normal
                                colorize: true
                                color: Appearance.colors.colSubtext
                            }
                        }

                        Loader {
                            active: (rowItem.modelData.iconSource ?? "").length === 0 && (rowItem.modelData.symbol ?? "").length > 0
                            visible: active
                            sourceComponent: MaterialSymbol {
                                text: rowItem.modelData.symbol
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colSubtext
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: rowItem.modelData.label
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                        }

                        StyledText {
                            // Only worth saying while the models themselves
                            // are out of sight.
                            visible: rowItem.modelData.collapsed ?? false
                            text: rowItem.modelData.count ?? 0
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }

                        MaterialSymbol {
                            text: "expand_more"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                            rotation: (rowItem.modelData.collapsed ?? false) ? -90 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animationCurves.standard
                                }
                            }
                        }
                    }

                    StyledToolTip {
                        text: (rowItem.modelData.collapsed ?? false) ? Translation.tr("Show these models") : Translation.tr("Fold this group away")
                    }
                }
            }

            Loader {
                id: modelLoader
                anchors.left: parent.left
                anchors.right: parent.right
                active: rowItem.modelData.kind === "model" && !!rowItem.modelData.model
                visible: active

                sourceComponent: RippleButton {
                    id: modelButton
                    readonly property var entry: rowItem.modelData.model
                    readonly property bool keyed: root.hasKey(entry)

                    leftPadding: 10
                    rightPadding: 10
                    topPadding: 8
                    bottomPadding: 8
                    buttonRadius: Appearance.rounding.small
                    toggled: entry.id === Ai.currentModelId
                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colRipple: Appearance.colors.colLayer2Active
                    colBackgroundToggled: Appearance.colors.colSecondaryContainer
                    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                    onClicked: root.picked(modelButton.entry.id)

                    contentItem: ColumnLayout {
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            StyledText {
                                Layout.fillWidth: true
                                text: modelButton.entry.title
                                elide: Text.ElideRight
                                color: modelButton.toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer2
                            }

                            MaterialSymbol {
                                visible: !modelButton.keyed
                                text: "key_off"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colSubtext
                            }

                            MaterialSymbol {
                                visible: modelButton.toggled
                                text: "check"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.m3colors.m3onSecondaryContainer
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: root.badgeDefs.filter(badge => modelButton.entry[badge.key] === true)

                                CapabilityBadge {
                                    required property var modelData
                                    symbol: modelData.symbol
                                    label: modelData.label
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: modelButton.keyed ? root.formatContext(modelButton.entry.contextWindow) : Translation.tr("No API key yet")
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }
        }
    }

    StyledText {
        anchors.centerIn: modelListView
        visible: root.rows.length === 0
        text: Translation.tr("Nothing matches “%1”").arg(root.query)
        color: Appearance.colors.colSubtext
    }
}
