using Gtk;
using AppIndicator;

public class TrayIcon : Object {
    private AppIndicator.Indicator indicator;
    private BatteryData battery;
    private Config config;
    private Gtk.Menu menu;
    private Gtk.MenuItem show_main_item;
    private Gtk.MenuItem show_details_item;
    private Gtk.MenuItem settings_item;
    private Gtk.CheckMenuItem autostart_item;
    private Gtk.MenuItem quit_item;

    public signal void show_main_window ();
    public signal void show_details ();
    public signal void open_settings ();
    public signal void quit_requested ();

    public TrayIcon (BatteryData battery, Config config) {
        this.battery = battery;
        this.config = config;

        indicator = new AppIndicator.Indicator (
            "battery-monitor",
            "battery-full",
            AppIndicator.IndicatorCategory.APPLICATION_STATUS
        );
        indicator.set_status (AppIndicator.IndicatorStatus.ACTIVE);

        create_menu ();
        update_icon ();
    }

    private void create_menu () {
        menu = new Gtk.Menu ();

        show_main_item = new Gtk.MenuItem.with_label ("显示主窗口");
        show_main_item.activate.connect (() => {
            show_main_window ();
        });
        menu.add (show_main_item);

        show_details_item = new Gtk.MenuItem.with_label ("显示电量详情");
        show_details_item.activate.connect (() => {
            show_details ();
        });
        menu.add (show_details_item);

        menu.add (new Gtk.SeparatorMenuItem ());

        autostart_item = new Gtk.CheckMenuItem.with_label ("开机自启动");
        autostart_item.active = config.autostart;
        autostart_item.toggled.connect (() => {
            config.autostart = autostart_item.active;
            config.save ();
            update_autostart ();
        });
        menu.add (autostart_item);

        menu.add (new Gtk.SeparatorMenuItem ());

        settings_item = new Gtk.MenuItem.with_label ("设置");
        settings_item.activate.connect (() => {
            open_settings ();
        });
        menu.add (settings_item);

        menu.add (new Gtk.SeparatorMenuItem ());

        quit_item = new Gtk.MenuItem.with_label ("退出程序");
        quit_item.activate.connect (() => {
            quit_requested ();
        });
        menu.add (quit_item);

        menu.show_all ();
        indicator.set_menu (menu);
    }

    public void update_icon () {
        if (!battery.update ()) {
            indicator.set_icon_full ("battery-missing", "未检测到电池");
            indicator.set_title ("电池监控器 - 未检测到电池");
            return;
        }

        string icon_name = get_icon_name ();
        indicator.set_icon_full (icon_name, "电池电量 %d%%".printf (battery.capacity));
        indicator.set_title ("电池监控器 - %d%% %s".printf (battery.capacity, battery.get_status_text ()));
    }

    private string get_icon_name () {
        bool charging = (battery.status == "Charging");

        if (battery.capacity <= 20) {
            return charging ? "battery-caution-charging" : "battery-caution";
        } else if (battery.capacity <= 40) {
            return charging ? "battery-low-charging" : "battery-low";
        } else if (battery.capacity <= 60) {
            return charging ? "battery-good-charging" : "battery-good";
        } else if (battery.capacity <= 80) {
            return charging ? "battery-good-charging" : "battery-good";
        } else {
            return charging ? "battery-full-charging" : "battery-full";
        }
    }

    private void update_autostart () {
        string desktop_file = Path.build_filename (
            Environment.get_user_config_dir (),
            "autostart",
            "battery-monitor.desktop"
        );

        if (config.autostart) {
            DirUtils.create_with_parents (Path.get_dirname (desktop_file), 0755);
            try {
                string template = """[Desktop Entry]
Type=Application
Name=Battery Monitor
Exec=battery-monitor
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
""";
                FileUtils.set_contents (desktop_file, template);
            } catch (Error e) {
                stderr.printf ("创建自启动文件失败: %s\n", e.message);
            }
        } else {
            if (FileUtils.test (desktop_file, FileTest.EXISTS)) {
                FileUtils.remove (desktop_file);
            }
        }
    }

    public void show_popup (int x, int y) {
        var popover = new Gtk.Popover (null);
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        box.margin = 10;

        var title_label = new Gtk.Label (null);
        title_label.set_markup ("<b>电池信息</b>");
        box.add (title_label);

        if (battery.update ()) {
            var info_label = new Gtk.Label (
                "电量: %d%%\n".printf (battery.capacity) +
                "状态: %s\n".printf (battery.get_status_text ()) +
                "功率: %.2f W\n".printf (battery.power_watts) +
                "健康度: %.1f%%".printf (battery.health_percent)
            );
            info_label.xalign = 0;
            box.add (info_label);
        } else {
            var label = new Gtk.Label ("未检测到电池");
            box.add (label);
        }

        popover.add (box);
        popover.set_position (Gtk.PositionType.BOTTOM);
        popover.show_all ();
        popover.popup ();
    }
}
