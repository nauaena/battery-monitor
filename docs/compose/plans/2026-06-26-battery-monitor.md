# Battery Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 Linux 电池监控桌面应用，支持系统托盘、主窗口、桌面小组件、历史图表，交付 .deb 安装包。

**Architecture:** 使用 Vala 语言 + GTK-3 框架，通过读取 /sys/class/power_supply/ 内核接口获取电池数据，使用 Ayatana AppIndicator 实现系统托盘，Meson 构建系统编译，dpkg-deb 打包。

**Tech Stack:** Vala 0.56, GTK-3, Ayatana AppIndicator, Meson, JSON-Glib

## Global Constraints

- 目标平台: Linux Mint 22.3 / Ubuntu 24.04 (x86_64)
- 界面语言: 中文
- 内存占用: < 15MB
- 启动时间: < 0.5秒
- 数据刷新间隔: 默认 2秒

---

## File Structure

```
battery-monitor/
├── src/
│   ├── main.vala                 # 程序入口
│   ├── battery.vala              # 电池数据读取
│   ├── history.vala              # 历史数据管理
│   ├── ui/
│   │   ├── tray.vala             # 系统托盘
│   │   ├── window.vala           # 主窗口
│   │   ├── widget.vala           # 桌面小组件
│   │   ├── chart.vala            # 历史图表
│   │   └── settings.vala         # 设置窗口
│   └── utils/
│       ├── autostart.vala        # 开机自启动
│       ├── notification.vala     # 通知管理
│       └── config.vala           # 配置管理
├── icons/
│   └── tray/                     # 托盘图标 SVG
├── data/
│   └── battery-monitor.desktop   # 桌面文件
├── meson.build                   # 构建配置
└── debian/
    ├── control
    ├── rules
    ├── postinst
    └── prerm
```

---

## Task 1: 项目初始化与构建配置

**Covers:** 4.1, 4.2

**Files:**
- Create: `battery-monitor/meson.build`
- Create: `battery-monitor/src/main.vala`
- Create: `battery-monitor/data/battery-monitor.desktop`

**Interfaces:**
- Produces: 可编译运行的空窗口应用

- [ ] **Step 1: 创建项目目录结构**

```bash
cd /home/liubing/文档/battery
mkdir -p battery-monitor/{src/{ui,utils},icons/tray,data,debian}
```

- [ ] **Step 2: 创建 meson.build**

```meson
project('battery-monitor', 'vala', 'c',
  version: '1.0.0',
  default_options: ['warning_level=2']
)

dependencies = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gtk+-3.0'),
  dependency('json-glib-1.0'),
  dependency('ayatana-appindicator3-0.1'),
]

sources = files(
  'src/main.vala',
)

executable('battery-monitor',
  sources,
  dependencies: dependencies,
  install: true
)

install_data(
  'data/battery-monitor.desktop',
  install_dir: join_paths(get_option('datadir'), 'applications')
)
```

- [ ] **Step 3: 创建 src/main.vala**

```vala
using Gtk;

public class BatteryMonitor : Application {
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
```

- [ ] **Step 4: 创建 data/battery-monitor.desktop**

```desktop
[Desktop Entry]
Name=电池监控器
Comment=Linux 电池监控工具
Exec=/usr/bin/battery-monitor
Icon=battery-monitor
Terminal=false
Type=Application
Categories=System;Monitor;
```

- [ ] **Step 5: 编译测试**

```bash
cd /home/liubing/文档/battery/battery-monitor
meson setup builddir
ninja -C builddir
./builddir/battery-monitor
```

Expected: 弹出空白窗口，标题为"电池监控器"

- [ ] **Step 6: 提交**

```bash
git init
git add .
git commit -m "feat: 初始化项目结构和构建配置"
```

---

## Task 2: 电池数据读取模块

**Covers:** 3.2.1, 3.2.2, 4.3

**Files:**
- Create: `battery-monitor/src/battery.vala`
- Modify: `battery-monitor/src/main.vala`
- Modify: `battery-monitor/meson.build`

**Interfaces:**
- Produces: `BatteryData` 类，提供 `update()` 方法和所有电池属性

- [ ] **Step 1: 创建 src/battery.vala**

```vala
public class BatteryData : Object {
    // 基本信息
    public int capacity { get; set; default = 0; }
    public string status { get; set; default = "Unknown"; }
    public string manufacturer { get; set; default = ""; }
    public string model_name { get; set; default = ""; }
    public string technology { get; set; default = ""; }
    
    // 功率信息 (单位已转换)
    public double power_watts { get; set; default = 0; }
    public double voltage_volts { get; set; default = 0; }
    public double current_amps { get; set; default = 0; }
    
    // 容量信息 (Wh)
    public double energy_now { get; set; default = 0; }
    public double energy_full { get; set; default = 0; }
    public double energy_full_design { get; set; default = 0; }
    
    // 健康度
    public double health_percent { 
        get { 
            if (energy_full_design > 0)
                return (energy_full / energy_full_design) * 100;
            return 0;
        }
    }
    
    public int cycle_count { get; set; default = 0; }
    
    private string battery_path = "/sys/class/power_supply/BAT0";
    
    public bool update () {
        // 检查电池是否存在
        if (!FileUtils.test (battery_path, FileTest.EXISTS)) {
            return false;
        }
        
        // 读取基本数据
        capacity = read_int ("capacity");
        status = read_string ("status");
        manufacturer = read_string ("manufacturer");
        model_name = read_string ("model_name");
        technology = read_string ("technology");
        cycle_count = read_int ("cycle_count");
        
        // 读取功率数据 (微单位转换)
        power_watts = read_long ("power_now") / 1000000.0;
        voltage_volts = read_long ("voltage_now") / 1000000.0;
        current_amps = read_long ("current_now") / 1000000.0;
        
        // 读取容量数据 (微单位转换为 Wh)
        energy_now = read_long ("energy_now") / 1000000.0;
        energy_full = read_long ("energy_full") / 1000000.0;
        energy_full_design = read_long ("energy_full_design") / 1000000.0;
        
        return true;
    }
    
    public string get_status_text () {
        switch (status) {
            case "Charging": return "充电中";
            case "Discharging": return "放电中";
            case "Full": return "已充满";
            case "Not charging": return "未充电";
            default: return "未知";
        }
    }
    
    public string get_health_status () {
        if (health_percent > 90) return "优秀";
        if (health_percent > 80) return "良好";
        if (health_percent > 70) return "一般";
        return "需关注";
    }
    
    public string get_estimated_time () {
        if (power_watts <= 0) return "无法估算";
        
        double remaining_hours;
        if (status == "Charging") {
            remaining_hours = (energy_full - energy_now) / power_watts;
            int hours = (int) remaining_hours;
            int minutes = (int) ((remaining_hours - hours) * 60);
            return "预计还需 %d小时%d分钟充满".printf (hours, minutes);
        } else if (status == "Discharging") {
            remaining_hours = energy_now / power_watts;
            int hours = (int) remaining_hours;
            int minutes = (int) ((remaining_hours - hours) * 60);
            return "预计还可使用 %d小时%d分钟".printf (hours, minutes);
        }
        return "无法估算";
    }
    
    private int read_int (string filename) {
        string filepath = Path.build_filename (battery_path, filename);
        try {
            string contents;
            FileUtils.get_contents (filepath, out contents);
            return int.parse (contents.strip ());
        } catch (Error e) {
            return 0;
        }
    }
    
    private long read_long (string filename) {
        string filepath = Path.build_filename (battery_path, filename);
        try {
            string contents;
            FileUtils.get_contents (filepath, out contents);
            return long.parse (contents.strip ());
        } catch (Error e) {
            return 0;
        }
    }
    
    private string read_string (string filename) {
        string filepath = Path.build_filename (battery_path, filename);
        try {
            string contents;
            FileUtils.get_contents (filepath, out contents);
            return contents.strip ();
        } catch (Error e) {
            return "";
        }
    }
}
```

