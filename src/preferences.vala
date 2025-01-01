/* preferences.vala
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

[GtkTemplate (ui = "/com/ak1932/serial_plotter/preferences.ui")]
public class SerialPlotter.Preferences : Adw.PreferencesDialog {
    [GtkChild]
    private unowned Adw.SwitchRow timestamp_row;

    [GtkChild]
    private unowned Adw.EntryRow timestamp_format_row;

    [GtkChild]
    private unowned Adw.SwitchRow milliseconds_row;

    public Preferences () {}

    construct {
        timestamp_row.active = GlobalConfig.timestamp;
        timestamp_format_row.text = GlobalConfig.timestamp_format;
        milliseconds_row.active = GlobalConfig.show_milliseconds;

        timestamp_row.notify["active"].connect ((s, p) => {
            GlobalConfig.timestamp = this.timestamp_row.active;
        });

        milliseconds_row.notify["active"].connect ((s, p) => {
            GlobalConfig.show_milliseconds = this.milliseconds_row.active;
        });

        timestamp_format_row.notify["text"].connect ((s, p) => {
            GlobalConfig.timestamp_format = this.timestamp_format_row.text;
        });
    }
}
