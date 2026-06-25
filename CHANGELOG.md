# Changelog

## v1.0.1 (2026-06-26)

### Bug Fixes

- **修复主窗口空白问题**: 窗口创建后未调用 `show_all()` 导致界面不显示

### Changed

- `main.vala`: 在 `create_main_window()` 方法中添加 `main_window.show_all()` 调用

---

## v1.0.0 (2026-06-26)

### Features

- 系统托盘动态图标（根据电量分档显示）
- 主窗口界面（电量/功率/预估/健康/历史图表）
- 桌面浮动小组件（可拖动、半透明背景）
- 低电量/充满电系统通知
- 设置界面（自启动、刷新间隔、通知阈值）
- 开机自启动支持
- 历史电量数据记录和图表展示

### Technical

- 使用 Vala + GTK-3 + Ayatana AppIndicator 技术栈
- 直接读取 `/sys/class/power_supply/BAT0/` 内核接口
- Meson 构建系统
- Debian 打包配置
