-- this is a comment
print("Timer")

--------------------------------------------
-- GPIO Setup
--------------------------------------------
print("Setting Up GPIO...")

-- Note: Pin index starts at 0 (for D0 or equivalent pin function)
led_pin = 3
relais_out_pin = 4
gpio.mode(led_pin, gpio.OUTPUT)
gpio.mode(relais_out_pin, gpio.OUTPUT)

function switchOn()
    gpio.write(relais_out_pin, gpio.HIGH)
end

function switchOff()
    gpio.write(relais_out_pin, gpio.LOW)
end
switchOn()

-- PWM for LED 'led_pin'
pwm_frequency = 200
pwm_duty_MIN = 1
pwm_duty_MAX = 1000 -- actually we could go up to 1023, but there's flickering then somehow.
pwm_duty = pwm_duty_MIN
pwm.setup(led_pin, pwm_frequency, pwm_duty_MIN)
pwm.start(led_pin)

------------------
-- STATES  --
------------------
-- 0: off, 1: on, 2: timer
relais_state = 2
-- initial delay (FIXME TODO: persist in flash)
seconds_until_switchoff = 1800
seconds_until_switchoff_counter = seconds_until_switchoff

pwm_percent = 0

----------------
-- Timers     --
----------------
timer1_id = 0
timer1_timeout_millis = 1000
tmr.register(timer1_id, timer1_timeout_millis, tmr.ALARM_SEMI, function()
    -- LOG --
    print("tick")
    print("  -> relais_state: " .. (relais_state or "?"))
    print("  -> seconds_until_switchoff_counter: " .. (seconds_until_switchoff_counter or "?"))
    
    -- railais_state --
    if tonumber(relais_state) == 2 then
        seconds_until_switchoff_counter = seconds_until_switchoff_counter-1
        if seconds_until_switchoff_counter < 0 then 
            relais_state = 0
            seconds_until_switchoff_counter = 0
            switchOff()
        else
            switchOn()
        end

        -- PWM
        pwm_duty = pwm_duty_MIN + 
                   pwm_duty_MAX * seconds_until_switchoff_counter / seconds_until_switchoff
        -- /PWM
        
    elseif tonumber(relais_state) == 1 then
        switchOn()
        -- PWM
        pwm_duty = pwm_duty_MAX
        -- /PWM
    elseif tonumber(relais_state) == 0 then
        switchOff()
        -- PWM
        pwm_duty = 20
        -- /PWM
    else
        print(" weird relais_state: " .. relais_state or "nil")
        relais_state = 0
    end

    tmr.start(timer1_id)
end)
tmr.start(timer1_id)
print(" timer1 started");




nextPWM = 1
countdirection = 1  -- 1=up 2=down
speed = 5
function getNextPWM()
    -- count up or down
    if countdirection==1 then
        nextPWM = nextPWM + speed
    elseif countdirection==2 then
        nextPWM = nextPWM - speed
    else
        print("EEEERRRROOOOOORRRR")
    end

    -- check overflow and change directions
    if nextPWM < pwm_duty_MIN then 
        --print("  whoops, underflow. counting up now...")
        nextPWM = pwm_duty_MIN
        countdirection = 1
    elseif nextPWM > pwm_duty then
        --print("  whoops, overrflow. counting down now...")
        nextPWM = pwm_duty
        countdirection = 2
    end
    
    --print("  nextPWM: " .. nextPWM)
    return nextPWM
end

-- TIMER 2 (pwm pulse)
timer2_id = 1
timer2_timeout_millis = 50
tmr.register(timer2_id, timer2_timeout_millis, tmr.ALARM_SEMI, function()
    pwm.setduty(led_pin, getNextPWM())
    
    tmr.interval(timer2_id, timer2_timeout_millis)
    tmr.start(timer2_id)
end)
tmr.start(timer2_id)
print(" timer2 started");

----------------
-- Init Wifi  --
----------------
print("Wifi Station Setup")
print("-- current AP cfg --")
print(wifi.ap.getmac())
print(wifi.ap.getip())
print(wifi.ap.getbroadcast())
print("-- current STATION cfg --")
print(wifi.sta.getmac())
print(wifi.sta.getip())

-- setup station mode
wifi.setmode(wifi.STATION)
-- less energy consumption
wifi.setphymode(wifi.PHYMODE_G)
-- edit config
WIFI_SSID = "Turminator"
WIFI_PASSWORD = "lkwpeter,.-123"
wifi.sta.config(WIFI_SSID, WIFI_PASSWORD) 
wifi.sta.connect()

