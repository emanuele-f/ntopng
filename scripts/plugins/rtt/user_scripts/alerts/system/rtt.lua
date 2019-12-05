--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")

local script = {
  -- This module is enabled by default
  default_enabled = true,

  -- No default configuration is provided
  default_value = {},

  -- See below
  hooks = {},
}

-- #################################################################

-- Defines an hook which is executed every minute
function script.hooks.min(params)
  --~ local value = info["hits.syn_scan_victim"] or 0

  -- Check if the configured threshold is crossed by the value and possibly trigger an alert
  --~ alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_tcp_syn_scan, value)
  tprint("TODO minute check")
end

-- #################################################################

return script
