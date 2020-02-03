local WIFI_STATUS = {
    [wifi.STA_IDLE] = "idle",
    [wifi.STA_CONNECTING] = "connecting",
    [wifi.STA_WRONGPWD] = "wrong password",
    [wifi.STA_APNOTFOUND] = "AP not found",
    [wifi.STA_FAIL] = "failed",
    [wifi.STA_GOTIP] = "got IP"
}

function init()

    board = sjson.decode([[
        {
            "ledPin": 4
        }
    ]])

    local smartConfigStarted = false
    local lastWifiStatus = wifi.STA_IDLE
    local blinkTimer

    function checkWifi()
        local status = wifi.sta.status()

        if status ~= lastWifiStatus then
            print("WiFi status: " .. WIFI_STATUS[lastWifiStatus] .. " -> " ..
                      WIFI_STATUS[status])
            lastWifiStatus = status
        end

        if status == wifi.STA_GOTIP and smartConfigStarted then
            print("Stopping SmartConfig")
            wifi.stopsmart()
            smartConfigStarted = false;
            blinkTimer:unregister()
            blinkTimer = nil
            gpio.write(board.ledPin, gpio.HIGH)
        end

        if status ~= wifi.STA_CONNECTING and status ~= wifi.STA_GOTIP and
            not smartConfigStarted then
            print("Starting SmartConfig")
            wifi.startsmart()
            smartConfigStarted = true;
            blinkTimer = tmr.create()
            blinkTimer:alarm(100, tmr.ALARM_AUTO, function(t)
                gpio.write(board.ledPin, gpio.read(board.ledPin) == 1 and 0 or 1)
            end)
        end
    end

    wifi.setmode(wifi.STATION)

    gpio.write(board.ledPin, gpio.HIGH)
    gpio.mode(board.ledPin, gpio.OUTPUT)

    tmr.create():alarm(5000, tmr.ALARM_AUTO, function(t) checkWifi(); end)

    checkWifi()

    print("Core initialized.")
end

local status, err = pcall(init)

if not status then
    print("Unhandled error: " .. err)
    print("Rebooting in 5 seconds...")
    tmr.create():alarm(5000, tmr.ALARM_SINGLE, function(t)
        print("Rebooting now.")
        node.restart()
    end)
end