- [ ] **Step 2: 更新 meson.build 添加 battery.vala**

```meson
sources = files(
  'src/main.vala',
  'src/battery.vala',
)
```

- [ ] **Step 3: 更新 main.vala 测试电池读取**

```vala
using Gtk;

public class BatteryMonitor : Application {
    private BatteryData battery;
    
    public BatteryMonitor () {
        Object (
            application_id: "com.github.battery-monitor",
            flags: ApplicationFlags.FLAGS_NONE
        );
        battery = new BatteryData ();
    }

    protected override void activate () {
        var window = new ApplicationWindow (this);
        window.title = "电池监控器";
        window.set_default_size (400, 300);
        
        // 测试电池数据读取
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
```

- [ ] **Step 4: 编译测试**

```bash
ninja -C builddir
./builddir/battery-monitor
```

Expected: 窗口显示电池信息（电量、状态、功率、健康度）

- [ ] **Step 5: 提交**

```bash
git add .
git commit -m "feat: 添加电池数据读取模块"
```

---

## Task 3: 配置管理模块

**Covers:** 3.5

**Files:**
- Create: `battery-monitor/src/utils/config.vala`
- Modify: `battery-monitor/meson.build`

**Interfaces:**
- Produces: `Config` 单例类，管理所有用户设置

- [ ] **Step 1: 创建 src/utils/config.vala**

```vala
public class Config : Object {
    private static Config? instance;
    private string config_dir;
    private string config_file;
    private KeyFile keyfile;
    
    // 设置项
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
            // 确保目录存在
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
```

- [ ] **Step 2: 更新 meson.build**

```meson
sources = files(
  'src/main.vala',
  'src/battery.vala',
  'src/utils/config.vala',
)
```

- [ ] **Step 3: 提交**

```bash
git add .
git commit -m "feat: 添加配置管理模块"
```

---

## Task 4: 系统托盘实现

**Covers:** 3.1

**Files:**
- Create: `battery-monitor/src/ui/tray.vala`
- Create: `battery-monitor/icons/tray/` (SVG 图标)
- Modify: `battery-monitor/meson.build`

**Interfaces:**
- Consumes: `BatteryData`, `Config`
- Produces: `TrayIcon` 类，管理托盘图标和菜单

- [ ] **Step 1: 创建托盘图标 SVG (简化版)**

创建 `icons/tray/battery-low.svg` 到 `battery-full.svg` (5个档位)

```svg
<!-- battery-20.svg 示例 -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
  <rect x="2" y="6" width="18" height="12" rx="2" fill="none" stroke="currentColor" stroke-width="2"/>
  <rect x="22" y="9" width="2" height="6" fill="currentColor"/>
  <rect x="4" y="8" width="3" height="8" fill="#ff4444"/>
</svg>
```

- [ ] **Step 2: 创建 src/ui/tray.vala**

```vala
using AyatanaAppindicator;

public class TrayIcon : Object {
    private Application app;
    private BatteryData battery;
    private Config config;
    private Indicator indicator;
    private Gtk.Menu menu;
    
    public TrayIcon (Application app, BatteryData battery) {
        this.app = app;
        this.battery = battery;
        this.config = Config.get_instance ();
        
        indicator = new Indicator.with_path (
            "battery-monitor",
            "battery-medium",
            Category.APPLICATION_STATUS,
            "/usr/share/battery-monitor/icons/tray/"
        );
        
        indicator.set_status (IndicatorStatus.ACTIVE);
        indicator.set_attention_icon_full ("battery-full", "电池已充满");
        
        setup_menu ();
        update_icon ();
    }
    
    private void setup_menu () {
        menu = new Gtk.Menu ();
        
        // 显示主窗口
        var show_item = new Gtk.MenuItem.with_label ("显示主窗口");
        show_item.activate.connect (() => {
            app.activate ();
        });
        menu.add (show_item);
        
        // 分隔符
        menu.add (new Gtk.SeparatorMenuItem ());
        
        // 开机自启动开关
        var autostart_item = new Gtk.CheckMenuItem.with_label ("开机自启动");
        autostart_item.active = config.autostart;
        autostart_item.toggled.connect ((item) => {
            config.autostart = item.active;
            config.save ();
        });
        menu.add (autostart_item);
        
        // 分隔符
        menu.add (new Gtk.SeparatorMenuItem ());
        
        // 退出
        var quit_item = new Gtk.MenuItem.with_label ("退出");
        quit_item.activate.connect (() => {
            app.quit ();
        });
        menu.add (quit_item);
        
        menu.show_all ();
        indicator.set_menu (menu);
    }
    
    public void update_icon () {
        if (!battery.update ()) {
            indicator.set_icon_full ("battery-missing", "未检测到电池");
            return;
        }
        
        string icon_name;
        int level = battery.capacity;
        
        if (level <= 20) icon_name = "battery-20";
        else if (level <= 40) icon_name = "battery-40";
        else if (level <= 60) icon_name = "battery-60";
        else if (level <= 80) icon_name = "battery-80";
        else icon_name = "battery-100";
        
        // 充电时添加后缀
        if (battery.status == "Charging") {
            icon_name += "-charging";
        }
        
        indicator.set_icon_full (icon_name, "%d%% %s".printf (level, battery.get_status_text ()));
        
        // 设置提示文本
        indicator.set_title ("%d%% - %s".printf (level, battery.get_status_text ()));
    }
}
```

- [ ] **Step 3: 更新 meson.build 添加 libayatana-appindicator**

```meson
sources = files(
  'src/main.vala',
  'src/battery.vala',
  'src/utils/config.vala',
  'src/ui/tray.vala',
)

install_data(
  'icons/tray/*.svg',
  install_dir: join_paths(get_option('datadir'), 'battery-monitor', 'icons', 'tray')
)
```

- [ ] **Step 4: 更新 main.vala 集成托盘**

