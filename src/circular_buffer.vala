/* circular_buffer.vala
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

class CircularBuffer : GLib.Object {
    class Item {
        public string data;
        public string timestamp;
        public Item(string data_, string timestamp_) { data = data_; timestamp = timestamp_; }
    }

    private Item[] buffer;
    private ssize_t head;
    private ssize_t tail;
    private ssize_t size;
    private ssize_t capacity;


    public CircularBuffer(ssize_t capacity) {
        this.capacity = capacity;
        this.buffer = new Item[capacity];
        this.head = 0;
        this.tail = 0;
        this.size = 0;
    }

    public bool is_empty() {
        return size == 0;
    }

    public bool is_full() {
        return size == capacity;
    }

    public void clear() {
        size = 0;
    }

    public void append(string data) {
        var timestamp = get_timestamp();

        buffer[tail] = new Item(data, timestamp);
        tail = (tail + 1) % capacity;
        if (is_full()) {
            // Overwrite the oldest data
            head = (head + 1) % capacity;
        } else {
            size++;
        }
    }

    public string get_timestamp() {

        var date = new GLib.DateTime.now();
        var timestamp = (GlobalConfig.show_milliseconds) ? 
                            "%s:%03d".printf(date.format(GlobalConfig.timestamp_format), date.get_microsecond() / 1000) :
                            date.format(GlobalConfig.timestamp_format);
        return timestamp;
    }

    public void append_with_timestamp(string data, string timestamp) {
        buffer[tail] = new Item(data, timestamp);
        tail = (tail + 1) % capacity;
        if (is_full()) {
            // Overwrite the oldest data
            head = (head + 1) % capacity;
        } else {
            size++;
        }
    }

    public string get_string() {
        StringBuilder builder = new StringBuilder();
        for (ssize_t i = size - 1; i >= 0; i--) {
            ssize_t index = (head + i) % capacity;
            builder.append(buffer[index].data + "\n");
        }
        return builder.str;
    }

    public string get_string_timestamp() {
        StringBuilder builder = new StringBuilder();
        for (ssize_t i = size - 1; i >= 0; i--) {
            ssize_t index = (head + i) % capacity;
            builder.append(buffer[index].timestamp + " => " + buffer[index].data + "\n");
        }
        return builder.str;
    }
}
