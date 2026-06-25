using Gtk;

public class BatteryMonitor : Gtk.Application {
    private BatteryData battery;
    private Config config;
    private TrayIcon tray;
    private Gtk.ApplicationWindow main_window;
    private uint update_timeout;

    public BatteryMonitor () {
        Object (
            application_id: "com.github.battery-monitor",
            flags: ApplicationFlags.FLAGS_NONE
        );
        battery = new BatteryData ();
        config = Config.get_instance ();
    }

    protected override void startup () {
        base.startup ();

        tray = new TrayIcon (battery, config);

        tray.show_main_window.connect (() => {
            if (main_window == null) {
                create_main_window ();
            }
            main_window.present ();
        });

        tray.show_details.connect (() => {
            show_details_window ();
        });

        tray.quit_requested.connect (() => {
            quit ();
        });

        update_timeout = Timeout.add_seconds (config.refresh_interval, () => {
            tray.update_icon ();
            return true;
        });
    }

    protected override void activate () {
        if (main_window == null) {
            create_main_window ();
        }
        main_window.present ();
    }

    private void create_main_window () {
        main_window = new Gtk.ApplicationWindow (this);
        main_window.title = "电池监控器";
        main_window.set_default_size (400, 300);
        main_window.delete_event.connect (() => {
            main_window.hide ();
            return true;
        });

        update_main_window ();
    }

    private void update_main_window () {
        if (main_window == null) return;

        main_window.foreach ((child) => {
            main_window.remove (child);
        });

        if (battery.update ()) {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            box.margin = 20;

            var title_label = new Gtk.Label (null);
            title_label.set_markup ("<b>电池信息</b>");
            box.add (title_label);

            var info_label = new Gtk.Label (
                "电量: %d%%\n".printf (battery.capacity) +
                "状态: %s\n".printf (battery.get_status_text ()) +
                "功率: %.2f W\n".printf (battery.power_watts) +
                "电压: %.2f V\n".printf (battery.voltage_volts) +
                "电流: %.2f A\n".printf (battery.current_amps) +
                "健康度: %.1f%%\n".printf (battery.health_percent) +
                "循环次数: %d".printf (battery.cycle_count)
            );
            info_label.xalign = 0;
            box.add (info_label);

            main_window.add (box);
        } else {
            var label = new Gtk.Label ("未检测到电池");
            main_window.add (label);
        }

        main_window.show_all ();
    }

    private void show_details_window () {
        var dialog = new Gtk.Dialog.with_buttons (
            "电量详情",
            main_window,
            Gtk.DialogFlags.MODAL,
            "关闭", Gtk.ResponseType.CLOSE
        );
        dialog.set_default_size (350, 400);

        var box = dialog.get_content_area ();
        box.margin = 15;

        if (battery.update ()) {
            var info = new Gtk.Label (
                "<b>详细信息</b>\n\n" +
                "电量: %d%%\n".printf (battery.capacity) +
                "状态: %s\n".printf (battery.get_status_text ()) +
                "制造商: %s\n".printf (battery.manufacturer) +
                "型号: %s\n".printf (battery.model_name) +
                "技术: %s\n".printf (battery.technology) +
                "功率: %.2f W\n".printf (battery.power_watts) +
                "电压: %.2f V\n".printf (battery.voltage_volts) +
                "电流: %.2f A\n".printf (battery.current_amps) +
                "当前能量: %.2f Wh\n".printf (battery.energy_now) +
                "满充能量: %.2f Wh\n".printf (battery.energy_full) +
                "设计容量: %.2f Wh\n".printf (battery.energy_full_design) +
                "健康度: %.1f%% (%s)\n".printf (battery.health_percent, battery.get_health_status ()) +
                "循环次数: %d\n".printf (battery.cycle_count) +
                "\n%s".printf (battery.get_estimated_time ())
            );
            info.use_markup = true;
            info.xalign = 0;
            box.add (info);
        } else {
            var label = new Gtk.Label ("未检测到电池");
            box.add (label);
        }

        dialog.show_all ();
        dialog.run ();
        dialog.destroy ();
    }

    public static int main (string[] args) {
        var app = new BatteryMonitor ();
        return app.run (args);
    }
}