-- register listener to see if we're connected
wifi.sta.eventMonReg(wifi.STA_GOTIP, function() print("STATION_GOT_IP") end)
 
----------------
-- Web Server --
----------------
print("Starting Web Server...")
-- a simple HTTP server
if srv~=nil then
  print("found an open server. closing it...")
  srv:close()
  print("done. now tyring to start...")
end

function Sendfile(sck, filename, sentCallback)
    print("opening file "..filename.."...")
    if not file.open(filename, "r") then
        sck:close()
        return
    end
    local function sendChunk()
        local line = file.read(512)
        if (line and #line>0) then 
            sck:send(line, sendChunk) 
        else
            file.close()
            collectgarbage()
            if sentCallback then
                sentCallback()
            else
                sck:close()
            end
        end
    end
    sendChunk()
end

----------------
-- Web Server --
----------------
srv = net.createServer(net.TCP)
srv:listen(80, function(conn)
    conn:on("receive", function(sck, request_payload)
        -- == DATA == --
        local payload = ""
        if request_payload == nil or request_payload == "" then
            payload = ""
        else
            payload = request_payload
        end
        print(payload)
    
        -- === FUNCTIONS ===
        function respondMain()
            sck:send("HTTP/1.1 200 OK\r\n" ..
                "Server: NodeMCU on ESP8266\r\n" ..
                "Content-Type: text/html; charset=UTF-8\r\n\r\n", 
                function()
                    Sendfile(sck, "1.html", 
                        function() 
                            sck:send("seconds_until_switchoff_counter: " .. seconds_until_switchoff_counter or "?", 
                            function() 
                                sck:close()
                            end)
                        end)
                end)
        end

        function respondCounter()
            sck:send("HTTP/1.1 200 OK\r\n" ..
                "Server: NodeMCU on ESP8266\r\n"..
                "Content-Type: application/json; charset=UTF-8\r\n\r\n" ..
                "{\"seconds_until_switchoff_counter\":" .. seconds_until_switchoff_counter .. "}", 
                function()
                    sck:close()
                end)
        end

        function respondOK()
            sck:send("HTTP/1.1 200 OK\r\n" ..
                "Server: NodeMCU on ESP8266\r\n", 
                function()
                    sck:close()
                end)
        end

        function respondError()
            sck:send("HTTP/1.1 400 OK\r\n" ..
                "Server: NodeMCU on ESP8266\r\n", 
                function()
                    sck:close()
                end)
        end
        
        function handleGET(path)
            print("### handleGET() ###")
            if string.match(path, "counter") then
                print(" - respondCounter()")
                respondCounter()
            else
                print(" - respondMain()") 
                respondMain()
            end
        end
        
        function handlePOST(path)
            print("### handlePOST() ###")

            local POST_expandTime = string.match(payload, "expandTime=(%d*)") --or "N/A"
            local POST_relais_state = string.match(payload, "relais_state=(%d)")
            local POST_genericvalue = string.match(payload, "genericvalue=")
            print("  expandTime: " .. (POST_expandTime or "?"))
            print("  relais_state: " .. (POST_relais_state or "?"))

            if POST_expandTime then
               seconds_until_switchoff = POST_expandTime
               seconds_until_switchoff_counter = seconds_until_switchoff
            end

            if POST_relais_state then
                relais_state = POST_relais_state
                -- reset counters
                if tonumber(POST_relais_state)==0 then seconds_until_switchoff_counter = 0 end
                if tonumber(POST_relais_state)==1 then seconds_until_switchoff_counter = 0 end
            end
            
            respondMain()
        end
        -- === FUNCTIONS - END ===
        
        -- === ACTUAL EVALUATION ===
        local GET_requestpath = string.match(payload, "GET (.*) HTTP") --or "N/A"
        local POST_requestpath = string.match(payload, "POST (.*) HTTP") --or "N/A"
        print(" GET_requestpath: " .. (GET_requestpath or "???") )
        print(" POST_requestpath: " .. (POST_requestpath or "???") )
        
        if GET_requestpath then
            handleGET(GET_requestpath)
        elseif POST_requestpath then
            handlePOST(POST_requestpath)
        else
            print("# cannot handle request. olny GET and POST are allowed.")
            respondError()
        end
        
    end)
        
end)
