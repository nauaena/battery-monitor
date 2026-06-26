using Gtk;

public class MainWindow : Gtk.ApplicationWindow {
    private BatteryData battery;
    private HistoryManager history;
    private Gtk.Label capacity_label;
    private Gtk.Label status_label;
    private Gtk.Label model_label;
    private Gtk.Label charge_type_label;
    private Gtk.Label power_label;
    private Gtk.Label voltage_label;
    private Gtk.Label current_label;
    private Gtk.Label input_voltage_label;
    private Gtk.Label input_current_label;
    private Gtk.Label estimated_time_label;
    private Gtk.Label design_capacity_label;
    private Gtk.Label current_capacity_label;
    private Gtk.Label health_label;
    private Gtk.Label cycle_label;
    private Gtk.Label lifetime_label;
    private Gtk.Label last_disconnect_label;
    private Gtk.Label charging_time_label;
    private Gtk.Label discharging_time_label;
    private Gtk.Scale progress_bar;
    private BatteryChart chart;
    private Gtk.ComboBoxText time_range_combo;
    private Gtk.Paned paned;
    private bool is_fullscreen = false;

    public MainWindow (Gtk.Application app, BatteryData battery, HistoryManager history) {
        Object (application: app);
        this.battery = battery;
        this.history = history;

        title = "电池监控器";
        set_default_size (800, 600);
        set_resizable (true);

        delete_event.connect (() => {
            hide ();
            return true;
        });

        key_press_event.connect ((event) => {
            if (event.keyval == Gdk.Key.F11) {
                toggle_fullscreen ();
                return true;
            }
            return false;
        });

        build_ui ();
        update_data ();
        update_history (history);
    }

    private void toggle_fullscreen () {
        if (is_fullscreen) {
            unfullscreen ();
            is_fullscreen = false;
            paned.set_position (350);
        } else {
            fullscreen ();
            is_fullscreen = true;
            int screen_width = screen.get_width ();
            paned.set_position (screen_width / 2);
        }
    }

    private void build_ui () {
        paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned.set_position (350);

        // 左侧：基本信息
        var left_box = build_left_panel ();
        paned.pack1 (left_box, false, false);

        // 右侧：图表
        var right_box = build_right_panel ();
        paned.pack2 (right_box, true, false);

        add (paned);
    }

    private Gtk.Widget build_left_panel () {
        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
        box.margin = 10;

        // 电池基本信息面板
        var basic_frame = new Gtk.Frame ("电池基本信息");
        var basic_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        basic_box.margin = 10;

        capacity_label = new Gtk.Label ("--");
        capacity_label.set_markup ("<span size='48000' weight='bold'>--</span>");
        capacity_label.halign = Gtk.Align.CENTER;
        basic_box.pack_start (capacity_label, false, false, 0);

        progress_bar = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);
        progress_bar.set_value (0);
        progress_bar.set_sensitive (false);
        progress_bar.set_size_request (-1, 20);
        basic_box.pack_start (progress_bar, false, false, 5);

        status_label = new Gtk.Label ("状态: --");
        status_label.halign = Gtk.Align.START;
        basic_box.pack_start (status_label, false, false, 0);

        model_label = new Gtk.Label (null);
        model_label.halign = Gtk.Align.START;
        basic_box.pack_start (model_label, false, false, 0);

        charge_type_label = new Gtk.Label ("充电协议: --");
        charge_type_label.halign = Gtk.Align.START;
        basic_box.pack_start (charge_type_label, false, false, 0);

        basic_frame.add (basic_box);
        box.pack_start (basic_frame, false, false, 0);

        // 功率信息面板
        var power_frame = new Gtk.Frame ("功率信息");
        var power_grid = new Gtk.Grid ();
        power_grid.column_spacing = 10;
        power_grid.row_spacing = 5;
        power_grid.margin = 10;

        power_label = new Gtk.Label ("--");
        voltage_label = new Gtk.Label ("--");
        current_label = new Gtk.Label ("--");
        input_voltage_label = new Gtk.Label ("--");
        input_current_label = new Gtk.Label ("--");

        power_grid.attach (new Gtk.Label ("功率:"), 0, 0, 1, 1);
        power_grid.attach (power_label, 1, 0, 1, 1);
        power_grid.attach (new Gtk.Label ("电压:"), 0, 1, 1, 1);
        power_grid.attach (voltage_label, 1, 1, 1, 1);
        power_grid.attach (new Gtk.Label ("电流:"), 0, 2, 1, 1);
        power_grid.attach (current_label, 1, 2, 1, 1);
        power_grid.attach (new Gtk.Label ("输入电压:"), 0, 3, 1, 1);
        power_grid.attach (input_voltage_label, 1, 3, 1, 1);
        power_grid.attach (new Gtk.Label ("输入电流:"), 0, 4, 1, 1);
        power_grid.attach (input_current_label, 1, 4, 1, 1);