```vala
using Gtk;

public class BatteryMonitor : Application {
    private BatteryData battery;
    private TrayIcon tray;
    private Config config;
    
    public BatteryMonitor () {
        Object (
            application_id: "com.github.battery-monitor",
            flags: ApplicationFlags.FLAGS_NONE
        );
        battery = new BatteryData ();
        config = Config.get_instance ();
    }

    protected override void activate () {
        var window = new ApplicationWindow (this);
        window.title = "电池监控器";
        window.set_default_size (400, 300);
        window.destroy.connect (() => {
            if (config.start_minimized) {
                window.hide ();
                return true;
            }
            return false;
        });
        
        // 显示电池信息
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

    protected override void startup () {
        base.startup ();
        tray = new TrayIcon (this, battery);
    }

    public static int main (string[] args) {
        var app = new BatteryMonitor ();
        return app.run (args);
    }
}
```

- [ ] **Step 5: 编译测试**

```bash
ninja -C builddir
./builddir/battery-monitor
```

Expected: 系统托盘出现电池图标，右键有菜单

- [ ] **Step 6: 提交**

```bash
git add .
git commit -m "feat: 实现系统托盘图标和菜单"
```

---

## Task 5: 主窗口界面

**Covers:** 3.2

**Files:**
- Create: `battery-monitor/src/ui/window.vala`
- Modify: `battery-monitor/meson.build`

**Interfaces:**
- Consumes: `BatteryData`, `Config`
- Produces: `MainWindow` 类

- [ ] **Step 1: 创建 src/ui/window.vala**

```vala
using Gtk;

public class MainWindow : ApplicationWindow {
    private BatteryData battery;
    private Config config;
    
    // UI 组件
    private Label capacity_label;
    private Label status_label;
    private Label power_label;
    private Label voltage_label;
    private Label current_label;
    private Label estimated_label;
    private Label health_label;
    private Label cycle_label;
    private Label health_status_label;
    private Scale capacity_scale;
    
    public MainWindow (Application app, BatteryData battery) {
        Object (application: app);
        this.battery = battery;
        this.config = Config.get_instance ();
        
        setup_ui ();
        update_data ();
    }
    
    private void setup_ui () {
        title = "电池监控器";
        set_default_size (450, 500);
        set_resizable (false);
        
        var main_box = new Box (Orientation.VERTICAL, 10);
        main_box.margin = 15;
        add (main_box);
        
        // 标题
        var title_label = new Label (null);
        title_label.set_markup ("<big><b>电池监控器</b></big>");
        main_box.pack_start (title_label, false, false, 5);
        
        // 电量显示区域
        var capacity_box = new Box (Orientation.HORIZONTAL, 20);
        capacity_box.homogeneous = true;
        main_box.pack_start (capacity_box, false, false, 10);
        
        // 左侧：电量仪表
        var left_box = new Box (Orientation.VERTICAL, 5);
        capacity_box.pack_start (left_box, true, true, 0);
        
        capacity_label = new Label (null);
        capacity_label.set_markup ("<big><b>0%</b></big>");
        left_box.pack_start (capacity_label, true, true, 0);
        
        capacity_scale = new Scale.with_range (Orientation.HORIZONTAL, 0, 100, 1);
        capacity_scale.set_sensitive (false);
        capacity_scale.set_size_request (150, -1);
        left_box.pack_start (capacity_scale, false, false, 0);
        
        // 右侧：状态信息
        var right_box = new Box (Orientation.VERTICAL, 5);
        capacity_box.pack_start (right_box, true, true, 0);
        
        status_label = new Label ("状态: --");
        right_box.pack_start (status_label, true, true, 0);
        
        power_label = new Label ("功率: -- W");
        right_box.pack_start (power_label, true, true, 0);
        
        // 分隔线
        main_box.pack_start (new Separator (Orientation.HORIZONTAL), false, false, 5);
        
        // 功率信息面板
        var power_frame = new Frame ("功率信息");
        main_box.pack_start (power_frame, false, false, 0);
        
        var power_grid = new Grid ();
        power_grid.column_spacing = 20;
        power_grid.margin = 10;
        power_frame.add (power_grid);
        
        power_grid.attach (new Label ("功率:"), 0, 0, 1, 1);
        var power_value = new Label ("-- W");
        power_grid.attach (power_value, 1, 0, 1, 1);
        
        power_grid.attach (new Label ("电压:"), 0, 1, 1, 1);
        voltage_label = new Label ("-- V");
        power_grid.attach (voltage_label, 1, 1, 1, 1);
        
        power_grid.attach (new Label ("电流:"), 0, 2, 1, 1);
        current_label = new Label ("-- A");
        power_grid.attach (current_label, 1, 2, 1, 1);
        
        // 电量预估面板
        var estimate_frame = new Frame ("电量预估");
        main_box.pack_start (estimate_frame, false, false, 0);
        
        estimated_label = new Label ("--");
        estimated_label.margin = 10;
        estimate_frame.add (estimated_label);
        
        // 电池健康面板
        var health_frame = new Frame ("电池健康");
        main_box.pack_start (health_frame, false, false, 0);
        
        var health_grid = new Grid ();
        health_grid.column_spacing = 20;
        health_grid.margin = 10;
        health_frame.add (health_grid);
        
        health_grid.attach (new Label ("健康度:"), 0, 0, 1, 1);
        health_label = new Label ("--%");
        health_grid.attach (health_label, 1, 0, 1, 1);
        
        health_grid.attach (new Label ("循环次数:"), 0, 1, 1, 1);
        cycle_label = new Label ("--次");
        health_grid.attach (cycle_label, 1, 1, 1, 1);
        
        health_grid.attach (new Label ("状态:"), 0, 2, 1, 1);
        health_status_label = new Label ("--");
        health_grid.attach (health_status_label, 1, 2, 1, 1);
        
        // 底部按钮
        var button_box = new Box (Orientation.HORIZONTAL, 10);
        button_box.halign = Align.CENTER;
        main_box.pack_end (button_box, false, false, 10);
        
        var refresh_button = new Button.with_label ("刷新");
        refresh_button.clicked.connect (() => update_data ());
        button_box.pack_start (refresh_button, false, false, 0);
        
        var minimize_button = new Button.with_label ("最小化");
        minimize_button.clicked.connect (() => {
            this.hide ();
        });
        button_box.pack_start (minimize_button, false, false, 0);
    }
    
    public void update_data () {
        if (!battery.update ()) {
            capacity_label.set_markup ("<big><b>N/A</b></big>");
            status_label.set_text ("状态: 未检测到电池");
            return;
        }
        
        // 更新电量显示
        capacity_label.set_markup ("<big><b>%d%%</b></big>".printf (battery.capacity));
        capacity_scale.set_value (battery.capacity);
        
        // 更新状态
        status_label.set_text ("状态: %s".printf (battery.get_status_text ()));
        power_label.set_text ("功率: %.2f W".printf (battery.power_watts));
        
        // 更新功率信息
        voltage_label.set_text ("%.2f V".printf (battery.voltage_volts));
        current_label.set_text ("%.2f A".printf (battery.current_amps));
        
        // 更新预估
        estimated_label.set_text (battery.get_estimated_time ());
        
        // 更新健康信息
        health_label.set_text ("%.1f%%".printf (battery.health_percent));
        cycle_label.set_text ("%d次".printf (battery.cycle_count));
        health_status_label.set_text (battery.get_health_status ());
        
        // 更新托盘标题
        this.title = "%d%% %s - 电池监控器".printf (
            battery.capacity, 
            battery.get_status_text ()
        );
    }
    
    public bool on_delete_event () {
        if (config.start_minimized) {
            this.hide ();
            return true;  // 阻止关闭
        }
        return false;
    }
}
```

