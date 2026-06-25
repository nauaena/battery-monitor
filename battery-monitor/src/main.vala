using Gtk;

public class BatteryMonitor : Gtk.Application {
    private BatteryData battery;

    public BatteryMonitor () {
        Object (
            application_id: "com.github.battery-monitor",
            flags: ApplicationFlags.FLAGS_NONE
        );
        battery = new BatteryData ();
    }

    protected override void activate () {
        var window = new Gtk.ApplicationWindow (this);
        window.title = "电池监控器";
        window.set_default_size (400, 300);

        if (battery.update ()) {
            var label = new Label (null);
            label.set_markup (
                "<b>电池信息</b>\n" +
                "电量: %d%%\n".printf (battery.capacity) +
                "状态: %s\n".printf (battery.get_status_text ()) +
                "功率: %.2f W\n".printf (battery.power_watts) +
                "健康度: %.1f%%".printf (battery.health_percent)
            );
            window.add (label);
        } else {
            var label = new Label ("未检测到电池");
            window.add (label);
        }

        window.show_all ();
    }

    public static int main (string[] args) {
        var app = new BatteryMonitor ();
        return app.run (args);
    }
}
