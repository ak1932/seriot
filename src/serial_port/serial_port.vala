/* serial_port.vala
 *
 * Copyright 2024 Aryan Kadole
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public errordomain PortError {
    PORT,
    CHANNEL,
    DATA,
}

public class SerialPort : GLib.Object {
    public Posix.speed_t baud_rate { get; set; default = Posix.B115200; }
    public int serial_port { get; set; default = -1; }
    public string port { get; set; }
    private const ssize_t buf_size = 1024;
    private char read_buf[buf_size];

    public SerialPort(string port, Posix.speed_t baud_rate) {
        _port = port;
        _baud_rate = baud_rate;
    }

    ~SerialPort() {
        // don't do shit in destructor on error
        try { close(); } catch (PortError e) {}
    }

    public void configure_tty(ref Posix.termios _tty) {
        // Control modes
        // no parity bit
        _tty.c_cflag &= ~Posix.PARENB;

        // clear stop bit
        _tty.c_cflag &= ~Posix.CSTOPB;

        // clear size bits and set 8 bit size
        _tty.c_cflag &= ~Posix.CSIZE;
        _tty.c_cflag |= Posix.CS8;

        // disable RTS/CTS hw flow control
        // tty.c_cflag &= ~Posix.CRTS

        // CREAD - allow to read data, CLOCAL - disable modem specific signal lines as well as SIGHUP signal
        _tty.c_cflag |= Posix.CREAD | Posix.CLOCAL;

        // Local modes
        // disable canonical mode i.e. to process data on newline
        _tty.c_lflag &= ~Posix.ICANON;

        // disable echo (probably doesn't do anything in non canonical mode)
        _tty.c_lflag &= ~Posix.ECHO; // Disable echo
        _tty.c_lflag &= ~Posix.ECHOE; // Disable erasure
        _tty.c_lflag &= ~Posix.ECHONL; // Disable new-line echo
        //

        // disable INTR, QUIT, and SUSP signals
        _tty.c_lflag &= ~Posix.ISIG;

        // INPUT MODES

        _tty.c_iflag &= ~(Posix.IXON | Posix.IXOFF | Posix.IXANY); // Turn off s/w flow ctrl
        _tty.c_iflag &= ~(Posix.IGNBRK | Posix.BRKINT | Posix.PARMRK | Posix.ISTRIP | Posix.INLCR | Posix.IGNCR | Posix.ICRNL); // Disable any special handling of received bytes
        _tty.c_oflag &= ~Posix.OPOST; // Prevent special interpretation of output bytes (e.g. newline chars)
        _tty.c_oflag &= ~Posix.ONLCR; // Prevent conversion of newline to carriage return/line feed
        //
        _tty.c_cc[Posix.VTIME] = 10; // Wait for up to 1s (10 deciseconds), returning as soon as any data is received.
        _tty.c_cc[Posix.VMIN] = 0;

        Posix.cfsetspeed(ref _tty, baud_rate);
    }

    public void open() throws PortError.PORT, PortError.CHANNEL {
        Posix.termios tty;

        serial_port = Posix.open(port, Posix.O_RDWR);

        if (serial_port < 0) {
            throw new PortError.PORT(@"Unable to open $port");
        }

        try { getattr(out tty); } catch (PortError.CHANNEL e) { throw e; }

        configure_tty(ref tty);

        if (Posix.tcsetattr(serial_port, Posix.TCSANOW, tty) != 0) {
            close();
            throw new PortError.CHANNEL(@"Error $(Posix.errno) from tcsetattr: $(Posix.strerror(Posix.errno))...Closing port");
        }
    }

    public void getattr(out Posix.termios tty) throws PortError.CHANNEL {
        if (Posix.tcgetattr(serial_port, out tty) != 0) {
            throw new PortError.CHANNEL(@"Error $(Posix.errno) from tcgetattr: $(Posix.strerror(Posix.errno))");
        }
    }

    public void read(ref string data) throws PortError.DATA, PortError.CHANNEL, PortError.PORT {
        Posix.memset(&read_buf, '\0', sizeof (char) * buf_size);

        ssize_t num_bytes = Posix.read(serial_port, &read_buf, buf_size - 1);

        // n is the number of bytes read. n may be 0 if no bytes were received, and can also be -1 to signal an error.
        if (num_bytes < 0) {
            try {
                close();
            } catch (PortError.PORT e) {
                throw e;
            }
            throw new PortError.DATA(@"Error $(Posix.errno) from read: $(Posix.strerror(Posix.errno))");
        } else if (num_bytes == 0) {
            Posix.termios tty;
            try { getattr(out tty); } catch (PortError.CHANNEL e) { throw e; }
        }

        data = (string) (read_buf);
    }

    public void write(string data) throws PortError.DATA {
        ssize_t write_result = Posix.write(serial_port, data, data.length);

        // n is the number of bytes read. n may be 0 if no bytes were received, and can also be -1 to signal an error.
        if (write_result != -1) {
            throw new PortError.DATA(@"Error $(Posix.errno) from write: $(Posix.strerror(Posix.errno))");
        }
    }

    public void close() throws PortError.PORT {
        if (serial_port != -1) {
            int status = Posix.close(serial_port);
            if (status == -1) {
                throw new PortError.PORT(@"Error $(Posix.errno) from close: $(Posix.strerror(Posix.errno))");
            }
            serial_port = -1;
        }
    }
}
