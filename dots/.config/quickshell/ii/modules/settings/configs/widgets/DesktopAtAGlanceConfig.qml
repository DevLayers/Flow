import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: false
    signal goBack()

    function setPrimaryService(service) {
        const priority = JSON.parse(JSON.stringify(Config.options.background.widgets.at_a_glance.servicePriority));
        const index = priority.indexOf(service);
        if (index > 0)
            priority.splice(index, 1);
        if (index !== 0)
            priority.unshift(service);
        Config.options.background.widgets.at_a_glance.servicePriority = priority;
    }

    RowLayout {
        spacing: Appearance.font.pixelSize.small

        RippleButton {
            implicitWidth: implicitHeight
            implicitHeight: Appearance.font.pixelSize.huge * 2
            topLeftRadius: Appearance.rounding.full
            topRightRadius: Appearance.rounding.full
            bottomLeftRadius: Appearance.rounding.full
            bottomRightRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colSecondaryContainerActive

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSecondaryContainer
            }

            onClicked: root.goBack()
        }

        StyledText {
            text: Translation.tr("At a Glance Widget Options")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer0
        }
    }

    ContentSection {
        title: Translation.tr("At a Glance")
        icon: "dashboard"

        Item {
            Layout.fillWidth: true
            implicitHeight: Appearance.sizes.mediaControlsHeight
            visible: !Config.isWidgetActive("at_a_glance")

            PagePlaceholder {
                anchors.fill: parent
                icon: "dashboard_customize"
                shape: MaterialShape.Shape.Circle
                title: Translation.tr("At a Glance widget disabled")
                description: Translation.tr("Enable the At a Glance widget in Desktop Widgets settings to use this page.")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.font.pixelSize.smaller
            visible: Config.isWidgetActive("at_a_glance")

            ContentSubsectionLabel {
                text: Translation.tr("Layout")
            }

            ConfigSelectionArray {
                currentValue: Config.options.background.widgets.at_a_glance.widthCells
                options: [
                    { displayName: Translation.tr("2x1 Compact"), icon: "view_week", value: 2 },
                    { displayName: Translation.tr("3x1 Full"), icon: "view_column", value: 3 }
                ]
                onSelected: value => Config.options.background.widgets.at_a_glance.widthCells = value
            }

            ConfigSwitch {
                buttonIcon: "label"
                text: Translation.tr("Show location")
                checked: Config.options.background.widgets.at_a_glance.showLocation
                onCheckedChanged: Config.options.background.widgets.at_a_glance.showLocation = checked
            }

            ConfigSwitch {
                buttonIcon: "label_important"
                text: Translation.tr("Show service details")
                checked: Config.options.background.widgets.at_a_glance.showServiceLabel
                onCheckedChanged: Config.options.background.widgets.at_a_glance.showServiceLabel = checked
            }

            ConfigSwitch {
                buttonIcon: "more_vert"
                text: Translation.tr("Show decorative separators")
                checked: Config.options.background.widgets.at_a_glance.showSeparators
                onCheckedChanged: Config.options.background.widgets.at_a_glance.showSeparators = checked
            }

            ContentSubsectionLabel {
                text: Translation.tr("Context priority")
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Choose which context appears first when multiple services are available.")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            ConfigSelectionArray {
                currentValue: Config.options.background.widgets.at_a_glance.servicePriority[0]
                options: [
                    { displayName: Translation.tr("Media first"), icon: "music_note", value: "media" },
                    { displayName: Translation.tr("Calendar first"), icon: "event", value: "calendar" },
                    { displayName: Translation.tr("Sports first"), icon: "sports_soccer", value: "sports" },
                    { displayName: Translation.tr("Date first"), icon: "today", value: "fallback" }
                ]
                onSelected: value => root.setPrimaryService(value)
            }

            ContentSubsectionLabel {
                text: Translation.tr("Context sources")
            }

            ConfigSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Use media context")
                checked: Config.options.background.widgets.at_a_glance.enableMedia
                onCheckedChanged: Config.options.background.widgets.at_a_glance.enableMedia = checked
            }

            ConfigSwitch {
                buttonIcon: "event"
                text: Translation.tr("Use calendar context")
                checked: Config.options.background.widgets.at_a_glance.enableCalendar
                onCheckedChanged: Config.options.background.widgets.at_a_glance.enableCalendar = checked
            }

            ConfigSwitch {
                buttonIcon: "sports_soccer"
                text: Translation.tr("Use sports context")
                checked: Config.options.background.widgets.at_a_glance.enableSports
                onCheckedChanged: Config.options.background.widgets.at_a_glance.enableSports = checked
            }

            ConfigSwitch {
                buttonIcon: "cloud"
                text: Translation.tr("Show weather")
                checked: Config.options.background.widgets.at_a_glance.enableWeather
                onCheckedChanged: Config.options.background.widgets.at_a_glance.enableWeather = checked
            }

            ContentSubsectionLabel {
                text: Translation.tr("Context windows")
            }

            ConfigSpinBox {
                icon: "event_upcoming"
                text: Translation.tr("Calendar window (minutes)")
                value: Config.options.background.widgets.at_a_glance.calendarWindowMinutes
                from: 0
                to: 720
                stepSize: 15
                onValueChanged: Config.options.background.widgets.at_a_glance.calendarWindowMinutes = value
            }

            ConfigSpinBox {
                icon: "schedule"
                text: Translation.tr("Sports window (hours)")
                value: Config.options.background.widgets.at_a_glance.sportsWindowHours
                from: 0
                to: 168
                stepSize: 1
                onValueChanged: Config.options.background.widgets.at_a_glance.sportsWindowHours = value
            }

            ConfigSwitch {
                buttonIcon: "animation"
                text: Translation.tr("Animate context changes")
                checked: Config.options.background.widgets.at_a_glance.animateContent
                onCheckedChanged: Config.options.background.widgets.at_a_glance.animateContent = checked
            }

            ContentSubsectionLabel {
                text: Translation.tr("Visual options")
            }

            ConfigSwitch {
                buttonIcon: "wb_sunny"
                text: Translation.tr("Enable shadows")
                checked: Config.options.background.widgets.enableShadows ?? true
                onCheckedChanged: Config.options.background.widgets.enableShadows = checked
            }

            ConfigSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Enable inner shadows")
                checked: Config.options.background.widgets.enableInnerShadow ?? true
                onCheckedChanged: Config.options.background.widgets.enableInnerShadow = checked
            }
        }
    }
}
