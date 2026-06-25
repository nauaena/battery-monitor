using Gtk;

public class SettingsWindow : Gtk.Dialog {
    private Config config;

    private Gtk.CheckButton autostart_check;
    private Gtk.CheckButton start_minimized_check;
    private Gtk.ComboBoxText theme_combo;

    private Gtk.CheckButton low_battery_alert_check;
    private Gtk.SpinButton low_battery_threshold_spin;
    private Gtk.CheckButton full_battery_alert_check;
    private Gtk.CheckButton health_alert_check;

    private Gtk.Scale widget_opacity_scale;
    private Gtk.Label opacity_value_label;

    private Gtk.ComboBoxText refresh_interval_combo;

    public SettingsWindow (Gtk.Window? parent) {
        Object (
            title: "设置",
            transient_for: parent,
            modal: true,
            default_width: 420,
            default_height: 500
        );
        config = Config.get_instance ();
        build_ui ();
        load_values ();
    }

    private void build_ui () {
        var content = get_content_area ();
        content.margin = 10;
        content.spacing = 10;

        // 通用设置
        var general_frame = new Gtk.Frame ("通用设置");
        var general_grid = new Gtk.Grid ();
        general_grid.column_spacing = 10;
        general_grid.row_spacing = 8;
        general_grid.margin = 10;

        autostart_check = new Gtk.CheckButton.with_label ("开机自启动");
        start_minimized_check = new Gtk.CheckButton.with_label ("启动时最小化到托盘");
        theme_combo = new Gtk.ComboBoxText ();
        theme_combo.append ("default", "跟随系统");
        theme_combo.append ("light", "浅色主题");
        theme_combo.append ("dark", "深色主题");
        theme_combo.set_active_id ("default");

        var general_label_autostart = new Gtk.Label ("开机自启动:");
        general_label_autostart.halign = Gtk.Align.START;
        var general_label_minimized = new Gtk.Label ("启动时最小化到托盘:");
        general_label_minimized.halign = Gtk.Align.START;
        var general_label_theme = new Gtk.Label ("主题选择:");
        general_label_theme.halign = Gtk.Align.START;

        general_grid.attach (general_label_autostart, 0, 0, 1, 1);
        general_grid.attach (autostart_check, 1, 0, 1, 1);
        general_grid.attach (general_label_minimized, 0, 1, 1, 1);
        general_grid.attach (start_minimized_check, 1, 1, 1, 1);
        general_grid.attach (general_label_theme, 0, 2, 1, 1);
        general_grid.attach (theme_combo, 1, 2, 1, 1);

        general_frame.add (general_grid);
        content.add (general_frame);

        // 通知设置
        var notify_frame = new Gtk.Frame ("通知设置");
        var notify_grid = new Gtk.Grid ();
        notify_grid.column_spacing = 10;
        notify_grid.row_spacing = 8;
        notify_grid.margin = 10;

        low_battery_alert_check = new Gtk.CheckButton.with_label ("启用低电量告警");
        low_battery_threshold_spin = new Gtk.SpinButton.with_range (5, 50, 1);
        low_battery_threshold_spin.set_value (20);
        full_battery_alert_check = new Gtk.CheckButton.with_label ("充满电通知");
        health_alert_check = new Gtk.CheckButton.with_label ("电池健康告警");

        var notify_label_low = new Gtk.Label ("低电量告警:");
        notify_label_low.halign = Gtk.Align.START;
        var notify_label_threshold = new Gtk.Label ("低电量阈值 (%):");
        notify_label_threshold.halign = Gtk.Align.START;
        var notify_label_full = new Gtk.Label ("充满电通知:");
        notify_label_full.halign = Gtk.Align.START;
        var notify_label_health = new Gtk.Label ("电池健康告警:");
        notify_label_health.halign = Gtk.Align.START;

        notify_grid.attach (notify_label_low, 0, 0, 1, 1);
        notify_grid.attach (low_battery_alert_check, 1, 0, 1, 1);
        notify_grid.attach (notify_label_threshold, 0, 1, 1, 1);
        notify_grid.attach (low_battery_threshold_spin, 1, 1, 1, 1);
        notify_grid.attach (notify_label_full, 0, 2, 1, 1);
        notify_grid.attach (full_battery_alert_check, 1, 2, 1, 1);
        notify_grid.attach (notify_label_health, 0, 3, 1, 1);
        notify_grid.attach (health_alert_check, 1, 3, 1, 1);

        notify_frame.add (notify_grid);
        content.add (notify_frame);

        // 刷新设置
        var refresh_frame = new Gtk.Frame ("刷新设置");
        var refresh_grid = new Gtk.Grid ();
        refresh_grid.column_spacing = 10;
        refresh_grid.row_spacing = 8;
        refresh_grid.margin = 10;

        refresh_interval_combo = new Gtk.ComboBoxText ();
        refresh_interval_combo.append ("1", "1 秒");
        refresh_interval_combo.append ("2", "2 秒");
        refresh_interval_combo.append ("5", "5 秒");
        refresh_interval_combo.append ("10", "10 秒");
        refresh_interval_combo.append ("30", "30 秒");
        refresh_interval_combo.set_active_id ("2");

        var refresh_label = new Gtk.Label ("数据刷新间隔:");
        refresh_label.halign = Gtk.Align.START;

        refresh_grid.attach (refresh_label, 0, 0, 1, 1);
        refresh_grid.attach (refresh_interval_combo, 1, 0, 1, 1);

        refresh_frame.add (refresh_grid);
        content.add (refresh_frame);

        // 小组件设置
        var widget_frame = new Gtk.Frame ("小组件设置");
        var widget_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        widget_box.margin = 10;

        var widget_label = new Gtk.Label ("透明度:");
        widget_label.halign = Gtk.Align.START;
        widget_box.pack_start (widget_label, false, false, 0);

        var opacity_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
        widget_opacity_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0.1, 1.0, 0.05);
        widget_opacity_scale.set_value (0.9);
        widget_opacity_scale.set_hexpand (true);
        widget_opacity_scale.value_changed.connect (() => {
            opacity_value_label.set_text ("%.0f%%".printf (widget_opacity_scale.get_value () * 100));
        });
        opacity_box.pack_start (widget_opacity_scale, true, true, 0);

