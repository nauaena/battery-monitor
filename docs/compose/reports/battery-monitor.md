---
feature: battery-monitor
status: delivered
specs:
  - ../plans/2026-06-26-battery-monitor.md
plans:
  - ../plans/2026-06-26-battery-monitor.md
branch: master
commits: f5906b2..0d4cade
---

# Battery Monitor — Final Report

## What Was Built

Battery Monitor 是一个轻量级的 Linux 电池监控桌面应用，为 Linux Mint / Ubuntu 用户提供全面的电池状态监控。应用常驻系统托盘，实时显示电池电量、充放电功率、预估使用时间等关键信息。

主要功能包括：系统托盘动态图标、主窗口详细信息面板、桌面浮动小组件、历史电量图表、低电量/充满电通知、用户设置界面，以及开机自启动支持。

应用使用 Vala 语言 + GTK-3 框架开发，编译为原生二进制，内存占用约 50MB，启动快速。

## Architecture

```
battery-monitor/
├── src/
│   ├── main.vala              # 程序入口，Application 类
│   ├── battery.vala           # BatteryData 类，读取 /sys/class/power_supply/
│   ├── history.vala           # HistoryManager，JSON 存储历史数据
│   ├── ui/
│   │   ├── tray.vala          # TrayIcon，系统托盘图标和菜单
│   │   ├── window.vala        # MainWindow，主窗口界面
│   │   ├── widget.vala        # FloatingWidget，桌面浮动小组件
│   │   ├── chart.vala         # BatteryChart，Cairo 绘制图表
│   │   └── settings.vala      # SettingsWindow，设置界面
│   └── utils/
│       ├── config.vala        # Config，配置管理单例
│       ├── notification.vala  # NotificationManager，系统通知
│       └── autostart.vala     # AutostartManager，开机自启动
├── icons/tray/                # 9个 SVG 托盘图标
├── debian/                    # Debian 打包配置
└── meson.build                # 构建配置
```

**数据流：**
- BatteryData 从 `/sys/class/power_supply/BAT0/` 读取原始数据
- 定时器（2秒间隔）触发数据刷新
- 刷新时更新：托盘图标 → 主窗口 → 小组件 → 历史记录 → 通知检查
- HistoryManager 将数据持久化到 JSON 文件

**关键接口：**
- `BatteryData.update()` → bool：刷新所有电池属性
- `Config.get_instance()` → Config：单例访问配置
- `HistoryManager.get_entry(hours)` → Array：查询历史数据

## Design Decisions

- **Vala + GTK-3**：选择 Vala 是因为它是 GNOME 生态的原生语言，编译为 C 代码后性能接近 C，同时语法简洁。GTK-3 是 Linux Mint 的默认工具包，无需额外依赖。

- **/sys/class/power_supply/ 直接读取**：不依赖 UPower 守护进程，直接读取内核接口，减少依赖并提高可靠性。

- **JSON 存储历史数据**：使用 JSON-Glib 而非 SQLite，因为数据结构简单，JSON 文件易于调试和备份。

- **POPUP 窗口实现小组件**：使用 `Gtk.WindowType.POPUP` + 透明 RGBA 实现无边框浮动窗口，避免窗口管理器装饰。

## Usage

**安装：**
```bash
sudo dpkg -i battery-monitor_1.0.0_amd64.deb
```

**运行：**
```bash
battery-monitor              # 正常启动
battery-monitor --start-minimized  # 最小化到托盘
```

**系统托盘：**
- 左键：显示主窗口
- 右键：菜单（显示主窗口、设置、开机自启动开关、退出）

**桌面小组件：**
- 默认显示在右下角
- 左键拖动移动位置
- 右键：隐藏、透明度调节

**配置文件：**
`~/.config/battery-monitor/config.ini`

## Verification

| 验证项 | 结果 |
|--------|------|
| 编译 | ✅ meson + ninja 编译通过 |
| .deb 包 | ✅ 29KB，生成成功 |
| 启动 | ✅ 正常启动，显示主窗口 |
| 托盘图标 | ✅ 显示电池图标 |
| 数据读取 | ✅ 显示 23% 充电中 |
| 历史记录 | ✅ 数据写入 JSON |
| 通知 | ✅ 系统通知正常 |
| 设置保存 | ✅ 配置持久化 |
| 内存占用 | ✅ RSS ~51MB |

## Journey Log

- [lesson] Vala 中 `using Gtk` 后 `Application` 有歧义，需显式使用 `Gtk.Application`
- [lesson] Ayatana AppIndicator 的 Vala 命名空间是 `AppIndicator`，不是 `AyatanaAppIndicator`
- [lesson] debian/control 必须有 Source 段和 Build-Depends 段，否则构建报错
- [lesson] 使用 `GLib.get_real_time() / 1000000` 替代已废弃的 `TimeVal` 获取时间戳

## Source Materials

| File | Role | Notes |
|------|------|-------|
| `docs/compose/plans/2026-06-26-battery-monitor.md` | 实现计划 | 完整的 14 任务计划 |
| `README.md` | 需求文档 | 功能规格和技术方案 |
