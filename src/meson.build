subdir('live-chart-1.10.0')

serial_plotter_sources = [
  'main.vala',
  'application.vala',
  'window.vala',
  'preferences.vala',
  'config.vala',
  'circular_buffer.vala',
  'serial_port/serial_port.vala'
]

serial_plotter_deps = [
  config_dep,
  dependency('gtk4'),
  dependency('gee-0.8'),
  dependency('libadwaita-1', version: '>= 1.4'),
  meson.get_compiler('vala').find_library('posix'),
]

serial_plotter_sources += gnome.compile_resources('seriot-resources',
  'seriot.gresource.xml',
  c_name: 'serial_plotter'
)

executable('seriot', serial_plotter_sources,
  dependencies: deps + [livechart_dep] + serial_plotter_deps,
  link_with: livechart_lib,
  include_directories: config_inc,
       install: true,
)