        power_frame.add (power_grid);
        box.pack_start (power_frame, false, false, 0);

        // 电量预估面板
        var estimate_frame = new Gtk.Frame ("电量预估");
        var estimate_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        estimate_box.margin = 10;

        estimated_time_label = new Gtk.Label ("--");
        estimated_time_label.halign = Gtk.Align.CENTER;
        estimate_box.pack_start (estimated_time_label, false, false, 0);

        estimate_frame.add (estimate_box);
        box.pack_start (estimate_frame, false, false, 0);

        // 电池健康面板
        var health_frame = new Gtk.Frame ("电池健康");
        var health_grid = new Gtk.Grid ();
        health_grid.column_spacing = 10;
        health_grid.row_spacing = 5;
        health_grid.margin = 10;

        design_capacity_label = new Gtk.Label ("--");
        current_capacity_label = new Gtk.Label ("--");
        health_label = new Gtk.Label ("--");
        cycle_label = new Gtk.Label ("--");
        lifetime_label = new Gtk.Label ("--");

        health_grid.attach (new Gtk.Label ("设计容量:"), 0, 0, 1, 1);
        health_grid.attach (design_capacity_label, 1, 0, 1, 1);
        health_grid.attach (new Gtk.Label ("当前容量:"), 0, 1, 1, 1);
        health_grid.attach (current_capacity_label, 1, 1, 1, 1);
        health_grid.attach (new Gtk.Label ("健康度:"), 0, 2, 1, 1);
        health_grid.attach (health_label, 1, 2, 1, 1);
        health_grid.attach (new Gtk.Label ("循环次数:"), 0, 3, 1, 1);
        health_grid.attach (cycle_label, 1, 3, 1, 1);
        health_grid.attach (new Gtk.Label ("寿命状态:"), 0, 4, 1, 1);
        health_grid.attach (lifetime_label, 1, 4, 1, 1);

        health_frame.add (health_grid);
        box.pack_start (health_frame, false, false, 0);

        // 历史记录面板
        var history_frame = new Gtk.Frame ("历史记录");
        var history_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        history_box.margin = 10;

        last_disconnect_label = new Gtk.Label ("上次断开充电: --");
        last_disconnect_label.halign = Gtk.Align.START;
        history_box.pack_start (last_disconnect_label, false, false, 0);

        var stats_grid = new Gtk.Grid ();
        stats_grid.column_spacing = 10;
        stats_grid.row_spacing = 5;
        stats_grid.margin_top = 5;

        charging_time_label = new Gtk.Label ("--");
        discharging_time_label = new Gtk.Label ("--");

        stats_grid.attach (new Gtk.Label ("今日充电:"), 0, 0, 1, 1);
        stats_grid.attach (charging_time_label, 1, 0, 1, 1);
        stats_grid.attach (new Gtk.Label ("今日放电:"), 0, 1, 1, 1);
        stats_grid.attach (discharging_time_label, 1, 1, 1, 1);

        history_box.pack_start (stats_grid, false, false, 0);

        history_frame.add (history_box);
        box.pack_start (history_frame, false, false, 0);

