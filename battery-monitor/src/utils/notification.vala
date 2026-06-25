public class NotificationManager : Object {
    private BatteryData battery;
    private Config config;

    private bool low_battery_notified;
    private bool full_battery_notified;
    private bool health_notified;
    private int last_capacity;

    public NotificationManager (BatteryData battery, Config config) {
        this.battery = battery;
        this.config = config;
        this.low_battery_notified = false;
        this.full_battery_notified = false;
        this.health_notified = false;
        this.last_capacity = battery.capacity;
    }

    public void check () {
        if (!battery.update ()) return;

        if (config.low_battery_alert) {
            check_low_battery ();
        }

        if (config.full_battery_alert) {
            check_full_battery ();
        }

        if (config.health_alert) {
            check_health ();
        }

        last_capacity = battery.capacity;
    }

    private void check_low_battery () {
        if (battery.capacity <= config.low_battery_threshold &&
            battery.status != "Charging" &&
            !low_battery_notified) {
            send_notification (
                "低电量警告",
                "电量已低于 %d%%，请及时充电".printf (config.low_battery_threshold),
                "battery-caution"
            );
            low_battery_notified = true;
        }

        if (battery.capacity > config.low_battery_threshold) {
            low_battery_notified = false;
        }
    }

    private void check_full_battery () {
        if (battery.status == "Full" && !full_battery_notified) {
            send_notification (
                "充电完成",
                "电池已充满",
                "battery-full-charging"
            );
            full_battery_notified = true;
        }

        if (battery.status != "Full") {
            full_battery_notified = false;
        }
    }

    private void check_health () {
        if (battery.health_percent < 70 && battery.health_percent > 0 && !health_notified) {
            send_notification (
                "电池健康警告",
                "电池健康度为 %.1f%%，建议更换电池".printf (battery.health_percent),
                "battery-caution"
            );
            health_notified = true;
        }
    }

    private void send_notification (string title, string body, string icon) {
        var notification = new GLib.Notification (title);
        notification.set_body (body);
        notification.set_icon (new GLib.ThemedIcon (icon));
        GLib.Application.get_default ().send_notification (null, notification);
    }
}