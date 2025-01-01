/* application.vala
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

public class SerialPlotter.Application : Adw.Application {
    public Application () {
        Object (
            application_id: "com.ak1932.serial_plotter",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
    }

    construct {
        ActionEntry[] action_entries = {
            { "about", this.on_about_action },
            { "preferences", this.on_preferences_action },
            { "quit", this.quit }
        };
        this.add_action_entries (action_entries, this);
        this.set_accels_for_action ("app.quit", {"<primary>q"});
        this.set_accels_for_action ("win.open", { "<Ctrl>o" });
        this.set_accels_for_action ("win.clean", { "<Ctrl>c" });
        this.set_accels_for_action ("win.timestamp-toggle", { "<Ctrl>t" });
        this.set_accels_for_action ("win.pause", { "<Ctrl>p" });
        this.set_accels_for_action ("win.forward", { "<Ctrl>f" });
        this.set_accels_for_action ("win.backward", { "<Ctrl>b" });
    }

    public override void activate () {
        base.activate ();
        var win = this.active_window ?? new SerialPlotter.Window (this);
        win.present ();
    }

    private void on_about_action () {
        string[] developers = { "Aryan Kadole" };
        var about = new Adw.AboutDialog () {
            application_name = "seriot",
            application_icon = "com.ak1932.serial_plotter",
            developer_name = "Aryan Kadole",
            translator_credits = _("translator-credits"),
            version = "0.1.0",
            developers = developers,
            copyright = "🄯 2024 Aryan Kadole",
        };

        about.present (this.active_window);
    }

    private void on_preferences_action () {
        // preferences.present(this.active_window);
        var preferences = new SerialPlotter.Preferences ();
        preferences.present (this.active_window);
    }
}