- [ ] **Step 2: 更新 meson.build**

```meson
sources = files(
  'src/main.vala',
  'src/battery.vala',
  'src/utils/config.vala',
  'src/ui/tray.vala',
  'src/ui/window.vala',
)
```

- [ ] **Step 3: 更新 main.vala 使用 MainWindow**

```vala
using Gtk;

public class BatteryMonitor : Application {
    private BatteryData battery;
    private TrayIcon tray;
    private MainWindow? main_window;
    private Config config;
    private uint update_timeout;
    
    public BatteryMonitor () {
        Object (
            application_id: "com.github.battery-monitor",
            flags: ApplicationFlags.FLAGS_NONE
        );
        battery = new BatteryData ();
        config = Config.get_instance ();
    }

    protected override void activate () {
        if (main_window == null) {
            main_window = new MainWindow (this, battery);
            main_window.delete_event.connect (() => {
                return main_window.on_delete_event ();
            });
        }
        main_window.present ();
    }

    protected override void startup () {
        base.startup ();
        tray = new TrayIcon (this, battery);
        
        // 定时更新
        update_timeout = Timeout.add_seconds (config.refresh_interval, () => {
            battery.update ();
            tray.update_icon ();
            if (main_window != null) {
                main_window.update_data ();
            }
            return true;
        });
    }

    protected override void shutdown () {
        if (update_timeout > 0) {
            Source.remove (update_timeout);
        }
        base.shutdown ();
    }

    public static int main (string[] args) {
        var app = new BatteryMonitor ();
        return app.run (args);
    }
}
```

- [ ] **Step 4: 编译测试**

```bash
ninja -C builddir
./builddir/battery-monitor
```

Expected: 主窗口显示完整电池信息，数据每2秒刷新

- [ ] **Step 5: 提交**

```bash
git add .
git commit -m "feat: 实现主窗口界面"
```

---

## Task 6: 桌面小组件

**Covers:** 3.3

**Files:**
- Create: `battery-monitor/src/ui/widget.vala`
- Modify: `battery-monitor/meson.build`

**Interfaces:**
- Consumes: `BatteryData`, `Config`
- Produces: `FloatingWidget` 类

- [ ] **Step 1: 创建 src/ui/widget.vala**

```vala
using Gtk;
using Gdk;

public class FloatingWidget : Gtk.Window {
    private BatteryData battery;
    private Config config;
    private Label capacity_label;
    private Label status_label;
    private bool is_dragging = false;
    private double drag_x;
    private double drag_y;
    
    public FloatingWidget (BatteryData battery) {
        Object (
            type: Gtk.WindowType.POPUP,
            decorated: false,
            skip_taskbar_hint: true,
            skip_pager_hint: true
        );
        
        this.battery = battery;
        this.config = Config.get_instance ();
        
        setup_ui ();
        setup_events ();
        update_position ();
    }
    
    private void setup_ui () {
        set_default_size (120, 60);
        set_opacity (config.widget_opacity);
        
        // 设置透明背景
        var visual = screen.get_rgba_visual ();
        if (visual != null) {
            this.set_visual (visual);
            app_paintable = true;
        }
        
        var main_box = new Box (Orientation.VERTICAL, 2);
        main_box.margin = 5;
        main_box.get_style_context ().add_class ("widget-background");
        
        // 电量显示
        capacity_label = new Label (null);
        capacity_label.set_markup ("<b>0%</b>");
        capacity_label.get_style_context ().add_class ("widget-text");
        main_box.pack_start (capacity_label, true, true, 0);
        
        // 状态显示
        status_label = new Label ("--");
        status_label.get_style_context ().add_class ("widget-status");
        main_box.pack_start (status_label, true, true, 0);
        
        add (main_box);
        
        // 应用样式
        var css_provider = new CssProvider ();
        css_provider.load_from_data ("""
            .widget-background {
                background-color: rgba(0, 0, 0, 0.7);
                border-radius: 10px;
            }
            .widget-text {
                color: white;
                font-size: 18px;
            }
            .widget-status {
                color: #aaaaaa;
                font-size: 10px;
            }
        """.data);
        
        StyleContext.add_provider_for_screen (
            screen,
            css_provider,
            STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }
    
    private void setup_events () {
        // 拖动支持
        button_press_event.connect ((event) => {
            if (event.button == 1) {
                is_dragging = true;
                drag_x = event.x_root - x;
                drag_y = event.y_root - y;
                return true;
            }
            return false;
        });
        
        button_release_event.connect ((event) => {
            is_dragging = false;
            return true;
        });
        
        motion_notify_event.connect ((event) => {
            if (is_dragging) {
                move ((int) (event.x_root - drag_x), (int) (event.y_root - drag_y));
                return true;
            }
            return false;
        });
        
        // 右键菜单
        button_press_event.connect ((event) => {
            if (event.button == 3) {
                show_context_menu ();
                return true;
            }
            return false;
        });
    }
    
    private void show_context_menu () {
        var menu = new Gtk.Menu ();
        
        var hide_item = new Gtk.MenuItem.with_label ("隐藏");
        hide_item.activate.connect (() => this.hide ());
        menu.add (hide_item);
        
        menu.add (new Gtk.SeparatorMenuItem ());
        
        var opacity_item = new Gtk.MenuItem.with_label ("透明度");
        opacity_item.activate.connect (() => {
            // TODO: 显示透明度调节
        });
        menu.add (opacity_item);
        
        menu.show_all ();
        menu.popup_at_pointer (null);
    }
    
    private void update_position () {
        // 默认显示在右下角
        var screen = this.get_screen ();
        int x_pos = screen.get_width () - 140;
        int y_pos = screen.get_height () - 100;
        move (x_pos, y_pos);
    }
    
    public void update_data () {
        if (!battery.update ()) return;
        
        capacity_label.set_markup ("<b>%d%%</b>".printf (battery.capacity));
        status_label.set_text (battery.get_status_text ());
        
        // 根据电量改变颜色
        string color;
        if (battery.capacity <= 20) {
            color = "#ff4444";
        } else if (battery.capacity <= 50) {
            color = "#ffaa00";
        } else {
            color = "#44ff44";
        }
        
        capacity_label.get_style_context ().add_class ("widget-text");
    }
}
```

