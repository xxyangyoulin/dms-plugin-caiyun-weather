import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "." as Caiyun

PluginComponent {
    id: root

    readonly property bool hasWeather: Caiyun.CaiyunWeatherService.available
    readonly property int rainProbability: Caiyun.CaiyunWeatherService.precipitationProbability()
    readonly property string primaryIcon: {
        if (!Caiyun.CaiyunWeatherService.configured)
            return "cloud_off"
        return Caiyun.CaiyunWeatherService.skyconIcon(Caiyun.CaiyunWeatherService.skycon)
    }
    readonly property string barText: {
        if (!Caiyun.CaiyunWeatherService.configured || !hasWeather)
            return "--"
        if (rainProbability >= 30)
            return `${Caiyun.CaiyunWeatherService.temperature}° ${rainProbability}%`
        return `${Caiyun.CaiyunWeatherService.temperature}°`
    }

    ccWidgetIcon: primaryIcon
    ccWidgetPrimaryText: Caiyun.CaiyunWeatherService.locationName || "Caiyun Weather"
    ccWidgetSecondaryText: hasWeather ? `${Caiyun.CaiyunWeatherService.temperature}° · ${Caiyun.CaiyunWeatherService.skyconText(Caiyun.CaiyunWeatherService.skycon)}` : Caiyun.CaiyunWeatherService.statusText
    ccWidgetIsActive: hasWeather
    ccWidgetIsToggle: false

    popoutWidth: 480
    popoutHeight: 620

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.primaryIcon
                color: Theme.widgetIconColor
                size: root.iconSize
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.barText
                color: Theme.widgetTextColor
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 1

            DankIcon {
                name: root.primaryIcon
                color: Theme.widgetIconColor
                size: root.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.hasWeather ? `${Caiyun.CaiyunWeatherService.temperature}` : "--"
                color: Theme.widgetTextColor
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: Caiyun.CaiyunWeatherService.locationName || "Caiyun Weather"
            detailsText: Caiyun.CaiyunWeatherService.statusText
            showCloseButton: false
            headerActions: Component {
                DankIcon {
                    name: "refresh"
                    size: Theme.iconSize - 4
                    color: refreshArea.containsMouse ? Theme.primary : Theme.surfaceText

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Caiyun.CaiyunWeatherService.manualRefresh()
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingM

                Item {
                    width: parent.width
                    height: Theme.spacingS
                }

                StyledRect {
                    width: parent.width
                    height: alertText.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.warning, 0.16)
                    visible: Caiyun.CaiyunWeatherService.hasAlert

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "warning"
                            color: Theme.warning
                            size: Theme.iconSize - 2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            id: alertText
                            width: parent.width - Theme.iconSize - Theme.spacingS
                            text: Caiyun.CaiyunWeatherService.alertContent[0]?.title || "Weather alert"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                StyledRect {
                    id: currentWeatherCard

                    width: parent.width
                    height: 104
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer
                    visible: root.hasWeather

                    Canvas {
                        id: sunArc

                        anchors.fill: parent
                        opacity: 0.42

                        readonly property real sunrise: Caiyun.CaiyunWeatherService.todaySunriseTimestamp()
                        readonly property real sunset: Caiyun.CaiyunWeatherService.todaySunsetTimestamp()
                        readonly property real nowTime: Date.now()

                        Timer {
                            interval: 60000
                            repeat: true
                            running: currentWeatherCard.visible
                            onTriggered: sunArc.requestPaint()
                        }

                        onSunriseChanged: requestPaint()
                        onSunsetChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        function sunProgress() {
                            if (sunrise <= 0 || sunset <= sunrise)
                                return 0
                            return Math.max(0, Math.min(1, (Date.now() - sunrise) / (sunset - sunrise)))
                        }

                        function pointAt(progress, startX, endX, baseY, arcHeight) {
                            const angle = Math.PI * (1 - progress)
                            const centerX = (startX + endX) / 2
                            const radiusX = (endX - startX) / 2
                            return {
                                "x": centerX + Math.cos(angle) * radiusX,
                                "y": baseY - Math.sin(angle) * arcHeight
                            }
                        }

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            if (sunrise <= 0 || sunset <= sunrise)
                                return

                            const startX = width * (1 - 0.618)
                            const endX = width - Theme.spacingL
                            const baseY = height - 18
                            const arcHeight = height * 0.46
                            const start = pointAt(0, startX, endX, baseY, arcHeight)
                            const end = pointAt(1, startX, endX, baseY, arcHeight)
                            const sun = pointAt(sunProgress(), startX, endX, baseY, arcHeight)

                            ctx.beginPath()
                            for (let i = 0; i <= 48; i++) {
                                const point = pointAt(i / 48, startX, endX, baseY, arcHeight)
                                if (i === 0)
                                    ctx.moveTo(point.x, point.y)
                                else
                                    ctx.lineTo(point.x, point.y)
                            }
                            ctx.strokeStyle = Theme.withAlpha(Theme.primary, 0.28)
                            ctx.lineWidth = 1.5
                            ctx.stroke()

                            ctx.fillStyle = Theme.withAlpha(Theme.primary, 0.18)
                            ctx.beginPath()
                            ctx.arc(sun.x, sun.y, 9, 0, Math.PI * 2)
                            ctx.fill()
                            ctx.fillStyle = Theme.withAlpha(Theme.primary, 0.55)
                            ctx.beginPath()
                            ctx.arc(sun.x, sun.y, 4, 0, Math.PI * 2)
                            ctx.fill()

                            ctx.fillStyle = Theme.withAlpha(Theme.surfaceText, 0.38)
                            ctx.font = `${Theme.fontSizeSmall}px sans-serif`
                            ctx.textAlign = "left"
                            ctx.fillText(Caiyun.CaiyunWeatherService.sunriseText(), start.x, height - 6)
                            ctx.textAlign = "right"
                            ctx.fillText(Caiyun.CaiyunWeatherService.sunsetText(), end.x, height - 6)
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingL

                        DankIcon {
                            name: Caiyun.CaiyunWeatherService.skyconIcon(Caiyun.CaiyunWeatherService.skycon)
                            color: Theme.primary
                            size: Theme.iconSize * 2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize * 2 - Theme.spacingL
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: `${Caiyun.CaiyunWeatherService.temperature}°C  ${Caiyun.CaiyunWeatherService.skyconText(Caiyun.CaiyunWeatherService.skycon)}`
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeLarge + 4
                                font.weight: Font.Bold
                            }

                            StyledText {
                                text: `体感 ${Caiyun.CaiyunWeatherService.apparentTemperature}°C · ${Caiyun.CaiyunWeatherService.windText()}`
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeMedium
                            }

                            StyledText {
                                width: parent.width
                                text: Caiyun.CaiyunWeatherService.keypoint
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.hasWeather

                    Repeater {
                        model: Caiyun.CaiyunWeatherService.dailyItems(2)

                        delegate: StyledRect {
                            width: (parent.width - Theme.spacingS) / 2
                            height: 90
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainer

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                Column {
                                    width: parent.width - Theme.iconSize - Theme.spacingM
                                    spacing: Theme.spacingXS
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        text: index === 0 ? "今天" : "明天"
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                    }

                                    StyledText {
                                        text: `${modelData.min}°~${modelData.max}°`
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeLarge + 2
                                        font.weight: Font.Medium
                                    }

                                    Row {
                                        spacing: Theme.spacingS

                                        StyledText {
                                            text: Caiyun.CaiyunWeatherService.aqiText(modelData.aqi)
                                            color: Theme.primary
                                            font.pixelSize: Theme.fontSizeSmall
                                        }

                                        StyledText {
                                            text: Caiyun.CaiyunWeatherService.skyconText(modelData.skycon)
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                    }
                                }

                                DankIcon {
                                    name: Caiyun.CaiyunWeatherService.skyconIcon(modelData.skycon)
                                    color: Theme.primary
                                    size: Theme.iconSize
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 24
                    spacing: Theme.spacingS
                    visible: root.hasWeather

                    StyledText {
                        width: parent.width - sunriseRow.width - Theme.spacingS
                        text: "逐小时预报"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        id: sunriseRow
                        spacing: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: `日出 ${Caiyun.CaiyunWeatherService.sunriseText()}`
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        StyledText {
                            text: `日落 ${Caiyun.CaiyunWeatherService.sunsetText()}`
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                Flickable {
                    id: hourlyFlickable

                    width: parent.width
                    height: 164
                    contentWidth: hourlyChart.width
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    visible: root.hasWeather

                    readonly property var items: Caiyun.CaiyunWeatherService.hourlyItems(24)
                    readonly property int itemWidth: 56
                    property bool initialPositionApplied: false

                    onItemsChanged: Qt.callLater(applyInitialPosition)
                    Component.onCompleted: Qt.callLater(applyInitialPosition)

                    function firstCurrentIndex() {
                        for (let i = 0; i < items.length; i++) {
                            if (!items[i].isPast)
                                return i
                        }
                        return 0
                    }

                    function applyInitialPosition() {
                        if (initialPositionApplied || items.length === 0)
                            return
                        const index = Math.max(0, firstCurrentIndex() - 1)
                        contentX = Math.min(index * itemWidth, Math.max(0, contentWidth - width))
                        initialPositionApplied = true
                    }

                    StyledRect {
                        id: hourlyChart

                        width: Math.max(hourlyFlickable.width, hourlyFlickable.items.length * hourlyFlickable.itemWidth)
                        height: hourlyFlickable.height
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainer

                        Canvas {
                            id: temperatureLine

                            anchors.fill: parent
                            property var items: hourlyFlickable.items
                            property int itemWidth: hourlyFlickable.itemWidth
                            property real topPadding: 22
                            property real chartHeight: 54

                            onItemsChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            function pointX(index) {
                                return index * itemWidth + itemWidth / 2
                            }

                            function pointY(item, minTemp, maxTemp) {
                                const range = Math.max(1, maxTemp - minTemp)
                                return topPadding + (maxTemp - item.temperature) / range * chartHeight
                            }

                            function rainAlpha(item) {
                                const value = item.precipitation || 0
                                const probability = item.probability || 0
                                const looksRainy = item.skycon && item.skycon.indexOf("RAIN") !== -1
                                if (value <= 0 && probability <= 0 && !looksRainy)
                                    return 0
                                return Math.max(0.06, Math.min(0.24, 0.04 + Math.sqrt(value) * 0.08 + probability / 1000))
                            }

                            function drawRainStreaks(ctx, x, alpha, intensity) {
                                const spacing = intensity > 0.5 ? 10 : 14
                                const length = intensity > 0.5 ? 14 : 10
                                ctx.strokeStyle = Theme.withAlpha(Theme.primary, Math.min(0.22, alpha + 0.04))
                                ctx.lineWidth = 1
                                for (let y = 10; y < height - 8; y += spacing) {
                                    const offset = ((y / spacing) % 2) * 8
                                    ctx.beginPath()
                                    ctx.moveTo(x + 10 + offset, y)
                                    ctx.lineTo(x + 10 + offset - 5, y + length)
                                    ctx.stroke()
                                    ctx.beginPath()
                                    ctx.moveTo(x + 34 + offset, y + 4)
                                    ctx.lineTo(x + 34 + offset - 5, y + 4 + length)
                                    ctx.stroke()
                                }
                            }

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                if (!items || items.length === 0)
                                    return

                                for (let h = 0; h < items.length; h++) {
                                    const alpha = rainAlpha(items[h])
                                    if (alpha <= 0)
                                        continue
                                    ctx.fillStyle = Theme.withAlpha(Theme.primary, alpha)
                                    ctx.fillRect(h * itemWidth, 0, itemWidth, height)
                                    drawRainStreaks(ctx, h * itemWidth, alpha, items[h].precipitation || 0)
                                }

                                let minTemp = items[0].temperature
                                let maxTemp = items[0].temperature
                                for (let i = 1; i < items.length; i++) {
                                    minTemp = Math.min(minTemp, items[i].temperature)
                                    maxTemp = Math.max(maxTemp, items[i].temperature)
                                }

                                ctx.beginPath()
                                ctx.moveTo(pointX(0), pointY(items[0], minTemp, maxTemp))
                                for (let j = 1; j < items.length; j++) {
                                    ctx.lineTo(pointX(j), pointY(items[j], minTemp, maxTemp))
                                }
                                ctx.strokeStyle = Theme.primary
                                ctx.lineWidth = 2
                                ctx.stroke()

                                ctx.fillStyle = Theme.primary
                                for (let k = 0; k < items.length; k++) {
                                    const x = pointX(k)
                                    const y = pointY(items[k], minTemp, maxTemp)
                                    ctx.beginPath()
                                    ctx.arc(x, y, items[k].isCurrent ? 4 : 3, 0, Math.PI * 2)
                                    ctx.fill()
                                }
                            }
                        }

                        Repeater {
                            model: hourlyFlickable.items

                            delegate: Item {
                                width: hourlyFlickable.itemWidth
                                height: hourlyChart.height
                                x: index * hourlyFlickable.itemWidth

                                readonly property real minTemp: {
                                    let value = hourlyFlickable.items.length > 0 ? hourlyFlickable.items[0].temperature : 0
                                    for (let i = 1; i < hourlyFlickable.items.length; i++)
                                        value = Math.min(value, hourlyFlickable.items[i].temperature)
                                    return value
                                }
                                readonly property real maxTemp: {
                                    let value = hourlyFlickable.items.length > 0 ? hourlyFlickable.items[0].temperature : 0
                                    for (let i = 1; i < hourlyFlickable.items.length; i++)
                                        value = Math.max(value, hourlyFlickable.items[i].temperature)
                                    return value
                                }
                                readonly property real chartY: 22 + (maxTemp - modelData.temperature) / Math.max(1, maxTemp - minTemp) * 54

                                StyledText {
                                    text: `${modelData.temperature}°`
                                    color: modelData.isPast ? Theme.surfaceVariantText : Theme.primary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: modelData.isCurrent ? Font.Bold : Font.Medium
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: Math.max(0, chartY - 20)
                                }

                                Column {
                                    y: 82
                                    width: parent.width
                                    spacing: 2

                                    StyledText {
                                        width: parent.width
                                        text: Caiyun.CaiyunWeatherService.skyconText(modelData.skycon)
                                        color: modelData.isPast ? Theme.surfaceVariantText : Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }

                                    DankIcon {
                                        name: Caiyun.CaiyunWeatherService.skyconIcon(modelData.skycon)
                                        color: modelData.isPast ? Theme.surfaceVariantText : Theme.primary
                                        size: Theme.iconSizeSmall
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    Item {
                                        width: parent.width
                                        height: probabilityText.implicitHeight

                                        StyledText {
                                            id: probabilityText
                                            text: modelData.probability > 0 ? `${modelData.probability}%` : ""
                                            color: modelData.isPast ? Theme.surfaceVariantText : Theme.primary
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }

                                    StyledText {
                                        text: modelData.isCurrent ? "现在" : modelData.time
                                        color: modelData.isCurrent ? Theme.surfaceText : Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: modelData.isCurrent ? Font.Bold : Font.Normal
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 3
                    columnSpacing: Theme.spacingS
                    rowSpacing: Theme.spacingS
                    visible: root.hasWeather

                    Repeater {
                        model: [
                            {
                                "icon": "humidity_low",
                                "label": "湿度",
                                "value": `${Math.round((Caiyun.CaiyunWeatherService.current?.humidity || 0) * 100)}%`
                            },
                            {
                                "icon": "rainy",
                                "label": "降水",
                                "value": `${root.rainProbability}%`
                            },
                            {
                                "icon": "speed",
                                "label": "气压",
                                "value": `${Math.round((Caiyun.CaiyunWeatherService.current?.pressure || 0) / 100)} hPa`
                            },
                            {
                                "icon": "visibility",
                                "label": "能见度",
                                "value": `${Math.round(Caiyun.CaiyunWeatherService.current?.visibility || 0)} km`
                            },
                            {
                                "icon": "cloud",
                                "label": "云量",
                                "value": `${Math.round((Caiyun.CaiyunWeatherService.current?.cloudrate || 0) * 100)}%`
                            },
                            {
                                "icon": "schedule",
                                "label": "更新",
                                "value": Caiyun.CaiyunWeatherService.formatTime(Caiyun.CaiyunWeatherService.lastUpdated)
                            }
                        ]

                        delegate: StyledRect {
                            width: (parent.width - Theme.spacingS * 2) / 3
                            height: 64
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainer

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - Theme.spacingS * 2
                                spacing: 2

                                StyledText {
                                    width: parent.width
                                    text: modelData.value
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    text: modelData.label
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    text: "未来 7 天"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    visible: root.hasWeather
                }

                Flickable {
                    id: dailyFlickable

                    width: parent.width
                    height: 184
                    contentWidth: dailyChart.width
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    visible: root.hasWeather

                    readonly property var items: Caiyun.CaiyunWeatherService.dailyItems(7)
                    readonly property int itemWidth: 72

                    StyledRect {
                        id: dailyChart

                        width: Math.max(dailyFlickable.width, dailyFlickable.items.length * dailyFlickable.itemWidth)
                        height: dailyFlickable.height
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainer

                        Canvas {
                            id: dailyTemperatureLine

                            anchors.fill: parent
                            property var items: dailyFlickable.items
                            property int itemWidth: dailyFlickable.itemWidth
                            property real topPadding: 32
                            property real chartHeight: 54

                            onItemsChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            function pointX(index) {
                                return index * itemWidth + itemWidth / 2
                            }

                            function highY(item, minTemp, maxTemp) {
                                const range = Math.max(1, maxTemp - minTemp)
                                return topPadding + (maxTemp - item.max) / range * chartHeight
                            }

                            function lowY(item, minTemp, maxTemp) {
                                const range = Math.max(1, maxTemp - minTemp)
                                return topPadding + (maxTemp - item.min) / range * chartHeight
                            }

                            function drawLine(ctx, valueFn, color, widthValue) {
                                ctx.beginPath()
                                ctx.moveTo(pointX(0), valueFn(items[0]))
                                for (let i = 1; i < items.length; i++) {
                                    ctx.lineTo(pointX(i), valueFn(items[i]))
                                }
                                ctx.strokeStyle = color
                                ctx.lineWidth = widthValue
                                ctx.stroke()
                            }

                            function rainAlpha(item) {
                                const probability = item.probability || 0
                                const looksRainy = item.skycon && item.skycon.indexOf("RAIN") !== -1
                                if (probability <= 0 && !looksRainy)
                                    return 0
                                return Math.max(0.05, Math.min(0.20, 0.04 + probability / 700))
                            }

                            function drawRainStreaks(ctx, x, alpha, probability) {
                                const dense = probability >= 60
                                const spacing = dense ? 12 : 16
                                const length = dense ? 14 : 10
                                ctx.strokeStyle = Theme.withAlpha(Theme.primary, Math.min(0.18, alpha + 0.03))
                                ctx.lineWidth = 1
                                for (let y = 12; y < height - 10; y += spacing) {
                                    const offset = ((y / spacing) % 2) * 10
                                    ctx.beginPath()
                                    ctx.moveTo(x + 14 + offset, y)
                                    ctx.lineTo(x + 14 + offset - 5, y + length)
                                    ctx.stroke()
                                    ctx.beginPath()
                                    ctx.moveTo(x + 44 + offset, y + 5)
                                    ctx.lineTo(x + 44 + offset - 5, y + 5 + length)
                                    ctx.stroke()
                                }
                            }

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                if (!items || items.length === 0)
                                    return

                                for (let h = 0; h < items.length; h++) {
                                    const alpha = rainAlpha(items[h])
                                    if (alpha <= 0)
                                        continue
                                    ctx.fillStyle = Theme.withAlpha(Theme.primary, alpha)
                                    ctx.fillRect(h * itemWidth, 0, itemWidth, height)
                                    drawRainStreaks(ctx, h * itemWidth, alpha, items[h].probability || 0)
                                }

                                let minTemp = items[0].min
                                let maxTemp = items[0].max
                                for (let i = 1; i < items.length; i++) {
                                    minTemp = Math.min(minTemp, items[i].min)
                                    maxTemp = Math.max(maxTemp, items[i].max)
                                }

                                drawLine(ctx, item => highY(item, minTemp, maxTemp), Theme.primary, 2)
                                drawLine(ctx, item => lowY(item, minTemp, maxTemp), Theme.withAlpha(Theme.primary, 0.45), 2)

                                for (let j = 0; j < items.length; j++) {
                                    const x = pointX(j)
                                    ctx.fillStyle = Theme.primary
                                    ctx.beginPath()
                                    ctx.arc(x, highY(items[j], minTemp, maxTemp), 3, 0, Math.PI * 2)
                                    ctx.fill()

                                    ctx.fillStyle = Theme.withAlpha(Theme.primary, 0.55)
                                    ctx.beginPath()
                                    ctx.arc(x, lowY(items[j], minTemp, maxTemp), 3, 0, Math.PI * 2)
                                    ctx.fill()
                                }
                            }
                        }

                        Repeater {
                            model: dailyFlickable.items

                            delegate: Item {
                                width: dailyFlickable.itemWidth
                                height: dailyChart.height
                                x: index * dailyFlickable.itemWidth

                                readonly property real minTemp: {
                                    let value = dailyFlickable.items.length > 0 ? dailyFlickable.items[0].min : 0
                                    for (let i = 1; i < dailyFlickable.items.length; i++)
                                        value = Math.min(value, dailyFlickable.items[i].min)
                                    return value
                                }
                                readonly property real maxTemp: {
                                    let value = dailyFlickable.items.length > 0 ? dailyFlickable.items[0].max : 0
                                    for (let i = 1; i < dailyFlickable.items.length; i++)
                                        value = Math.max(value, dailyFlickable.items[i].max)
                                    return value
                                }
                                readonly property real highY: 32 + (maxTemp - modelData.max) / Math.max(1, maxTemp - minTemp) * 54
                                readonly property real lowY: 32 + (maxTemp - modelData.min) / Math.max(1, maxTemp - minTemp) * 54

                                StyledText {
                                    text: `${modelData.max}°`
                                    color: Theme.primary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: index === 0 ? Font.Bold : Font.Medium
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: Math.max(0, highY - 20)
                                }

                                StyledText {
                                    text: `${modelData.min}°`
                                    color: Theme.withAlpha(Theme.primary, 0.75)
                                    font.pixelSize: Theme.fontSizeSmall
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: Math.min(parent.height - 96, lowY + 6)
                                }

                                Column {
                                    y: 104
                                    width: parent.width
                                    spacing: 2

                                    StyledText {
                                        text: index === 0 ? "今天" : modelData.day
                                        color: index === 0 ? Theme.surfaceText : Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: index === 0 ? Font.Bold : Font.Normal
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: modelData.date
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    DankIcon {
                                        name: Caiyun.CaiyunWeatherService.skyconIcon(modelData.skycon)
                                        color: Theme.primary
                                        size: Theme.iconSizeSmall
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: {
                                            const parts = []
                                            if (modelData.probability > 0)
                                                parts.push(`${modelData.probability}%`)
                                            const aqi = Caiyun.CaiyunWeatherService.aqiText(modelData.aqi)
                                            if (aqi !== "--" && !aqi.endsWith("优"))
                                                parts.push(aqi)
                                            return parts.join(" · ")
                                        }
                                        visible: text !== ""
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: !root.hasWeather

                    DankIcon {
                        name: "cloud_off"
                        color: Theme.surfaceVariantText
                        size: Theme.iconSize * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        width: parent.width
                        text: Caiyun.CaiyunWeatherService.configured ? Caiyun.CaiyunWeatherService.statusText : "Open plugin settings and enter Caiyun token plus longitude/latitude."
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeMedium
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
