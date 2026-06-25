public class HistoryManager : Object {
    private string data_dir;
    private string history_file;
    private Json.Array entries;
    private const int MAX_DAYS = 7;

    public HistoryManager () {
        data_dir = Path.build_filename (
            Environment.get_user_data_dir (),
            "battery-monitor"
        );
        history_file = Path.build_filename (data_dir, "history.json");
        entries = new Json.Array ();
        load ();
    }

    public void add_entry (int capacity, string status, double power_watts, double voltage_volts) {
        var entry = new Json.Object ();
        entry.set_int_member ("timestamp", GLib.get_real_time () / 1000000);
        entry.set_int_member ("capacity", capacity);
        entry.set_string_member ("status", status);
        entry.set_double_member ("power", power_watts);
        entry.set_double_member ("voltage", voltage_volts);

        entries.add_object_element (entry);
        cleanup_old_entries ();
        save ();
    }

    public Json.Array get_entries (int hours) {
        var result = new Json.Array ();
        int64 cutoff = GLib.get_real_time () / 1000000 - (hours * 3600);

        for (int i = 0; i < entries.get_length (); i++) {
            var entry = entries.get_object_element (i);
            int64 timestamp = entry.get_int_member ("timestamp");
            if (timestamp >= cutoff) {
                result.add_object_element (entry);
            }
        }

        return result;
    }

    public int64 get_last_disconnect_time () {
        int64 last_time = 0;
        for (int i = (int) entries.get_length () - 1; i >= 0; i--) {
            var entry = entries.get_object_element (i);
            string status = entry.get_string_member ("status");
            if (status == "Discharging" || status == "Full") {
                last_time = entry.get_int_member ("timestamp");
                break;
            }
        }
        return last_time;
    }

    private void cleanup_old_entries () {
        int64 cutoff = GLib.get_real_time () / 1000000 - (MAX_DAYS * 24 * 3600);
        var cleaned = new Json.Array ();

        for (int i = 0; i < entries.get_length (); i++) {
            var entry = entries.get_object_element (i);
            int64 timestamp = entry.get_int_member ("timestamp");
            if (timestamp >= cutoff) {
                cleaned.add_object_element (entry);
            }
        }

        entries = cleaned;
    }

    private void load () {
        if (!FileUtils.test (history_file, FileTest.EXISTS)) {
            return;
        }

        try {
            string contents;
            FileUtils.get_contents (history_file, out contents);
            var parser = new Json.Parser ();
            parser.load_from_data (contents, -1);
            var root = parser.get_root ();

            if (root.get_node_type () == Json.NodeType.ARRAY) {
                entries = root.get_array ();
            }
        } catch (Error e) {
            stderr.printf ("加载历史数据失败: %s\n", e.message);
        }
    }

    public void save () {
        try {
            DirUtils.create_with_parents (data_dir, 0755);
            var generator = new Json.Generator ();
            var root = new Json.Node (Json.NodeType.ARRAY);
            root.set_array (entries);
            generator.set_root (root);
            generator.set_pretty (true);
            string json = generator.to_data (null);
            FileUtils.set_contents (history_file, json);
        } catch (Error e) {
            stderr.printf ("保存历史数据失败: %s\n", e.message);
        }
    }
}
