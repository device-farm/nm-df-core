local WIFI_STATUS = {
    [wifi.STA_IDLE] = "idle",
    [wifi.STA_CONNECTING] = "connecting",
    [wifi.STA_WRONGPWD] = "wrong password",
    [wifi.STA_APNOTFOUND] = "AP not found",
    [wifi.STA_FAIL] = "failed",
    [wifi.STA_GOTIP] = "got IP"
}

function init()

    df = {}

    local boardFunction = node.flashindex("board")
    if type(boardFunction) ~= "function" then error("No board module found") end

    df.board = boardFunction()

    local smartConfigStarted = false
    local lastWifiStatus = wifi.STA_IDLE
    local ledState = false
    local blinkTimer

    function startSmartConfig()
        if not smartConfigStarted then
            print("Starting WiFi SmartConfig")
            wifi.startsmart(function() smartConfigStarted = false end)
            smartConfigStarted = true
        end
    end

    function setLed(state)
        if (df.board.ledPin) then
            ledState = state

            if (state) then
                gpio.write(df.board.ledPin, gpio.LOW)
                gpio.mode(df.board.ledPin, gpio.OUTPUT)
            else
                gpio.mode(df.board.ledPin, gpio.INT, gpio.PULLUP)
                gpio.trig(df.board.ledPin, "up", startSmartConfig)
            end
        end
    end

    function checkWifi()
        local status = wifi.sta.status()

        if status ~= lastWifiStatus then
            print("WiFi status: " .. WIFI_STATUS[lastWifiStatus] .. " -> " ..
                      WIFI_STATUS[status])
            lastWifiStatus = status
        end

        if status == wifi.STA_GOTIP and blinkTimer then
            blinkTimer:unregister()
            blinkTimer = nil
            setLed(false)
        end

        if status ~= wifi.STA_GOTIP and not blinkTimer then
            blinkTimer = tmr.create()
            blinkTimer:alarm(smartConfigStarted and 500 or 100, tmr.ALARM_AUTO,
                             function(t) setLed(not ledState) end)
        end
    end

    setLed(false)

    wifi.setmode(wifi.STATION)

    for _, e in pairs({
        wifi.eventmon.STA_CONNECTED, wifi.eventmon.STA_DISCONNECTED,
        wifi.eventmon.STA_AUTHMODE_CHANGE, wifi.eventmon.STA_GOT_IP,
        wifi.eventmon.STA_DHCP_TIMEOUT, wifi.eventmon.AP_STACONNECTED,
        wifi.eventmon.AP_STADISCONNECTED, wifi.eventmon.AP_PROBEREQRECVED
    }) do wifi.eventmon.register(e, checkWifi) end

    checkWifi()

    print("Core initialized.")

    local application = node.flashindex("application")
    if type(application) ~= "function" then
        error("No application module found")
    end

    application()

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
