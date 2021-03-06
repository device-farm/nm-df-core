local WIFI_STATUS = {
    [wifi.STA_IDLE] = "idle",
    [wifi.STA_CONNECTING] = "connecting",
    [wifi.STA_WRONGPWD] = "wrong password",
    [wifi.STA_APNOTFOUND] = "AP not found",
    [wifi.STA_FAIL] = "failed",
    [wifi.STA_GOTIP] = "got IP"
}

function init()

    local configFunction = node.flashindex("generated-config")
    if type(configFunction) ~= "function" then error("No generated config module found") end

    df = {
        config = configFunction()
    }

    local wifiLedPin = df.config.wifiLedPin();

    local smartConfigStarted = false
    local lastWifiStatus = wifi.STA_IDLE

    local ledState = false
    local blinkTimer
    local blinkPeriod = 0

    function startSmartConfig()
        if not smartConfigStarted then
            print("Starting WiFi SmartConfig")
            smartConfigStarted = true
            updateBlink()
            wifi.startsmart(function() 
                smartConfigStarted = false 
                updateBlink()
            end)
        end
    end

    function setLed(state)
        if (wifiLedPin) then
            ledState = state

            if (state) then
                gpio.write(wifiLedPin, gpio.LOW)
                gpio.mode(wifiLedPin, gpio.OUTPUT)
            else
                gpio.mode(wifiLedPin, gpio.INT, gpio.PULLUP)
                gpio.trig(wifiLedPin, "up", startSmartConfig)
            end
        end
    end

    function blink(period)        
        if (period ~= blinkPeriod) then

            blinkPeriod = period

            if blinkTimer then
                blinkTimer:unregister()
                blinkTimer = nil
                setLed(false)
            end
            if period > 0 then
                blinkTimer = tmr.create()
                blinkTimer:alarm(period, tmr.ALARM_AUTO,
                                 function(t) setLed(not ledState) end)
            end
        end
    end

    function updateBlink()
        local status = wifi.sta.status()
        blink(smartConfigStarted and 500 or (status == wifi.STA_GOTIP and 0 or 100))
    end

    function checkWifi()
        local status = wifi.sta.status()

        if status ~= lastWifiStatus then
            print("WiFi status: " .. WIFI_STATUS[lastWifiStatus] .. " -> " ..
                      WIFI_STATUS[status])
            lastWifiStatus = status
        end

        updateBlink();
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