- [ ] **Step 2: 更新 meson.build**

```meson
sources = files(
  'src/main.vala',
  'src/battery.vala',
  'src/utils/config.vala',
  'src/ui/tray.vala',
  'src/ui/window.vala',
  'src/ui/widget.vala',
)
```

- [ ] **Step 3: 更新 main.vala 集成小组件**

在 `BatteryMonitor` 类中添加：

```vala
private FloatingWidget? floating_widget;

// 在 startup() 中添加:
floating_widget = new FloatingWidget (battery);
floating_widget.show_all ();

// 在 update_timeout 回调中添加:
if (floating_widget != null && floating_widget.visible) {
    floating_widget.update_data ();
}
```

- [ ] **Step 4: 编译测试**

```bash
ninja -C builddir
./builddir/battery-monitor
```

Expected: 桌面右下角出现半透明小组件，可拖动

- [ ] **Step 5: 提交**

```bash
git add .
git commit -m "feat: 实现桌面浮动小组件"
```

---

## Task 7: 历史数据与图表

**Covers:** 3.2.5

**Files:**
- Create: `battery-monitor/src/history.vala`
- Create: `battery-monitor/src/ui/chart.vala`
- Modify: `battery-monitor/meson.build`

**Interfaces:**
- Consumes: `BatteryData`
- Produces: `HistoryManager`, `BatteryChart`

- [ ] **Step 1: 创建 src/history.vala**

```vala
using Json;

public class HistoryManager : Object {
    private string history_dir;
    private string history_file;
    private Array<HistoryEntry> entries;
    
    public struct HistoryEntry {
        public int64 timestamp;
        public int capacity;
        public string status;
        public double power_watts;
    }
    
    public HistoryManager () {
        history_dir = Path.build_filename (
            Environment.get_user_data_dir (),
            "battery-monitor"
        );
        history_file = Path.build_filename (history_dir, "history.json");
        entries = new Array<HistoryEntry> ();
        load ();
    }
    
    public void add_entry (BatteryData battery) {
        HistoryEntry entry = HistoryEntry () {
            timestamp = get_real_time () / 1000000,  // 微秒转秒
            capacity = battery.capacity,
            status = battery.status,
            power_watts = battery.power_watts
        };
        
        entries.append_val (entry);
        
        // 只保留最近7天的数据
        int64 cutoff = get_real_time () / 1000000 - 7 * 24 * 3600;
        while (entries.length > 0 && entries.index (0).timestamp < cutoff) {
            entries.remove_index (0);
        }
        
        save ();
    }
    
    public Array<HistoryEntry> get_entries (int hours) {
        var result = new Array<HistoryEntry> ();
        int64 cutoff = get_real_time () / 1000000 - hours * 3600;
        
        for (int i = 0; i < entries.length; i++) {
            if (entries.index (i).timestamp >= cutoff) {
                result.append_val (entries.index (i));
            }
        }
        return result;
    }
    
    private void load () {
        try {
            if (!FileUtils.test (history_file, FileTest.EXISTS)) return;
            
            string contents;
            FileUtils.get_contents (history_file, out contents);
            
            var parser = new Json.Parser ();
            parser.load_from_data (contents);
            
            var root = parser.get_root ();
            var array = root.get_array ();
            
            for (int i = 0; i < array.get_length (); i++) {
                var obj = array.get_object_element (i);
                HistoryEntry entry = HistoryEntry () {
                    timestamp = obj.get_int_member ("timestamp"),
                    capacity = (int) obj.get_int_member ("capacity"),
                    status = obj.get_string_member ("status"),
                    power_watts = obj.get_double_member ("power_watts")
                };
                entries.append_val (entry);
            }
        } catch (Error e) {
            stderr.printf ("加载历史数据失败: %s\n", e.message);
        }
    }
    
    private void save () {
        try {
            DirUtils.create_with_parents (history_dir, 0755);
            
            var builder = new Json.Builder ();
            builder.begin_array ();
            
            for (int i = 0; i < entries.length; i++) {
                var entry = entries.index (i);
                builder.begin_object ();
                builder.set_member_name ("timestamp");
                builder.add_int_value (entry.timestamp);
                builder.set_member_name ("capacity");
                builder.add_int_value (entry.capacity);
                builder.set_member_name ("status");
                builder.add_string_value (entry.status);
                builder.set_member_name ("power_watts");
                builder.add_double_value (entry.power_watts);
                builder.end_object ();
            }
            
            builder.end_array ();
            
            var generator = new Json.Generator ();
            generator.root = builder.get_root ();
            generator.pretty = true;
            
            string json = generator.to_data (null);
            FileUtils.set_contents (history_file, json);
        } catch (Error e) {
            stderr.printf ("保存历史数据失败: %s\n", e.message);
        }
    }
}
```

- [ ] **Step 2: 创建 src/ui/chart.vala**

```vala
using Gtk;
using Cairo;

public class BatteryChart : DrawingArea {
    private Array<HistoryManager.HistoryEntry> data;
    private int time_range_hours;
    
    public BatteryChart () {
        data = new Array<HistoryManager.HistoryEntry> ();
        time_range_hours = 24;
        set_size_request (400, 150);
    }
    
    public void set_data (Array<HistoryManager.HistoryEntry> entries) {
        this.data = entries;
        queue_draw ();
    }
    
    public void set_time_range (int hours) {
        this.time_range_hours = hours;
        queue_draw ();
    }
    
    public override bool draw (Context cr) {
        int width = get_allocated_width ();
        int height = get_allocated_height ();
        
        // 背景
        cr.set_source_rgb (1, 1, 1);
        cr.rectangle (0, 0, width, height);
        cr.fill ();
        
        if (data.length < 2) {
            // 显示提示文字
            cr.set_source_rgb (0.5, 0.5, 0.5);
            cr.select_font_face ("Sans", FontSlant.NORMAL, FontWeight.NORMAL);
            cr.set_font_size (12);
            cr.move_to (width / 2 - 50, height / 2);
            cr.show_text ("数据不足，无法显示图表");
            return true;
        }
        
        // 计算边界
        double margin_left = 40;
        double margin_right = 10;
        double margin_top = 10;
        double margin_bottom = 30;
        
        double chart_width = width - margin_left - margin_right;
        double chart_height = height - margin_top - margin_bottom;
        
        // 绘制网格线
        cr.set_source_rgb (0.9, 0.9, 0.9);
        cr.set_line_width (1);
        for (int i = 0; i <= 4; i++) {
            double y = margin_top + (chart_height * i / 4);
            cr.move_to (margin_left, y);
            cr.line_to (width - margin_right, y);
            cr.stroke ();
        }
        
        // 绘制Y轴标签
        cr.set_source_rgb (0, 0, 0);
        cr.select_font_face ("Sans", FontSlant.NORMAL, FontWeight.NORMAL);
        cr.set_font_size (10);
        for (int i = 0; i <= 4; i++) {
            double y = margin_top + (chart_height * i / 4);
            int value = 100 - i * 25;
            cr.move_to (5, y + 4);
            cr.show_text ("%d%%".printf (value));
        }
        
        // 绘制数据线
        if (data.length > 1) {
            cr.set_source_rgb (0.2, 0.6, 1.0);
            cr.set_line_width (2);
            
            double x_scale = chart_width / (data.length - 1);
            double y_scale = chart_height / 100.0;
            
            for (int i = 0; i < data.length; i++) {
                double x = margin_left + i * x_scale;
                double y = margin_top + (100 - data.index (i).capacity) * y_scale;
                
                if (i == 0) {
                    cr.move_to (x, y);
                } else {
                    cr.line_to (x, y);
                }
            }
            cr.stroke ();
            
            // 绘制数据点
            cr.set_source_rgb (0.2, 0.6, 1.0);
            for (int i = 0; i < data.length; i++) {
                double x = margin_left + i * x_scale;
                double y = margin_top + (100 - data.index (i).capacity) * y_scale;
                
                cr.arc (x, y, 3, 0, 2 * Math.PI);
                cr.fill ();
            }
        }
        
        // 绘制X轴标签
        cr.set_source_rgb (0, 0, 0);
        cr.set_font_size (10);
        string[] labels = {"开始", "现在"};
        cr.move_to (margin_left, height - 5);
        cr.show_text (labels[0]);
        cr.move_to (width - margin_right - 20, height - 5);
        cr.show_text (labels[1]);
        
        return true;
    }
}
```

