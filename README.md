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
* Networking
   * Configurator
   * NTP
* OTA Updates
* Most things from the original init system.
* CI
* Error handling.
   * Avoid factory resetting at all costs

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

# Things i am unsure about
* CeleryScript - Has both network _and_ core requirements.
* Farmware - Same
* database migrations might have been borked/need attention for upgrading production devices.
* Some early logs may need to be cleaned up.
* CI
