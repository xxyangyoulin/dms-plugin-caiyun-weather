pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property string pluginId: "caiyunWeather"
    readonly property bool configured: token !== "" && longitude !== "" && latitude !== ""
    readonly property bool stale: lastUpdated > 0 && Date.now() - lastUpdated > refreshIntervalMinutes * 60000 * 2
    readonly property var current: weather?.result?.realtime || null
    readonly property var daily: weather?.result?.daily || null
    readonly property var hourly: weather?.result?.hourly || null
    readonly property var alertContent: weather?.result?.alert?.content || []
    readonly property bool hasAlert: alertContent.length > 0
    readonly property string keypoint: weather?.result?.forecast_keypoint || ""
    readonly property string skycon: current?.skycon || ""
    readonly property int temperature: current ? Math.round(current.temperature) : 0
    readonly property int apparentTemperature: current ? Math.round(current.apparent_temperature ?? current.temperature) : 0
    readonly property int aqi: {
        const value = current?.air_quality?.aqi?.chn ?? current?.air_quality?.aqi?.usa ?? 0
        return Math.round(value)
    }
    readonly property string statusText: {
        if (!configured)
            return "Not configured";
        if (nightUpdatePaused && isNightPauseActive())
            return "Night updates paused";
        if (loading)
            return available ? "Updating" : "Loading";
        if (errorMessage !== "")
            return errorMessage;
        if (!available)
            return "No weather data";
        return "Updated " + formatTime(lastUpdated);
    }

    property string token: ""
    property string locationName: ""
    property string longitude: ""
    property string latitude: ""
    property string language: "zh_CN"
    property int refreshIntervalMinutes: 15
    property bool nightUpdatePaused: false
    property real lastFetchAttempt: 0
    property real lastManualRefresh: 0
    property real lastUpdated: 0
    property bool loading: false
    property bool available: false
    property string errorMessage: ""
    property var weather: ({})
    property var hourlyHistory: []

    Component.onCompleted: {
        loadSettings()
    }

    Connections {
        target: PluginService

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId) {
                root.loadSettings()
            }
        }
    }

    Timer {
        interval: Math.max(5, root.refreshIntervalMinutes) * 60000
        repeat: true
        running: root.configured
        onTriggered: root.refresh()
    }

    function loadSettings() {
        token = PluginService.loadPluginData(pluginId, "token", "")
        locationName = PluginService.loadPluginData(pluginId, "locationName", "")
        longitude = PluginService.loadPluginData(pluginId, "longitude", "")
        latitude = PluginService.loadPluginData(pluginId, "latitude", "")
        language = PluginService.loadPluginData(pluginId, "language", "zh_CN")
        refreshIntervalMinutes = PluginService.loadPluginData(pluginId, "refreshIntervalMinutes", 15)
        nightUpdatePaused = PluginService.loadPluginData(pluginId, "nightUpdatePaused", false)

        const cached = PluginService.loadPluginState(pluginId, "weather", null)
        const cachedAt = PluginService.loadPluginState(pluginId, "lastUpdated", 0)
        hourlyHistory = normalizeHourlyHistory(PluginService.loadPluginState(pluginId, "hourlyHistory", []))
        if (cached) {
            weather = cached
            lastUpdated = cachedAt > 1000000000000 ? cachedAt : ((cached.server_time || 0) * 1000)
            available = true
        }
    }

    function refresh(force) {
        if (!configured)
            return
        if (loading)
            return
        if (!force && nightUpdatePaused && isNightPauseActive())
            return

        const now = Date.now()
        if (!force && now - lastFetchAttempt < 30000)
            return

        lastFetchAttempt = now
        loading = true
        errorMessage = ""

        const url = `https://api.caiyunapp.com/v2.6/${encodeURIComponent(token)}/${longitude},${latitude}/weather?alert=true&hourlysteps=72&dailysteps=7&lang=${language}&unit=metric`
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            loading = false
            if (xhr.status >= 200 && xhr.status < 300) {
                handleResponse(xhr.responseText)
                return
            }

            handleFailure("Weather request failed")
        }
        xhr.timeout = 8000
        xhr.ontimeout = function () {
            loading = false
            handleFailure("Weather request timed out")
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function manualRefresh() {
        const now = Date.now()
        if (now - lastManualRefresh < 30000)
            return
        lastManualRefresh = now
        refresh(true)
    }

    function isNightPauseActive() {
        const hour = new Date().getHours()
        return hour >= 18 || hour < 9
    }

    function handleResponse(text) {
        try {
            const data = JSON.parse(text)
            if (data.status !== "ok")
                throw new Error(data.status || "Bad response")

            weather = data
            available = true
            lastUpdated = Date.now()
            updateHourlyHistory(data)
            PluginService.savePluginState(pluginId, "weather", data)
            PluginService.savePluginState(pluginId, "lastUpdated", lastUpdated)
        } catch (e) {
            handleFailure("Could not parse weather data")
        }
    }

    function handleFailure(message) {
        errorMessage = message
        available = Object.keys(weather || {}).length > 0
    }

    function skyconIcon(value) {
        const icons = {
            "CLEAR_DAY": "clear_day",
            "CLEAR_NIGHT": "clear_night",
            "PARTLY_CLOUDY_DAY": "partly_cloudy_day",
            "PARTLY_CLOUDY_NIGHT": "partly_cloudy_night",
            "CLOUDY": "cloud",
            "LIGHT_HAZE": "foggy",
            "MODERATE_HAZE": "foggy",
            "HEAVY_HAZE": "foggy",
            "LIGHT_RAIN": "rainy",
            "MODERATE_RAIN": "rainy",
            "HEAVY_RAIN": "rainy_heavy",
            "STORM_RAIN": "thunderstorm",
            "FOG": "foggy",
            "LIGHT_SNOW": "cloudy_snowing",
            "MODERATE_SNOW": "cloudy_snowing",
            "HEAVY_SNOW": "snowing_heavy",
            "STORM_SNOW": "snowing_heavy",
            "DUST": "air",
            "SAND": "air",
            "WIND": "air"
        }
        return icons[value] || "cloud"
    }

    function skyconText(value) {
        const text = {
            "CLEAR_DAY": "晴",
            "CLEAR_NIGHT": "晴",
            "PARTLY_CLOUDY_DAY": "多云",
            "PARTLY_CLOUDY_NIGHT": "多云",
            "CLOUDY": "阴",
            "LIGHT_HAZE": "轻度雾霾",
            "MODERATE_HAZE": "中度雾霾",
            "HEAVY_HAZE": "重度雾霾",
            "LIGHT_RAIN": "小雨",
            "MODERATE_RAIN": "中雨",
            "HEAVY_RAIN": "大雨",
            "STORM_RAIN": "暴雨",
            "FOG": "雾",
            "LIGHT_SNOW": "小雪",
            "MODERATE_SNOW": "中雪",
            "HEAVY_SNOW": "大雪",
            "STORM_SNOW": "暴雪",
            "DUST": "浮尘",
            "SAND": "沙尘",
            "WIND": "大风"
        }
        return text[value] || value || "--"
    }

    function precipitationProbability() {
        const items = hourly?.precipitation || []
        if (items.length === 0)
            return 0
        return formatProbability(items[0].probability || 0)
    }

    function formatProbability(value) {
        const normalizedValue = value > 100 ? value / 100 : value
        const percent = normalizedValue <= 1 ? normalizedValue * 100 : normalizedValue
        return Math.max(0, Math.min(100, Math.round(percent)))
    }

    function normalizeHourlyHistory(items) {
        if (!items || !Array.isArray(items))
            return []
        return items.map(item => Object.assign({}, item, {
            "probability": formatProbability(item.probability || 0),
            "precipitation": item.precipitation || 0
        }))
    }

    function hourlyItems(limit) {
        const now = Date.now()
        const currentHour = new Date()
        currentHour.setMinutes(0, 0, 0)
        const currentHourTime = currentHour.getTime()
        const sixHoursAgo = now - 6 * 60 * 60 * 1000
        const past = []
        const future = []
        const precipitationByTime = hourlyPrecipitationByTime()

        for (let i = 0; i < hourlyHistory.length; i++) {
            const item = hourlyHistory[i]
            const timestamp = Date.parse(item.datetime)
            if (!timestamp || timestamp < sixHoursAgo)
                continue
            const precipitationValue = item.precipitation || precipitationByTime[item.datetime] || 0
            if (timestamp < currentHourTime) {
                past.push(Object.assign({}, item, {
                    "precipitation": precipitationValue,
                    "probability": formatProbability(item.probability || 0),
                    "isPast": true,
                    "isCurrent": false
                }))
            } else {
                future.push(Object.assign({}, item, {
                    "precipitation": precipitationValue,
                    "probability": formatProbability(item.probability || 0),
                    "isPast": false,
                    "isCurrent": false
                }))
            }
        }

        past.sort((a, b) => Date.parse(a.datetime) - Date.parse(b.datetime))
        future.sort((a, b) => Date.parse(a.datetime) - Date.parse(b.datetime))

        const result = past.concat(future.slice(0, limit))
        const currentIndex = firstCurrentHourlyIndex(result)
        if (currentIndex >= 0)
            result[currentIndex].isCurrent = true
        return result
    }

    function hourlyPrecipitationByTime() {
        const result = {}
        const items = hourly?.precipitation || []
        for (let i = 0; i < items.length; i++) {
            if (items[i]?.datetime)
                result[items[i].datetime] = items[i].value || 0
        }
        return result
    }

    function updateHourlyHistory(data) {
        const temps = data?.result?.hourly?.temperature || []
        const skycons = data?.result?.hourly?.skycon || []
        const precipitation = data?.result?.hourly?.precipitation || []
        const byTime = {}

        for (let i = 0; i < hourlyHistory.length; i++) {
            const item = hourlyHistory[i]
            if (item?.datetime)
                byTime[item.datetime] = item
        }

        for (let j = 0; j < temps.length; j++) {
            const datetime = temps[j].datetime
            if (!datetime)
                continue
            byTime[datetime] = {
                "datetime": datetime,
                "time": formatHour(datetime),
                "temperature": Math.round(temps[j].value),
                "skycon": skycons[j]?.value || skycon,
                "precipitation": precipitation[j]?.value || 0,
                "probability": formatProbability(precipitation[j]?.probability || 0)
            }
        }

        const cutoff = Date.now() - 6 * 60 * 60 * 1000
        const merged = Object.keys(byTime).map(key => byTime[key]).filter(item => Date.parse(item.datetime) >= cutoff)
        merged.sort((a, b) => Date.parse(a.datetime) - Date.parse(b.datetime))
        hourlyHistory = merged
        PluginService.savePluginState(pluginId, "hourlyHistory", hourlyHistory)
    }

    function firstCurrentHourlyIndex(items) {
        const currentHour = new Date()
        currentHour.setMinutes(0, 0, 0)
        const currentHourTime = currentHour.getTime()
        for (let i = 0; i < items.length; i++) {
            if (Date.parse(items[i].datetime) === currentHourTime)
                return i
        }
        for (let j = 0; j < items.length; j++) {
            if (Date.parse(items[j].datetime) > currentHourTime)
                return j
        }
        return items.length > 0 ? items.length - 1 : -1
    }

    function dailyItems(limit) {
        const result = []
        const temps = daily?.temperature || []
        const skycons = daily?.skycon || []
        const precipitation = daily?.precipitation || []
        for (let i = 0; i < Math.min(limit, temps.length); i++) {
            result.push({
                "day": formatDay(temps[i].date),
                "date": formatMonthDay(temps[i].date),
                "min": Math.round(temps[i].min),
                "max": Math.round(temps[i].max),
                "skycon": skycons[i]?.value || skycon,
                "probability": formatProbability(precipitation[i]?.probability || 0),
                "aqi": dailyAqi(i)
            })
        }
        return result
    }

    function dailyAqi(index) {
        const items = daily?.air_quality?.aqi || []
        const value = items[index]?.avg?.chn ?? items[index]?.avg?.usa ?? 0
        return Math.round(value)
    }

    function aqiText(value) {
        if (!value)
            return "--"
        if (value <= 50)
            return `${value}优`
        if (value <= 100)
            return `${value}良`
        if (value <= 150)
            return `${value}轻度`
        if (value <= 200)
            return `${value}中度`
        return `${value}重度`
    }

    function sunriseText() {
        return daily?.astro?.[0]?.sunrise?.time || "--"
    }

    function sunsetText() {
        return daily?.astro?.[0]?.sunset?.time || "--"
    }

    function todaySunriseTimestamp() {
        return todayTimeToTimestamp(sunriseText())
    }

    function todaySunsetTimestamp() {
        return todayTimeToTimestamp(sunsetText())
    }

    function todayTimeToTimestamp(value) {
        if (!value || value === "--")
            return 0
        const parts = value.split(":")
        if (parts.length < 2)
            return 0
        const date = new Date()
        date.setHours(parseInt(parts[0]), parseInt(parts[1]), 0, 0)
        return date.getTime()
    }

    function formatTime(timestamp) {
        if (!timestamp)
            return "--"
        return new Date(timestamp).toLocaleTimeString(Qt.locale(), "HH:mm")
    }

    function formatHour(value) {
        return new Date(value).toLocaleTimeString(Qt.locale(), "HH:mm")
    }

    function formatDay(value) {
        return new Date(value).toLocaleDateString(Qt.locale(), "ddd")
    }

    function formatMonthDay(value) {
        return new Date(value).toLocaleDateString(Qt.locale(), "MM/dd")
    }

    function windText() {
        const wind = current?.wind
        if (!wind)
            return "--"
        return `${directionText(wind.direction)} ${Math.round(wind.speed)} km/h`
    }

    function directionText(deg) {
        const directions = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
        return directions[Math.round(((deg % 360) / 45)) % 8]
    }
}