- [ ] **Step 3: 更新 meson.build**

```meson
sources = files(
  'src/main.vala',
  'src/battery.vala',
  'src/utils/config.vala',
  'src/history.vala',
  'src/ui/tray.vala',
  'src/ui/window.vala',
  'src/ui/widget.vala',
  'src/ui/chart.vala',
)
```

- [ ] **Step 4: 更新 main.vala 集成历史数据**

```vala
private HistoryManager history;

// 在 startup() 中:
history = new HistoryManager ();

// 在 update_timeout 回调中:
if (battery.capacity > 0) {
    history.add_entry (battery);
}
```

- [ ] **Step 5: 编译测试**

```bash
ninja -C builddir
./builddir/battery-monitor
```

Expected: 运行几分钟后，历史数据开始记录

- [ ] **Step 6: 提交**

```bash
git add .
git commit -m "feat: 添加历史数据管理和图表"
```

---

## Task 8: 通知系统

**Covers:** 3.4

**Files:**
- Create: `battery-monitor/src/utils/notification.vala`
- Modify: `battery-monitor/meson.build`

**Interfaces:**
- Consumes: `BatteryData`, `Config`
- Produces: `NotificationManager`

- [ ] **Step 1: 创建 src/utils/notification.vala**

```vala
public class NotificationManager : Object {
    private Config config;
    private BatteryData battery;
    private bool was_full = false;
    private int last_alert_level = 100;
    
    public NotificationManager (BatteryData battery) {
        this.config = Config.get_instance ();
        this.battery = battery;
    }
    
    public void check () {
        if (!battery.update ()) return;
        
        // 低电量告警
        if (config.low_battery_alert && battery.capacity <= config.low_battery_threshold) {
            if (battery.capacity != last_alert_level && battery.status == "Discharging") {
                show_notification (
                    "电池电量低",
                    "当前电量: %d%%\n请及时充电".printf (battery.capacity),
                    "battery-low"
                );
                last_alert_level = battery.capacity;
            }
        }
        
        // 电量充满通知
        if (config.full_battery_alert) {
            if (battery.capacity >= 100 && !was_full && battery.status == "Full") {
                show_notification (
                    "电池已充满",
                    "当前电量: 100%%\n可以拔掉充电器了",
                    "battery-full"
                );
                was_full = true;
            } else if (battery.capacity < 100) {
                was_full = false;
            }
        }
        
        // 电池健康告警
        if (config.health_alert && battery.health_percent < 70) {
            // 只显示一次
            static bool health_warned = false;
            if (!health_warned) {
                show_notification (
                    "电池健康警告",
                    "电池健康度: %.1f%%\n建议更换电池".printf (battery.health_percent),
                    "battery-caution"
                );
                health_warned = true;
            }
        }
    }
    
    private void show_notification (string title, string body, string icon) {
        try {
            var notification = new Notification (title);
            notification.set_body (body);
            notification.set_icon (icon);
            notification.set_priority (NotificationPriority.HIGH);
            
            var app = GLib.Application.get_default ();
            if (app != null) {
                app.send_notification (null, notification);
            }
        } catch (Error e) {
            stderr.printf ("发送通知失败: %s\n", e.message);
        }
    }
}
```

- [ ] **Step 2: 更新 meson.build**

```meson
sources = files(
  'src/main.vala',
  'src/battery.vala',
  'src/utils/config.vala',
  'src/utils/notification.vala',
  'src/history.vala',
  'src/ui/tray.vala',
  'src/ui/window.vala',
  'src/ui/widget.vala',
  'src/ui/chart.vala',
)
```

- [ ] **Step 3: 更新 main.vala 集成通知**

```vala
private NotificationManager notification;

// 在 startup() 中:
notification = new NotificationManager (battery);

// 在 update_timeout 回调中:
notification.check ();
```

- [ ] **Step 4: 编译测试**

```bash
ninja -C builddir
./builddir/battery-monitor
```

Expected: 低电量时弹出系统通知

- [ ] **Step 5: 提交**

```bash
git add .
git commit -m "feat: 添加通知系统"
```

---

## Task 9: 设置窗口

**Covers:** 3.5

**Files:**
- Create: `battery-monitor/src/ui/settings.vala`
- Modify: `battery-monitor/meson.build`

**Interfaces:**
- Consumes: `Config`
- Produces: `SettingsWindow`

- [ ] **Step 1: 创建 src/ui/settings.vala**