        opacity_value_label = new Gtk.Label ("90%");
        opacity_box.pack_start (opacity_value_label, false, false, 0);

        widget_box.pack_start (opacity_box, false, false, 0);

        widget_frame.add (widget_box);
        content.add (widget_frame);

        // 按钮
        add_button ("取消", ResponseType.CANCEL);
        add_button ("保存", ResponseType.ACCEPT);
        set_default_response (ResponseType.ACCEPT);

        response.connect ((response_id) => {
            if (response_id == ResponseType.ACCEPT) {
                save_values ();
                config.save ();
            }
            destroy ();
        });

        show_all ();
    }

    public void load_values () {
        autostart_check.active = config.autostart;
        start_minimized_check.active = config.start_minimized;
        low_battery_alert_check.active = config.low_battery_alert;
        low_battery_threshold_spin.set_value (config.low_battery_threshold);
        full_battery_alert_check.active = config.full_battery_alert;
        health_alert_check.active = config.health_alert;
        widget_opacity_scale.set_value (config.widget_opacity);
        opacity_value_label.set_text ("%.0f%%".printf (config.widget_opacity * 100));
        refresh_interval_combo.set_active_id (config.refresh_interval.to_string ());
    }

    public void save_values () {
        config.autostart = autostart_check.active;
        config.start_minimized = start_minimized_check.active;
        config.low_battery_alert = low_battery_alert_check.active;
        config.low_battery_threshold = (int) low_battery_threshold_spin.get_value ();
        config.full_battery_alert = full_battery_alert_check.active;
        config.health_alert = health_alert_check.active;
        config.widget_opacity = widget_opacity_scale.get_value ();

        string? interval_id = refresh_interval_combo.get_active_id ();
        if (interval_id != null) {
            config.refresh_interval = int.parse (interval_id);
        }
    }
}
