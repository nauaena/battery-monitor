public class Config : Object {
    private static Config? instance;
    private string config_dir;
    private string config_file;
    private KeyFile keyfile;
    
    public bool autostart { get; set; default = true; }
    public bool start_minimized { get; set; default = false; }
    public int refresh_interval { get; set; default = 2; }
    public bool low_battery_alert { get; set; default = true; }
    public int low_battery_threshold { get; set; default = 20; }
    public bool full_battery_alert { get; set; default = true; }
    public bool health_alert { get; set; default = true; }
    public double widget_opacity { get; set; default = 0.9; }
    
    public static Config get_instance () {
        if (instance == null) {
            instance = new Config ();
        }
        return instance;
    }
    
    private Config () {
        config_dir = Path.build_filename (
            Environment.get_user_config_dir (), 
            "battery-monitor"
        );
        config_file = Path.build_filename (config_dir, "config.ini");
        keyfile = new KeyFile ();
        load ();
    }
    
    public void load () {
        try {
            if (FileUtils.test (config_file, FileTest.EXISTS)) {
                keyfile.load_from_file (config_file, KeyFileFlags.NONE);
                autostart = keyfile.get_boolean ("general", "autostart");
                start_minimized = keyfile.get_boolean ("general", "start_minimized");
                refresh_interval = keyfile.get_integer ("general", "refresh_interval");
                low_battery_alert = keyfile.get_boolean ("notification", "low_battery_alert");
                low_battery_threshold = keyfile.get_integer ("notification", "low_battery_threshold");
                full_battery_alert = keyfile.get_boolean ("notification", "full_battery_alert");
                health_alert = keyfile.get_boolean ("notification", "health_alert");
                widget_opacity = keyfile.get_double ("widget", "opacity");
            }
        } catch (Error e) {
            // 使用默认值
        }
    }
    
    public void save () {
        try {
            DirUtils.create_with_parents (config_dir, 0755);
            keyfile.set_boolean ("general", "autostart", autostart);
            keyfile.set_boolean ("general", "start_minimized", start_minimized);
            keyfile.set_integer ("general", "refresh_interval", refresh_interval);
            keyfile.set_boolean ("notification", "low_battery_alert", low_battery_alert);
            keyfile.set_integer ("notification", "low_battery_threshold", low_battery_threshold);
            keyfile.set_boolean ("notification", "full_battery_alert", full_battery_alert);
            keyfile.set_boolean ("notification", "health_alert", health_alert);
            keyfile.set_double ("widget", "opacity", widget_opacity);
            keyfile.save_to_file (config_file);
        } catch (Error e) {
            stderr.printf ("保存配置失败: %s\n", e.message);
        }
    }
}