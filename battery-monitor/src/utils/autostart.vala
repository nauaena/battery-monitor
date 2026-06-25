public class AutostartManager : Object {
    private string autostart_dir;
    private string desktop_file;
    
    public AutostartManager () {
        autostart_dir = Path.build_filename (
            Environment.get_user_config_dir (),
            "autostart"
        );
        desktop_file = Path.build_filename (
            autostart_dir,
            "battery-monitor.desktop"
        );
    }
    
    public void update (Config config) {
        if (config.autostart) {
            enable ();
        } else {
            disable ();
        }
    }
    
    public void enable () {
        DirUtils.create_with_parents (autostart_dir, 0755);
        
        try {
            var file = File.new_for_path (desktop_file);
            var stream = file.replace (null, false, FileCreateFlags.REPLACE_DESTINATION);
            
            var content = """[Desktop Entry]
Name=电池监控器
Exec=/usr/bin/battery-monitor --start-minimized
Icon=battery-monitor
Terminal=false
Type=Application
X-GNOME-Autostart-enabled=true
""";
            
            stream.write (content.data);
            stream.close ();
        } catch (Error e) {
            stderr.printf ("创建自启动文件失败: %s\n", e.message);
        }
    }
    
    public void disable () {
        try {
            var file = File.new_for_path (desktop_file);
            if (file.query_exists ()) {
                file.delete ();
            }
        } catch (Error e) {
            stderr.printf ("删除自启动文件失败: %s\n", e.message);
        }
    }
    
    public bool is_enabled () {
        var file = File.new_for_path (desktop_file);
        return file.query_exists ();
    }
}
