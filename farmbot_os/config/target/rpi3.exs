use Mix.Config
config :farmbot_os, :captive_portal_address, "192.168.24.1"
config :farmbot_os, kernel_modules: ["snd-bcm2835"]

config :nerves, :firmware,
  fwup_conf: "config/target/fwup.rpi3.conf"
