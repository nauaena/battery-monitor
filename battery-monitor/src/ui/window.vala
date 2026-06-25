using Gtk;

public class MainWindow : Gtk.ApplicationWindow {
    private BatteryData battery;
    private Gtk.Label capacity_label;
    private Gtk.Label status_label;
    private Gtk.Label model_label;
    private Gtk.Label power_label;
    private Gtk.Label voltage_label;
    private Gtk.Label current_label;
    private Gtk.Label estimated_time_label;
    private Gtk.Label design_capacity_label;
    private Gtk.Label current_capacity_label;
    private Gtk.Label health_label;
    private Gtk.Label cycle_label;
    private Gtk.Label lifetime_label;
    private Gtk.Scale progress_bar;

    public MainWindow (Gtk.Application app, BatteryData battery) {
        Object (application: app);
        this.battery = battery;

        title = "电池监控器";
        set_default_size (450, 550);
        set_border_width (10);

        delete_event.connect (() => {
            hide ();
            return true;
        });

        build_ui ();
        update_data ();
    }

    private void build_ui () {
        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
        main_box.margin_top = 10;
        main_box.margin_bottom = 10;
        main_box.margin_start = 15;
        main_box.margin_end = 15;

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
        progress_bar.set_size_request (-1, 25);
        basic_box.pack_start (progress_bar, false, false, 5);

        status_label = new Gtk.Label ("状态: --");
        status_label.halign = Gtk.Align.START;
        basic_box.pack_start (status_label, false, false, 0);

        model_label = new Gtk.Label (null);
        model_label.halign = Gtk.Align.START;
        basic_box.pack_start (model_label, false, false, 0);

        basic_frame.add (basic_box);
        main_box.pack_start (basic_frame, false, false, 0);

        // 功率信息面板
        var power_frame = new Gtk.Frame ("功率信息");
        var power_grid = new Gtk.Grid ();
        power_grid.column_spacing = 10;
        power_grid.row_spacing = 5;
        power_grid.margin = 10;

        power_label = new Gtk.Label ("--");
        voltage_label = new Gtk.Label ("--");
        current_label = new Gtk.Label ("--");

        power_grid.attach (new Gtk.Label ("当前功率:"), 0, 0, 1, 1);
        power_grid.attach (power_label, 1, 0, 1, 1);
        power_grid.attach (new Gtk.Label ("电压:"), 0, 1, 1, 1);
        power_grid.attach (voltage_label, 1, 1, 1, 1);
        power_grid.attach (new Gtk.Label ("电流:"), 0, 2, 1, 1);
        power_grid.attach (current_label, 1, 2, 1, 1);

        power_frame.add (power_grid);
        main_box.pack_start (power_frame, false, false, 0);

        // 电量预估面板
        var estimate_frame = new Gtk.Frame ("电量预估");
        var estimate_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        estimate_box.margin = 10;

        estimated_time_label = new Gtk.Label ("--");
        estimated_time_label.halign = Gtk.Align.CENTER;
        estimate_box.pack_start (estimated_time_label, false, false, 0);

        estimate_frame.add (estimate_box);
        main_box.pack_start (estimate_frame, false, false, 0);

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
        main_box.pack_start (health_frame, false, false, 0);

        // 底部按钮
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        button_box.halign = Gtk.Align.CENTER;

        var refresh_button = new Gtk.Button.with_label ("刷新");
        refresh_button.clicked.connect (() => {
            update_data ();
        });
        button_box.pack_start (refresh_button, false, false, 0);

        var minimize_button = new Gtk.Button.with_label ("最小化");
        minimize_button.clicked.connect (() => {
            hide ();
        });
        button_box.pack_start (minimize_button, false, false, 0);

        main_box.pack_end (button_box, false, false, 0);

        add (main_box);
    }

    public void update_data () {
        if (!battery.update ()) {
            capacity_label.set_markup ("<span size='48000' weight='bold'>--</span>");
            progress_bar.set_value (0);
            status_label.set_text ("状态: 未检测到电池");
            model_label.set_text ("型号: -- | 技术: --");
            power_label.set_text ("--");
            voltage_label.set_text ("--");
            current_label.set_text ("--");
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

        // 功率信息
        power_label.set_text ("%.2f W".printf (battery.power_watts));
        voltage_label.set_text ("%.2f V".printf (battery.voltage_volts));
        current_label.set_text ("%.2f A".printf (battery.current_amps));

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
    }
}