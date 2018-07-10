# FarmbotNG
Restructure of FarmbotOS to fix network and log errors.

# Things that still need migrating
* CeleryScript
   * Scheduling
   * Integration with `farmbot_core` somehow. (`@behaviour` maybe?)
* Farmware
   * HTTP Endpoint
   * unix domain socket?
   * lua?
* CI
* Error handling.
   * Avoid factory resetting at all costs
   * Where to put factory reset code? `farmbot_os` i guess?
   * how to handle lower deps crashing?
* Pin Bindings

# Things that have been migrated
* asset storage -> `farmbot_core`
* farmbot_firmware (partially) -> `farmbot_core`
   * missing arduino firmware build
* logging
   * storage -> `farmbot_core`
   * uploading -> `farmbot_ext`
* bot state management (partially)
   * global state -> `farmbot_core`
   * real time updating -> `farmbot_ext`
* configuration (partially) -> `farmbot_core`
* farm_events -> `farmbot_core`
* regimens -> `farmbot_core`
* authorization -> `farmbot_ext`
* amqp -> `farmbot_ext`
* http client -> `farmbot_ext`
* auto sync messages -> `farmbot_ext`
* Easter Eggs -> `farmbot_os` might move to `farmbot_ext`
* OTA Updates -> `farmbot_os`
* Networking -> `farmbot_os` (will need to be revisited.)
   * Configurator
   * NTP
   * Setting node name is broken.
* System things -> `farmbot_os`
  * reboot/poweroff etc
  * factory reset
* System info -> `farmbot_os`
  * wifi network level
  * soc temp

# Things i am unsure about
* CeleryScript - Has both network _and_ core requirements.
* Farmware - Same
* database migrations might have been borked/need attention for upgrading production devices.
* Some early logs may need to be cleaned up.
* CI
