project('battery-monitor', 'vala', 'c',
  version: '1.0.0',
  default_options: ['warning_level=2']
)

dependencies = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gtk+-3.0'),
  dependency('ayatana-appindicator3-0.1'),
]

sources = files(
  'src/main.vala',
  'src/battery.vala',
  'src/utils/config.vala',
  'src/ui/tray.vala',
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

icon_dir = join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps')
install_data(
  'icons/tray/battery-missing.svg',
  'icons/tray/battery-caution.svg',
  'icons/tray/battery-caution-charging.svg',
  'icons/tray/battery-low.svg',
  'icons/tray/battery-low-charging.svg',
  'icons/tray/battery-good.svg',
  'icons/tray/battery-good-charging.svg',
  'icons/tray/battery-full.svg',
  'icons/tray/battery-full-charging.svg',
  install_dir: icon_dir
)