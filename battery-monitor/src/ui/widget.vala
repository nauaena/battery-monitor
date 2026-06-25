using Gtk;

public class FloatingWidget : Gtk.Window {
    private BatteryData battery;
    private Config config;
    private Gtk.Label capacity_label;
    private Gtk.Label status_label;
    private Gtk.Image status_icon;
    private bool dragging = false;
    private double drag_x;
    private double drag_y;
    private bool minimized = false;
    private Gtk.CssProvider css_provider;

    public FloatingWidget (BatteryData battery, Config config) {
        Object (
            type: Gtk.WindowType.POPUP,
            decorated: false,
            skip_taskbar_hint: true,
            skip_pager_hint: true
        );
        this.battery = battery;
        this.config = config;

        set_app_paintable (true);
        set_visual (get_screen ().get_rgba_visual ());

        set_size_request (120, 60);
        set_default_size (120, 60);

        position_window ();
        build_ui ();
        apply_styles ();
        setup_events ();
        update_data ();
    }

    private void position_window () {
        var screen = get_screen ();
        int screen_width = screen.get_width ();
        int screen_height = screen.get_height ();
        move (screen_width - 150, screen_height - 100);
    }

    private void build_ui () {
        var main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
        main_box.margin = 8;
        main_box.margin_top = 5;
        main_box.margin_bottom = 5;
        main_box.margin_start = 10;
        main_box.margin_end = 10;

        capacity_label = new Gtk.Label ("--");
        capacity_label.get_style_context ().add_class ("widget-capacity");
        main_box.pack_start (capacity_label, false, false, 0);

        var info_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);

        status_icon = new Gtk.Image ();
        status_icon.set_pixel_size (14);
        info_box.pack_start (status_icon, false, false, 0);

        status_label = new Gtk.Label ("--");
        status_label.get_style_context ().add_class ("widget-status");
        info_box.pack_start (status_label, false, false, 0);

        main_box.pack_start (info_box, false, false, 0);

        add (main_box);
    }

    private void apply_styles () {
        css_provider = new Gtk.CssProvider ();
        string css = """
            .widget-window {
                background-color: rgba(30, 30, 30, 0.85);
                border-radius: 12px;
                border: 1px solid rgba(255, 255, 255, 0.15);
            }
            .widget-capacity {
                color: white;
                font-size: 22px;
                font-weight: bold;
                font-family: monospace;
            }
            .widget-status {
                color: rgba(255, 255, 255, 0.7);
                font-size: 10px;
            }
            .widget-charging {
                color: #4CAF50;
                font-size: 14px;
            }
        """;

        try {
            css_provider.load_from_data (css, -1);
            Gtk.StyleContext.add_provider_for_screen (
                get_screen (),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        } catch (Error e) {
            stderr.printf ("加载 CSS 失败: %s\n", e.message);
        }

        get_style_context ().add_class ("widget-window");
    }

    private void setup_events () {
        button_press_event.connect ((event) => {
            if (event.button == 1) {
                dragging = true;
                drag_x = event.x_root;
                drag_y = event.y_root;
                return true;
            } else if (event.button == 3) {
                show_context_menu ();
                return true;
            }
            return false;
        });

        button_release_event.connect ((event) => {
            if (event.button == 1) {
                dragging = false;
                return true;
            }
            return false;
        });

        motion_notify_event.connect ((event) => {
            if (dragging) {
                double dx = event.x_root - drag_x;
                double dy = event.y_root - drag_y;
                int x, y;
                get_position (out x, out y);
                move ((int) (x + dx), (int) (y + dy));
                drag_x = event.x_root;
                drag_y = event.y_root;
                return true;
            }
            return false;
        });
    }

    private void show_context_menu () {
        var menu = new Gtk.Menu ();

        var hide_item = new Gtk.MenuItem.with_label ("隐藏");
        hide_item.activate.connect (() => {
            hide ();
            minimized = true;
        });
        menu.add (hide_item);

        menu.add (new Gtk.SeparatorMenuItem ());

        var opacity_label = new Gtk.MenuItem.with_label ("透明度");
        opacity_label.set_sensitive (false);
        menu.add (opacity_label);

        double[] opacities = { 0.5, 0.7, 0.85, 1.0 };
        foreach (double opa in opacities) {
            var opa_item = new Gtk.CheckMenuItem.with_label ("%.0f%%".printf (opa * 100));
            opa_item.active = (config.widget_opacity - opa).abs () < 0.05;
            opa_item.toggled.connect (() => {
                if (opa_item.active) {
                    config.widget_opacity = opa;
                    set_opacity (opa);
                    config.save ();
                }
            });
            menu.add (opa_item);
        }

        menu.add (new Gtk.SeparatorMenuItem ());

        var quit_item = new Gtk.MenuItem.with_label ("退出");
        quit_item.activate.connect (() => {
            Gtk.main_quit ();
        });
        menu.add (quit_item);

        menu.show_all ();
        menu.popup_at_pointer (null);
    }

    public void update_data () {
        if (!battery.update ()) {
            capacity_label.set_text ("--");
            status_label.set_text ("未检测");
            status_icon.set_from_icon_name ("battery-missing", Gtk.IconSize.SMALL_TOOLBAR);
            return;
        }

        capacity_label.set_text ("%d%%".printf (battery.capacity));
        status_label.set_text (battery.get_status_text ());

        if (battery.status == "Charging") {
            status_icon.set_from_icon_name ("battery-good-charging", Gtk.IconSize.SMALL_TOOLBAR);
        } else {
            string icon = get_status_icon ();
            status_icon.set_from_icon_name (icon, Gtk.IconSize.SMALL_TOOLBAR);
        }
    }

    private string get_status_icon () {
        if (battery.capacity <= 20) return "battery-caution";
        if (battery.capacity <= 40) return "battery-low";
        if (battery.capacity <= 80) return "battery-good";
        return "battery-full";
    }

    public new void show_all () {
        base.show_all ();
        set_opacity (config.widget_opacity);
    }

    public void show_widget () {
        show_all ();
        minimized = false;
    }

    public bool is_minimized () {
        return minimized;
    }
}
