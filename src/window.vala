/* window.vala
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
[GtkTemplate (ui = "/com/ak1932/serial_plotter/window.ui")]
public class SerialPlotter.Window : Adw.ApplicationWindow {
    private bool interrupt;
    private bool send_interrupt;
    private Gee.HashMap<string, LiveChart.Serie> series;
    private LiveChart.Chart chart;
    private bool is_port_open;
    private bool global_pause;
    private CircularBuffer buf;
    private SerialPort sp;

    [GtkChild]
    private unowned Gtk.Entry input_bar;

    [GtkChild]
    private unowned Gtk.DropDown port_menu;

    [GtkChild]
    private unowned Gtk.DropDown baud_rate_menu;

    [GtkChild]
    private unowned Gtk.TextView main_text_view;

    [GtkChild]
    private unowned Gtk.Button open_button;

    [GtkChild]
    private unowned Gtk.Button seekforward_plotter_button;

    [GtkChild]
    private unowned Gtk.Button seekbackward_plotter_button;

    [GtkChild]
    private unowned Gtk.Button global_pause_button;

    [GtkChild]
    private unowned Gtk.Button global_clean_button;

    [GtkChild]
    private unowned Adw.ToastOverlay toast_overlay;

    [GtkChild]
    private unowned Gtk.Box plot_box;

    [GtkChild]
    private unowned Gtk.ActionBar plot_bar;

    private string[] ttys;
    private string[] baud_rates;

    public Window (Gtk.Application app) {
        Object (application: app);
    }

    private void refresh_port_list () {
        try {
            string[] current_ttys = {};
            var dev = Dir.open ("/dev");
            string tty;
            int default_tty = -1;
            int n = 0;

            while ((tty = dev.read_name ()) != null) {
                if (tty.length > 3 && tty.substring (0, 3) == "tty") {
                    current_ttys += tty;
                    if (tty.length > 6) {
                        default_tty = n;
                    }
                    n++;
                }
            }

            ttys = current_ttys;
            this.port_menu.set_model (new Gtk.StringList (ttys));
            if (default_tty != -1)
                this.port_menu.set_selected (default_tty);
        } catch (FileError e) {
            this.toast_overlay.add_toast (new Adw.Toast (@"ls /dev/tty* failed : $(e.message)"));
        }
    }

    construct {
        refresh_port_list ();
        baud_rates = new string[] {
            "0",
            "50",
            "75",
            "110",
            "134",
            "150",
            "200",
            "300",
            "600",
            "1200",
            "1800",
            "2400",
            "4800",
            "9600",
            "19200",
            "38400",
            "57600",
            "115200",
            "230400",
        };
        send_interrupt = false;

        this.input_bar.icon_press.connect (() => { this.send_interrupt = true; });
        this.input_bar.activate.connect (() => { this.send_interrupt = true; });
        this.input_bar.set_activates_default (true);

        this.baud_rate_menu.set_model (new Gtk.StringList (baud_rates));
        this.baud_rate_menu.set_selected (baud_rates.length - 2); // set 115200 in default state

        buf = new CircularBuffer (1000);
        series = new Gee.HashMap<string, LiveChart.Serie> ();
        is_port_open = false;
        interrupt = false;

        var open_action = new SimpleAction ("open", null);
        open_action.activate.connect (this.open_close_port);
        this.add_action (open_action);

        var clean_action = new SimpleAction ("clean", null);
        clean_action.activate.connect (this.clean_buffer);
        this.add_action (clean_action);

        var play_pause_action = new SimpleAction ("pause", null);
        play_pause_action.activate.connect (this.play_pause_port);
        this.add_action (play_pause_action);

        var forward_action = new SimpleAction ("forward", null);
        forward_action.activate.connect (this.seek_forward_plotter);
        this.add_action (forward_action);

        var backward_action = new SimpleAction ("backward", null);
        backward_action.activate.connect (this.seek_backward_plotter);
        this.add_action (backward_action);

        var timestamp_toggle_action = new SimpleAction ("timestamp-toggle", null);
        timestamp_toggle_action.activate.connect (() => { GlobalConfig.timestamp = !GlobalConfig.timestamp; });
        this.add_action (timestamp_toggle_action);

        var config = new LiveChart.Config ();
        config.y_axis.unit = "";
        config.x_axis.tick_length = 60;
        config.x_axis.tick_interval = 0.2f;
        config.x_axis.lines.visible = false;
        config.x_axis.show_fraction = false;

        chart = new LiveChart.Chart ();

        chart.config = config;
        chart.legend.labels.font.size = 20;
        chart.vexpand = true;
        chart.vexpand = true;

        plot_box.append (chart);

        seekforward_plotter_button.clicked.connect (seek_forward_plotter);
        seekbackward_plotter_button.clicked.connect (seek_backward_plotter);

        global_pause = false;
        global_pause_button.clicked.connect (this.play_pause_port);

        global_clean_button.clicked.connect (clean_buffer);

        var refresh_port_action = new SimpleAction ("refresh_ports", null);
        refresh_port_action.activate.connect (this.refresh_port_list);
        this.add_action (refresh_port_action);
    }

    private void seek_forward_plotter () {
        int64 conv = chart.config.time.conv_sec;
        int64 seek_time = (int64) (chart.config.x_axis.tick_interval * conv);
        chart.config.time.current += seek_time;
    }

    private void seek_backward_plotter () {
        int64 conv = chart.config.time.conv_sec;
        int64 seek_time = (int64) (chart.config.x_axis.tick_interval * conv);
        chart.config.time.current -= seek_time;
    }

    private void clean_buffer () {
        this.buf.clear ();
        this.main_text_view.buffer.text = "";
    }

    private void play_pause_port () {
        var conv_usec = chart.config.time.conv_us;
        global_pause = !global_pause;
        // chart.refresh_every (global_pause ? 0 : 100);
        chart.refresh_every (100, global_pause ? 0.0 : 1.0);
        global_pause_button.icon_name = global_pause ? "media-playback-start-symbolic" : "media-playback-pause-symbolic";
        global_pause_button.tooltip_text = global_pause ? "Play" : "Pause";
        if (!global_pause)
            chart.config.time.current = GLib.get_real_time () / conv_usec;
    }

    private void add_serie (string serie_name) {
        // buffer for chart
        LiveChart.Values values = new LiveChart.Values (1000);

        var serie = new LiveChart.Serie (serie_name, new LiveChart.Line (values));
        serie.line.color = { (float) Random.double_range (0, 1), (float) Random.double_range (0, 1), (float) Random.double_range (0, 1), 1.0f };
        this.series[serie_name] = serie;
        chart.add_serie (this.series[serie_name]);
        Gtk.ToggleButton serie_button = new Gtk.ToggleButton ();
        serie_button.label = serie_name;
        serie_button.set_active (true);
        serie_button.toggled.connect (() => {
            this.series[serie_name].visible = !this.series[serie_name].visible;
            serie_button.tooltip_text = this.series[serie_name].visible ? @"Hide $(serie_name)" : @"Show $(serie_name)";
        });
        plot_bar.pack_start (serie_button);
    }

    private void open_close_port (Variant? parameter) {
        if (is_port_open) {
            interrupt = true;
            return;
        }

        string chosen_speed_string = baud_rates[this.baud_rate_menu.get_selected ()];
        Posix.speed_t selected_baud_rate = string_to_baudrate (chosen_speed_string);
        string port = "/dev/" + ttys[this.port_menu.get_selected ()];
        sp = new SerialPort (port, selected_baud_rate);

        try {
            sp.open ();
        } catch (PortError e) {
            this.toast_overlay.add_toast (new Adw.Toast (e.message));
            return;
        }

        this.toast_overlay.add_toast (new Adw.Toast (@"$(port) $(chosen_speed_string) opened"));
        this.is_port_open = true;
        this.input_bar.can_focus = true;

        this.open_button.label = "Close";

        Gtk.TextBuffer buffer = this.main_text_view.buffer;

        string prev_line = "";

        Timeout.add (100, () => {
            string data = "";
            if (this.send_interrupt) {
                try {
                    sp.write (this.input_bar.text);
                    this.toast_overlay.add_toast (new Adw.Toast (@"Sent data"));
                } catch (PortError e) {
                    this.toast_overlay.add_toast (new Adw.Toast (@"Write error : $(e.message)"));
                }
                this.send_interrupt = false;
            }

            if (this.interrupt) {
                try {
                    sp.close ();
                    this.input_bar.can_focus = false;
                    this.toast_overlay.add_toast (new Adw.Toast (@"$(port) closed"));
                } catch (PortError e) {
                    this.toast_overlay.add_toast (new Adw.Toast (@"$(e.message)"));
                }

                interrupt = false;
                is_port_open = false;
                this.open_button.label = "Open";
                return false;
            }

            if (this.global_pause)
                return true;

            try {
                sp.read (ref data);
            } catch (PortError e) {
                this.toast_overlay.add_toast (new Adw.Toast (e.message));
                this.interrupt = true;
                return true;
            }

            string[] lines = data.split ("\r\n");
            if (lines.length > 0) {
                lines[0] = prev_line + lines[0];
                prev_line = lines[lines.length - 1];
                var timestamp = buf.get_timestamp ();

                foreach (string line in lines[0 : lines.length - 1]) {
                    buf.append_with_timestamp (line, timestamp);
                    foreach (string elem in line.split (",")) {
                        int i = elem.index_of_char (':');
                        if (i != -1) {
                            string key = elem.substring (0, i);
                            string value = elem.substring (i + 1);
                            float val;

                            if (!series.has_key (key)) {
                                if (!key.validate ())
                                    continue; // only add key to plotter if it is lowercase or uppercase character
                                add_serie (key);
                            }

                            if (series[key].visible) {
                                if (float.try_parse (value, out val)) {
                                    series[key].add (val);
                                }
                            }
                        }
                    }
                }
            }

            buffer.text = GlobalConfig.timestamp ? buf.get_string_timestamp () : buf.get_string ();

            return true;
        });
    }

    private Posix.speed_t string_to_baudrate (string chosen_speed_string) {
        switch (chosen_speed_string) {
        case "0": {
            return Posix.B0;
        }
        case "50": {
            return Posix.B50;
        }
        case "75": {
            return Posix.B75;
        }
        case "110": {
            return Posix.B110;
        }
        case "134": {
            return Posix.B134;
        }
        case "150": {
            return Posix.B150;
        }
        case "200": {
            return Posix.B200;
        }
        case "300": {
            return Posix.B300;
        }
        case "600": {
            return Posix.B600;
        }
        case "1200": {
            return Posix.B1200;
        }
        case "1800": {
            return Posix.B1800;
        }
        case "2400": {
            return Posix.B2400;
        }
        case "4800": {
            return Posix.B4800;
        }
        case "9600": {
            return Posix.B9600;
        }
        case "19200": {
            return Posix.B19200;
        }
        case "38400": {
            return Posix.B38400;
        }
        case "57600": {
            return Posix.B57600;
        }
        case "115200": {
            return Posix.B115200;
        }
        case "230400": {
            return Posix.B230400;
        }
        default: {
            this.toast_overlay.add_toast (new Adw.Toast (@"$(chosen_speed_string) baud rate is not possible. setting 115200"));
            return Posix.B115200;
        }
        }
    }
}