```vala
using Gtk;

public class SettingsWindow : Dialog {
    private Config config;
    
    // UI 组件
    private Switch autostart_switch;
    private Switch start_minimized_switch;
    private SpinButton refresh_interval_spin;
    private Switch low_battery_switch;
    private SpinButton low_battery_threshold_spin;
    private Switch full_battery_switch;
    private Switch health_switch;
    private Scale opacity_scale;
    
    public SettingsWindow (Gtk.Window? parent) {
        Object (
            title: "设置",
            transient_for: parent,
            modal: true,
            default_width: 400,
            default_height: 500
        );
        
        config = Config.get_instance ();
        setup_ui ();
        load_values ();
    }
    
    private void setup_ui () {
        var content = get_content_area ();
        content.margin = 10;
        
        // 通用设置
        var general_frame = new Frame ("通用设置");
        content.pack_start (general_frame, false, false, 5);
        
        var general_grid = new Grid ();
        general_grid.column_spacing = 20;
        general_grid.row_spacing = 10;
        general_grid.margin = 10;
        general_frame.add (general_grid);
        
        general_grid.attach (new Label ("开机自启动:"), 0, 0, 1, 1);
        autostart_switch = new Switch ();
        general_grid.attach (autostart_switch, 1, 0, 1, 1);
        
        general_grid.attach (new Label ("启动时最小化:"), 0, 1, 1, 1);
        start_minimized_switch = new Switch ();
        general_grid.attach (start_minimized_switch, 1, 1, 1, 1);
        
        general_grid.attach (new Label ("刷新间隔(秒):"), 0, 2, 1, 1);
        refresh_interval_spin = new SpinButton.with_range (1, 30, 1);
        general_grid.attach (refresh_interval_spin, 1, 2, 1, 1);
        
        // 通知设置
        var notify_frame = new Frame ("通知设置");
        content.pack_start (notify_frame, false, false, 5);
        
        var notify_grid = new Grid ();
        notify_grid.column_spacing = 20;
        notify_grid.row_spacing = 10;
        notify_grid.margin = 10;
        notify_frame.add (notify_grid);
        
        notify_grid.attach (new Label ("低电量告警:"), 0, 0, 1, 1);
        low_battery_switch = new Switch ();
        notify_grid.attach (low_battery_switch, 1, 0, 1, 1);
        
        notify_grid.attach (new Label ("告警阈值(%):"), 0, 1, 1, 1);
        low_battery_threshold_spin = new SpinButton.with_range (5, 50, 5);
        notify_grid.attach (low_battery_threshold_spin, 1, 1, 1, 1);
        
        notify_grid.attach (new Label ("充满电通知:"), 0, 2, 1, 1);
        full_battery_switch = new Switch ();
        notify_grid.attach (full_battery_switch, 1, 2, 1, 1);
        
        notify_grid.attach (new Label ("健康告警:"), 0, 3, 1, 1);
        health_switch = new Switch ();
        notify_grid.attach (health_switch, 1, 3, 1, 1);
        
        // 小组件设置
        var widget_frame = new Frame ("小组件设置");
        content.pack_start (widget_frame, false, false, 5);
        
        var widget_grid = new Grid ();
        widget_grid.column_spacing = 20;
        widget_grid.row_spacing = 10;
        widget_grid.margin = 10;
        widget_frame.add (widget_grid);
        
        widget_grid.attach (new Label ("透明度:"), 0, 0, 1, 1);
        opacity_scale = new Scale.with_range (Orientation.HORIZONTAL, 0.3, 1.0, 0.1);
        opacity_scale.set_value_pos (PositionType.RIGHT);
        widget_grid.attach (opacity_scale, 1, 0, 1, 1);
        
        // 按钮
        var button_box = new Box (Orientation.HORIZONTAL, 10);
        button_box.halign = Align.END;
        button_box.margin_top = 10;
        content.pack_end (button_box, false, false, 0);
        
        var cancel_button = new Button.with_label ("取消");
        cancel_button.clicked.connect (() => this.destroy ());
        button_box.pack_start (cancel_button, false, false, 0);
        
        var save_button = new Button.with_label ("保存");
        save_button.get_style_context ().add_class ("suggested-action");
        save_button.clicked.connect (() => {
            save_values ();
            this.destroy ();
        });
        button_box.pack_start (save_button, false, false, 0);
    }
    
    private void load_values () {
        autostart_switch.active = config.autostart;
        start_minimized_switch.active = config.start_minimized;
        refresh_interval_spin.set_value (config.refresh_interval);
        low_battery_switch.active = config.low_battery_alert;
        low_battery_threshold_spin.set_value (config.low_battery_threshold);
        full_battery_switch.active = config.full_battery_alert;
        health_switch.active = config.health_alert;
        opacity_scale.set_value (config.widget_opacity);
    }
    
    private void save_values () {
        config.autostart = autostart_switch.active;
        config.start_minimized = start_minimized_switch.active;
        config.refresh_interval = (int) refresh_interval_spin.get_value ();
        config.low_battery_alert = low_battery_switch.active;
        config.low_battery_threshold = (int) low_battery_threshold_spin.get_value ();
        config.full_battery_alert = full_battery_switch.active;
        config.health_alert = health_switch.active;
        config.widget_opacity = opacity_scale.get_value ();
        config.save ();
    }
}
```

- [ ] **Step 2: 更新 meson.build**

```meson
sources = files(
  'src/main.vala',
  'src/battery.vala',
  'src/utils/config.vala',
  'src/utils/notification.vala',
  'src/history.vala',
  'src/ui/tray.vala',
  'src/ui/window.vala',
  'src/ui/widget.vala',
  'src/ui/chart.vala',
  'src/ui/settings.vala',
)
```

- [ ] **Step 3: 在 tray.vala 添加设置菜单项**

在 `setup_menu()` 中添加：

```vala
// 设置
var settings_item = new Gtk.MenuItem.with_label ("设置");
settings_item.activate.connect (() => {
    var settings_window = new SettingsWindow (null);
    settings_window.present ();
});
menu.add (settings_item);
```

- [ ] **Step 4: 编译测试**

```bash
ninja -C builddir
./builddir/battery-monitor
```

Expected: 托盘右键菜单出现"设置"，打开设置窗口

- [ ] **Step 5: 提交**

```bash
git add .
git commit -m "feat: 添加设置窗口"
```

---

## Task 10: 开机自启动

**Covers:** 3.6

**Files:**
- Create: `battery-monitor/src/utils/autostart.vala`
- Create: `battery-monitor/data/battery-monitor-autostart.desktop`
- Modify: `battery-monitor/meson.build`

**Interfaces:**
- Consumes: `Config`
- Produces: `AutostartManager`

- [ ] **Step 1: 创建 src/utils/autostart.vala**

```vala
public class AutostartManager : Object {
    private Config config;
    private string autostart_dir;
    private string desktop_file;
    
    public AutostartManager () {
        config = Config.get_instance ();
        autostart_dir = Path.build_filename (
            Environment.get_user_config_dir (),
            "autostart"
        );
        desktop_file = Path.build_filename (autostart_dir, "battery-monitor.desktop");
    }
    
    public void update () {
        if (config.autostart) {
            enable ();
        } else {
            disable ();
        }
    }
    
    private void enable () {
        try {
            DirUtils.create_with_parents (autostart_dir, 0755);
            
            string content = """[Desktop Entry]
Name=电池监控器
Comment=Linux 电池监控工具
Exec=/usr/bin/battery-monitor --start-minimized
Icon=battery-monitor
Terminal=false
Type=Application
X-GNOME-Autostart-enabled=true
""";
            FileUtils.set_contents (desktop_file, content);
        } catch (Error e) {
            stderr.printf ("创建自启动文件失败: %s\n", e.message);
        }
    }
    
    private void disable () {
        if (FileUtils.test (desktop_file, FileTest.EXISTS)) {
            try {
                FileUtils.remove (desktop_file);
            } catch (Error e) {
                stderr.printf ("删除自启动文件失败: %s\n", e.message);
            }
        }
    }
    
    public bool is_enabled () {
        return FileUtils.test (desktop_file, FileTest.EXISTS);
    }
}
```