        scrolled.add (box);
        return scrolled;
    }

    private Gtk.Widget build_right_panel () {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
        box.margin = 10;

        // 工具栏
        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);

        var time_label = new Gtk.Label ("时间范围:");
        toolbar.pack_start (time_label, false, false, 0);

        time_range_combo = new Gtk.ComboBoxText ();
        time_range_combo.append ("1", "1小时");
        time_range_combo.append ("6", "6小时");
        time_range_combo.append ("24", "24小时");
        time_range_combo.append ("168", "7天");
        time_range_combo.set_active_id ("1");
        time_range_combo.changed.connect (() => {
            int hours = int.parse (time_range_combo.get_active_id ());
            chart.set_time_range (hours);
            chart.set_data (history.get_entries (hours));
        });
        toolbar.pack_start (time_range_combo, false, false, 0);

        var chart_label = new Gtk.Label ("曲线:");
        toolbar.pack_start (chart_label, false, false, 0);

        var chart_combo = new Gtk.ComboBoxText ();
        chart_combo.append ("0", "电量");
        chart_combo.append ("1", "充电功率");
        chart_combo.append ("2", "放电功率");
        chart_combo.set_active_id ("0");
        chart_combo.changed.connect (() => {
            int mode = int.parse (chart_combo.get_active_id ());
            chart.set_chart_mode (mode);
        });
        toolbar.pack_start (chart_combo, false, false, 0);

        var refresh_button = new Gtk.Button.with_label ("刷新");
        refresh_button.clicked.connect (() => {
            update_data ();
        });
        toolbar.pack_end (refresh_button, false, false, 0);

        var minimize_button = new Gtk.Button.with_label ("最小化");
        minimize_button.clicked.connect (() => {
            hide ();
        });
        toolbar.pack_end (minimize_button, false, false, 0);

        box.pack_start (toolbar, false, false, 0);

        // 图表
        chart = new BatteryChart ();
        box.pack_start (chart, true, true, 0);

        return box;
    }

    public void update_data () {
        if (!battery.update ()) {
            capacity_label.set_markup ("<span size='48000' weight='bold'>--</span>");
            progress_bar.set_value (0);
            status_label.set_text ("状态: 未检测到电池");
            model_label.set_text ("型号: -- | 技术: --");
            charge_type_label.set_text ("充电协议: --");
            power_label.set_text ("--");
            voltage_label.set_text ("--");
            current_label.set_text ("--");
            input_voltage_label.set_text ("--");
            input_current_label.set_text ("--");
            estimated_time_label.set_text ("--");
            design_capacity_label.set_text ("--");
            current_capacity_label.set_text ("--");
            health_label.set_text ("--");
            cycle_label.set_text ("--");
            lifetime_label.set_text ("--");
            return;
        }

        // 电池基本信息
        capacity_label.set_markup ("<span size='48000' weight='bold'>%d%%</span>".printf (battery.capacity));
        progress_bar.set_value (battery.capacity);
        status_label.set_text ("状态: %s".printf (battery.get_status_text ()));

        var model_text = "型号: %s | 技术: %s".printf (battery.model_name, battery.technology);
        if (battery.model_name == "") {
            model_text = "型号: 未知 | 技术: %s".printf (battery.technology);
        }
        model_label.set_text (model_text);

        charge_type_label.set_text ("充电协议: %s".printf (battery.get_charge_type_text ()));

        // 功率信息
        power_label.set_text ("%.2f W".printf (battery.display_power_watts));
        voltage_label.set_text ("%.2f V".printf (battery.voltage_volts));
        current_label.set_text ("%.2f A".printf (battery.current_amps));
        input_voltage_label.set_text ("%.2f V".printf (battery.input_voltage));
        input_current_label.set_text ("%.2f A".printf (battery.input_current));

        // 电量预估
        estimated_time_label.set_text (battery.get_estimated_time ());

        // 电池健康
        design_capacity_label.set_text ("%.2f Wh".printf (battery.energy_full_design));
        current_capacity_label.set_text ("%.2f Wh".printf (battery.energy_full));
        health_label.set_text ("%.1f%% (%s)".printf (battery.health_percent, battery.get_health_status ()));
        cycle_label.set_text ("%d".printf (battery.cycle_count));

        if (battery.health_percent > 90) {
            lifetime_label.set_text ("优秀");
        } else if (battery.health_percent > 80) {
            lifetime_label.set_text ("良好");
        } else if (battery.health_percent > 70) {
            lifetime_label.set_text ("一般");
        } else {
            lifetime_label.set_text ("需关注");
        }

        // 更新窗口标题
        title = "%d%% %s - 电池监控器".printf (battery.capacity, battery.get_status_text ());
    }

    public void update_history (HistoryManager history) {
        int64 last_disconnect = history.get_last_disconnect_time ();
        if (last_disconnect > 0) {
            var dt = new GLib.DateTime.from_unix_local (last_disconnect);
            last_disconnect_label.set_text ("上次断开充电: %s".printf (dt.format ("%m-%d %H:%M")));
        }

        var today_entries = history.get_entries (24);

        int charging_minutes = 0;
        int discharging_minutes = 0;

        for (int i = 0; i < today_entries.get_length (); i++) {
            var entry = today_entries.get_object_element (i);
            int64 timestamp = entry.get_int_member ("timestamp");
            string status = entry.get_string_member ("status");

            if (i > 0) {
                var prev_entry = today_entries.get_object_element (i - 1);
                int64 prev_timestamp = prev_entry.get_int_member ("timestamp");
                int diff = (int) (timestamp - prev_timestamp);
                if (diff > 0 && diff < 3600) {
                    if (status == "Charging") {
                        charging_minutes += diff / 60;
                    } else if (status == "Discharging") {
                        discharging_minutes += diff / 60;
                    }
                }
            }
        }

        charging_time_label.set_text ("%d小时%d分钟".printf (charging_minutes / 60, charging_minutes % 60));
        discharging_time_label.set_text ("%d小时%d分钟".printf (discharging_minutes / 60, discharging_minutes % 60));

        int hours = int.parse (time_range_combo.get_active_id ());
        chart.set_data (history.get_entries (hours));
    }
}
