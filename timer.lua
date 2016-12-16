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
seconds_until_switchoff_counter = 1800

----------------
-- Timers     --
----------------

-- duty: 0..1023 
-- attention: >100 causes flickering somehow
function getPWMDuty()
    -- handle ON and OFF separately
    if tonumber(relais_state) == 1 then return 1000 end
    if tonumber(relais_state) == 0 then return  150 end
    if tonumber(relais_state) ~= 2 then
        print(" weird relais_state: " .. relais_state or "nil")
    end
    -- now that we know that we're in TIMER mode, we can check remaining time...
    if tonumber(seconds_until_switchoff_counter) > (15*60) then return 1000 end
    if tonumber(seconds_until_switchoff_counter) > (14*60) then return 800 end
    if tonumber(seconds_until_switchoff_counter) > (13*60) then return 700 end
    if tonumber(seconds_until_switchoff_counter) > (12*60) then return 600 end
    if tonumber(seconds_until_switchoff_counter) > (11*60) then return 500 end
    if tonumber(seconds_until_switchoff_counter) > (10*60) then return 400 end
    if tonumber(seconds_until_switchoff_counter) > ( 9*60) then return 300 end
    if tonumber(seconds_until_switchoff_counter) > ( 8*60) then return 200 end
    if tonumber(seconds_until_switchoff_counter) > ( 7*60) then return 100 end
    if tonumber(seconds_until_switchoff_counter) > ( 6*60) then return 80 end
    if tonumber(seconds_until_switchoff_counter) > ( 5*60) then return 60 end
    if tonumber(seconds_until_switchoff_counter) > ( 4*60) then return 40 end
    if tonumber(seconds_until_switchoff_counter) > ( 3*60) then return 30 end
    if tonumber(seconds_until_switchoff_counter) > ( 2*60) then return 20 end
    if tonumber(seconds_until_switchoff_counter) > (   60) then return 15 end
    if tonumber(seconds_until_switchoff_counter) > (   50) then return 11 end
    if tonumber(seconds_until_switchoff_counter) > (   40) then return 7 end
    if tonumber(seconds_until_switchoff_counter) > (   30) then return 4 end
    if tonumber(seconds_until_switchoff_counter) > (   20) then return 2 end
    return 1
end

-- DO NOT CHANGE THIS TIMER DEFINITION!
timer1_id = 0
timer1_timeout_millis = 1000
tmr.register(timer1_id, timer1_timeout_millis, tmr.ALARM_SEMI, function()
    -- LOG --
    print("tick")
    print("  -> relais_state: " .. (relais_state or "?"))
    print("  -> seconds_until_switchoff_counter: " .. (seconds_until_switchoff_counter or "?"))
    print("  -> pwm_duty: " .. (pwm_duty or "?"))
    
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
    elseif tonumber(relais_state) == 1 then
        switchOn()
    elseif tonumber(relais_state) == 0 then
        switchOff()
    else
        print(" weird relais_state: " .. relais_state or "nil")
        relais_state = 0
    end

    -- set PWM maximum to visualize remaining time
    -- (...devide by 2 to keep the LED darker)
    pwm_duty = getPWMDuty() / 2
    if pwm_duty < pwm_duty_MIN+1 then pwm_duty = pwm_duty_MIN+1 end
    --print("  getPWMDuty(): " .. pwm_duty)
    -- /PWM

    tmr.start(timer1_id)
end)
tmr.start(timer1_id)
print(" timer1 started");




nextMaximumPWM = 1
function getSpeed()
    if nextMaximumPWM < 10   then return 1  end
    if nextMaximumPWM < 50   then return 2  end
    if nextMaximumPWM < 100  then return 3  end
    if nextMaximumPWM < 200  then return 4  end
    if nextMaximumPWM < 400  then return 6  end
    if nextMaximumPWM < 600  then return 8  end
    if nextMaximumPWM < 800  then return 10 end
    if nextMaximumPWM < 1000 then return 12 end
    return 10
end
countdirection = 1  -- 1=up 2=down
function getNextPWM()
    -- count up or down
    speed = getSpeed()
    -- print("  speed: " .. speed or "N/A")
    if countdirection==1 then
        nextMaximumPWM = nextMaximumPWM + speed
    elseif countdirection==2 then
        nextMaximumPWM = nextMaximumPWM - speed
    else
        print("EEEERRRROOOOOORRRR")
    end

    -- check overflow and change directions
    if nextMaximumPWM < pwm_duty_MIN then 
        --print("  whoops, underflow. counting up now...")
        nextMaximumPWM = pwm_duty_MIN
        countdirection = 1
    elseif nextMaximumPWM > pwm_duty then
        --print("  whoops, overrflow. counting down now...")
        nextMaximumPWM = pwm_duty
        countdirection = 2
    end
    
    --print("  nextMaximumPWM: " .. nextMaximumPWM)
    return nextMaximumPWM