- [ ] **Step 2: 创建 data/battery-monitor-autostart.desktop**

```desktop
[Desktop Entry]
Name=电池监控器
Comment=Linux 电池监控工具
Exec=/usr/bin/battery-monitor --start-minimized
Icon=battery-monitor
Terminal=false
Type=Application
X-GNOME-Autostart-enabled=true
```

- [ ] **Step 3: 更新 meson.build**

```meson
sources = files(
  'src/main.vala',
  'src/battery.vala',
  'src/utils/config.vala',
  'src/utils/notification.vala',
  'src/utils/autostart.vala',
  'src/history.vala',
  'src/ui/tray.vala',
  'src/ui/window.vala',
  'src/ui/widget.vala',
  'src/ui/chart.vala',
  'src/ui/settings.vala',
)

install_data(
  'data/battery-monitor-autostart.desktop',
  install_dir: join_paths(get_option('sysconfdir'), 'xdg', 'autostart')
)
```

- [ ] **Step 4: 更新 main.vala 处理 --start-minimized 参数**

```vala
public static int main (string[] args) {
    bool start_minimized = false;
    
    // 解析命令行参数
    for (int i = 1; i < args.length; i++) {
        if (args[i] == "--start-minimized") {
            start_minimized = true;
        }
    }
    
    var app = new BatteryMonitor ();
    
    if (start_minimized) {
        // 启动时不显示主窗口
        app.hold ();
    }
    
    return app.run (args);
}
```

- [ ] **Step 5: 编译测试**

```bash
ninja -C builddir
./builddir/battery-monitor
```

Expected: 自启动文件正确创建

- [ ] **Step 6: 提交**

```bash
git add .
git commit -m "feat: 实现开机自启动功能"
```

---

## Task 11: 图标资源

**Covers:** 5.2

**Files:**
- Create: `battery-monitor/icons/tray/*.svg`

- [ ] **Step 1: 创建托盘图标 SVG**

创建以下图标文件：
- `battery-20.svg` - 0-20% 电量
- `battery-40.svg` - 20-40% 电量
- `battery-60.svg` - 40-60% 电量
- `battery-80.svg` - 60-80% 电量
- `battery-100.svg` - 80-100% 电量
- `battery-charging.svg` - 充电状态

示例 `battery-20.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
  <rect x="2" y="6" width="18" height="12" rx="2" fill="none" stroke="#666" stroke-width="2"/>
  <rect x="22" y="9" width="2" height="6" fill="#666"/>
  <rect x="4" y="8" width="3" height="8" fill="#ff4444"/>
</svg>
```

- [ ] **Step 2: 提交**

```bash
git add .
git commit -m "feat: 添加托盘图标资源"
```

---

## Task 12: 打包配置

**Covers:** 4.4

**Files:**
- Create: `battery-monitor/debian/control`
- Create: `battery-monitor/debian/rules`
- Create: `battery-monitor/debian/postinst`
- Create: `battery-monitor/debian/prerm`

- [ ] **Step 1: 创建 debian/control**

```
Package: battery-monitor
Version: 1.0.0
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Your Name <your@email.com>
Description: Linux 电池监控工具
 一个轻量级的 Linux 电池监控应用，支持系统托盘、
 桌面小组件、历史图表等功能。
Depends: libgtk-3-0, libayatana-appindicator3-1
Build-Depends: debhelper (>= 10), meson, valac, 
               libgtk-3-dev, libayatana-appindicator3-dev
```

- [ ] **Step 2: 创建 debian/rules**

```makefile
#!/usr/bin/make -f

%:
	dh $@ --buildsystem=meson

override_dh_auto_install:
	dh_auto_install
	install -D -m 755 debian/battery-monitor.postinst debian/postinst
```

- [ ] **Step 3: 创建 debian/postinst**

```bash
#!/bin/bash
set -e

case "$1" in
    configure)
        # 更新桌面数据库
        update-desktop-database /usr/share/applications || true
        update-icon-caches /usr/share/icons || true
        ;;
esac

#DEBHELPER#
```

- [ ] **Step 4: 创建 debian/prerm**

```bash
#!/bin/bash
set -e

case "$1" in
    remove|upgrade|deconfigure)
        # 删除自启动文件
        rm -f ~/.config/autostart/battery-monitor.desktop || true
        ;;
esac

#DEBHELPER#
```

- [ ] **Step 5: 使 debian/rules 可执行**

```bash
chmod +x debian/rules
```

- [ ] **Step 6: 提交**

```bash
git add .
git commit -m "feat: 添加 Debian 打包配置"
```

---

## Task 13: 构建 .deb 包

**Covers:** 4.4

- [ ] **Step 1: 安装打包工具**

```bash
sudo apt install -y devscripts debhelper
```

- [ ] **Step 2: 构建包**

```bash
cd /home/liubing/文档/battery/battery-monitor
dpkg-buildpackage -us -uc -b
```

- [ ] **Step 3: 验证包**

```bash
ls -la ../battery-monitor_1.0.0_amd64.deb
dpkg-deb --info ../battery-monitor_1.0.0_amd64.deb
```

- [ ] **Step 4: 安装测试**

```bash
sudo dpkg -i ../battery-monitor_1.0.0_amd64.deb
battery-monitor
```

- [ ] **Step 5: 提交**

```bash
git add .
git commit -m "build: 生成 v1.0.0 发布版本"
```

---

## Task 14: 最终验证

**Covers:** 全部

- [ ] **Step 1: 功能测试清单**

- [ ] 系统托盘图标显示正常
- [ ] 右键菜单功能正常
- [ ] 主窗口显示所有电池信息
- [ ] 数据每2秒自动刷新
- [ ] 桌面小组件显示正常
- [ ] 小组件可拖动
- [ ] 历史数据记录正常
- [ ] 低电量通知正常
- [ ] 设置保存/加载正常
- [ ] 开机自启动配置正常

- [ ] **Step 2: 性能测试**

```bash
# 检查内存占用
ps aux | grep battery-monitor

# 检查 CPU 占用
top -p $(pgrep battery-monitor)
```

Expected: 内存 < 15MB，CPU < 1%

- [ ] **Step 3: 安装/卸载测试**

```bash
# 卸载
sudo dpkg -r battery-monitor

# 重新安装
sudo dpkg -i ../battery-monitor_1.0.0_amd64.deb

# 验证
which battery-monitor
```

- [ ] **Step 4: 最终提交**

```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

---

**计划完成。**
