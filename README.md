# Seriot

A GNOME desktop serial monitor and serial plotter.

## Features:
    - Play/Pause
    - Serial Plotter - plot incoming data
    - Enable/Disable plots
    - Rewind/Forward plots

Depending on your system, permissions to get read/write access would be required

For Arch ppl - 
https://wiki.archlinux.org/title/Arduino#Accessing_serial

Create a file containing
```
/etc/udev/rules.d/01-ttyusb.rules
SUBSYSTEMS=="usb-serial", TAG+="uaccess"
```

For Ubuntu folks -
```bash
sudo usermod -a -G dialout $USER
sudo usermod -a -G plugdev $USER
```

Screenshots -

