print("Starting Bootloader...")
button_pin = 0
luafilename = "timer.lua"
gpio.mode(button_pin, gpio.INPUT)
local buttonpressed = gpio.read(button_pin)
print(" -> buttonpressed: "..((buttonpressed==0 and "yes") or "no"))

if(buttonpressed==0) then
    print(" -> interrupting autostart")
else
    print(" -> performing startup of " .. luafilename)
    tmr.alarm(0, 5000, tmr.ALARM_SINGLE, function() 
            dofile(luafilename)
        end) 
end
