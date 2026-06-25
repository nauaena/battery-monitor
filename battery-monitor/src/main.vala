using Gtk;

public class BatteryMonitor : Gtk.Application {
    private BatteryData battery;
    private Config config;
    private TrayIcon tray;
    private MainWindow main_window;
    private FloatingWidget widget;
    private HistoryManager history;
    private NotificationManager notification;
    private AutostartManager autostart;
    private uint update_timeout;
    private bool start_minimized;

    public BatteryMonitor () {
        Object (
            application_id: "com.github.battery-monitor",
            flags: ApplicationFlags.HANDLES_COMMAND_LINE
        );
        battery = new BatteryData ();
        config = Config.get_instance ();
        history = new HistoryManager ();
        notification = new NotificationManager (battery, config);
        autostart = new AutostartManager ();
        start_minimized = false;
    }

    protected override int command_line (ApplicationCommandLine cmdline) {
        string[] args = cmdline.get_arguments ();
        for (int i = 1; i < args.length; i++) {
            if (args[i] == "--start-minimized") {
                start_minimized = true;
            }
        }
        activate ();
        return 0;
    }

    protected override void startup () {
        base.startup ();

        autostart.update (config);

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

        widget = new FloatingWidget (battery, config);

        update_timeout = Timeout.add_seconds (config.refresh_interval, () => {
            tray.update_icon ();
            if (battery.update ()) {
                history.add_entry (battery.capacity, battery.status, battery.power_watts, battery.voltage_volts);
                notification.check ();
            }
            if (main_window != null && main_window.get_visible ()) {
                main_window.update_data ();
                main_window.update_history (history);
            }
            widget.update_data ();
            return true;
        });

        widget.show_all ();
    }

    protected override void activate () {
        if (!start_minimized) {
            if (main_window == null) {
                create_main_window ();
            }
            main_window.present ();
        }
    }

    private void create_main_window () {
        main_window = new MainWindow (this, battery, history);
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
