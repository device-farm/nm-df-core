print("LFS !")

local WIFI_STATUS = {
    [wifi.STA_IDLE] = "idle",
    [wifi.STA_CONNECTING] = "connecting",
    [wifi.STA_WRONGPWD] = "wrong password",
    [wifi.STA_APNOTFOUND] = "AP not found",
    [wifi.STA_FAIL] = "failed",
    [wifi.STA_GOTIP] = "got IP"
}

function init()

    local smartConfigStarted = false

    function checkWifi()
        local status = wifi.sta.status()
        print("WiFi status: " .. WIFI_STATUS[status])

        if status == wifi.STA_CONNECTING or status == wifi.STA_GOTIP then
            if smartConfigStarted then
                print("Stopping SmartConfig")
                wifi.stopsmart()
                smartConfigStarted = false;
            end
        else
            if not smartConfigStarted then
                print("Starting SmartConfig")
                wifi.startsmart()
                smartConfigStarted = true;
            end
        end
    end

    wifi.setmode(wifi.STATION)

    tmr.create():alarm(5000, tmr.ALARM_AUTO, function(t) checkWifi(); end)

    checkWifi()

    print("Core initialized.")

    -- board = sjson.decode([[
    --     {
    --         "ledPin": 4
    --     }
    -- ]])

    -- gpio.mode(board.ledPin, gpio.OUTPUT)
    -- gpio.write(board.ledPin, gpio.LOW)
    -- print("Tak co?"..board.ledPin)
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
