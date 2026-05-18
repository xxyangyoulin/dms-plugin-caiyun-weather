import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "caiyunWeather"

    StyledText {
        width: parent.width
        text: "Caiyun Weather"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Token is saved in local plugin settings, not in the plugin source."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "token"
        label: "API Token"
        description: "Caiyun weather API token."
        placeholder: "Paste your Caiyun token"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "locationName"
        label: "Location Name"
        description: "Name shown in the popout header."
        placeholder: "Home"
        defaultValue: ""
    }

    Row {
        width: parent.width
        spacing: Theme.spacingS

        DankButton {
            id: locationButton
            text: "Use Current Location"
            iconName: "my_location"
            enabled: LocationService.locationAvailable && LocationService.valid
            onClicked: {
                root.saveValue("latitude", LocationService.latitude.toString())
                root.saveValue("longitude", LocationService.longitude.toString())
            }
        }

        StyledText {
            width: parent.width - Theme.spacingS - locationButton.width
            text: LocationService.locationAvailable ? (LocationService.valid ? `${LocationService.latitude.toFixed(5)}, ${LocationService.longitude.toFixed(5)}` : "Location service has no coordinates yet") : "Location service unavailable"
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    StringSetting {
        settingKey: "longitude"
        label: "Longitude"
        description: "Caiyun API uses longitude,latitude in the request path."
        placeholder: "116.3176"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "latitude"
        label: "Latitude"
        placeholder: "39.9760"
        defaultValue: ""
    }

    SelectionSetting {
        settingKey: "language"
        label: "Language"
        description: "Language for Caiyun text fields."
        defaultValue: "zh_CN"
        options: [
            {
                "label": "简体中文",
                "value": "zh_CN"
            },
            {
                "label": "繁体中文",
                "value": "zh_TW"
            },
            {
                "label": "English",
                "value": "en_US"
            }
        ]
    }

    SliderSetting {
        settingKey: "refreshIntervalMinutes"
        label: "Refresh Interval"
        description: "Automatic refresh interval in minutes."
        defaultValue: 15
        minimum: 5
        maximum: 60
        unit: "min"
    }

    ToggleSetting {
        settingKey: "nightUpdatePaused"
        label: "Pause Night Updates"
        description: "Skip scheduled updates from 18:00 to 09:00. Manual refresh still works."
        defaultValue: false
    }
}
