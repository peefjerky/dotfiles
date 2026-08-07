function kbd_bl
    echo $argv[1] | sudo tee /sys/class/leds/:white:kbd_backlight/brightness
end
