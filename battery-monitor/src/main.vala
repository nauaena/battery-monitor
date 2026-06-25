using Gtk;

public class BatteryMonitor : Gtk.Application {
    public BatteryMonitor () {
        Object (
            application_id: "com.github.battery-monitor",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate () {
        var window = new ApplicationWindow (this);
        window.title = "电池监控器";
        window.set_default_size (400, 300);
        window.show_all ();
    }

    public static int main (string[] args) {
        var app = new BatteryMonitor ();
        return app.run (args);
    }
}