end

-- TIMER 2 (pwm pulse)
timer2_id = 1
function getTimer2_timeout_millis()
    if nextMaximumPWM < 10   then return 80 end
    if nextMaximumPWM < 50   then return 70 end
    if nextMaximumPWM < 100  then return 60 end
    if nextMaximumPWM < 200  then return 50 end
    if nextMaximumPWM < 400  then return 40 end
    if nextMaximumPWM < 600  then return 30 end
    if nextMaximumPWM < 800  then return 20 end
    if nextMaximumPWM < 1000 then return 10 end
    return 5
end
tmr.register(timer2_id, getTimer2_timeout_millis(), tmr.ALARM_SEMI, function()
    pwm.setduty(led_pin, getNextPWM())
    
    tmr.interval(timer2_id, getTimer2_timeout_millis())
    tmr.start(timer2_id)
end)
tmr.start(timer2_id)
print(" timer2 started");

----------------
-- Init Wifi  --
----------------
-- read config from FS
client_ssid = "notinitialized"
client_password = "notinitialized"
if file.open("client_ssid.txt", "r") then
    client_ssid = file.readline()
    file.close()
end
collectgarbage()
if file.open("client_password.txt", "r") then
    client_password = file.readline()
    file.close()
end
collectgarbage()
print("client_ssid: '" .. client_ssid .. "'")
print("client_password: '" .. client_password .. "'")
print("  again: " .. string.gsub(client_password, "%%2C", ","))

-- setup station mode
wifi.setmode(wifi.STATION)
-- less energy consumption
wifi.setphymode(wifi.PHYMODE_G)
-- edit config
wifi.sta.config(client_ssid, client_password) 
wifi.sta.connect()
print(" connecting to: " .. client_ssid)

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

        function respondStatus()
            sck:send("HTTP/1.1 200 OK\r\n" ..
                "Server: NodeMCU on ESP8266\r\n"..
                "Content-Type: application/json; charset=UTF-8\r\n\r\n" ..
                "{\"seconds_until_switchoff_counter\":" .. seconds_until_switchoff_counter .. 
                ",\"relais_state\":" .. relais_state .. "}", 
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
            -- path?
            if string.match(path, "status") then
                print(" - respondStatus()")
                respondStatus()
            else
                print(" - respondMain()") 
                respondMain()
            end
        end

        -- handle posted data updates
        function handlePOSTcontent(POST_seconds_until_switchoff_counter, POST_relais_state)
            if POST_seconds_until_switchoff_counter and tonumber(POST_relais_state)==2 then
               seconds_until_switchoff_counter = POST_seconds_until_switchoff_counter
            end

            if POST_relais_state then
                relais_state = POST_relais_state
                -- reset counters
                if tonumber(POST_relais_state)==0 then seconds_until_switchoff_counter = 0 end
                if tonumber(POST_relais_state)==1 then seconds_until_switchoff_counter = 0 end
            end
        end
        
        function handlePOST(path)
            print("### handlePOST() ###")
            -- path?
            if string.match(path, "status") then
                -- POST @ path "/status" --> application/json
                local whitespace1, POST_seconds_until_switchoff_counter = string.match(payload, "\"seconds_until_switchoff_counter\":(%s*)(%d*)")
                local whitespace2, POST_relais_state = string.match(payload, "\"relais_state\":(%s*)(%d)")
                print("  POST_seconds_until_switchoff_counter: " .. (POST_seconds_until_switchoff_counter or "?"))
                print("  POST_relais_state: " .. (POST_relais_state or "?"))
                handlePOSTcontent(POST_seconds_until_switchoff_counter, POST_relais_state)
            else
                -- POST @ path "/" --> application/x-www-form-urlencoded
                local POST_seconds_until_switchoff_counter = string.match(payload, "seconds_until_switchoff_counter=(%d*)")
                local POST_relais_state = string.match(payload, "relais_state=(%d)")
                print("  POST_seconds_until_switchoff_counter: " .. (POST_seconds_until_switchoff_counter or "?"))
                print("  POST_relais_state: " .. (POST_relais_state or "?"))
                handlePOSTcontent(POST_seconds_until_switchoff_counter, POST_relais_state)
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
