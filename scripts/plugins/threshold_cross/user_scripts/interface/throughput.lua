--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")

local script = {
  default_enabled = false,

  -- See below
  hooks = {},

  gui = {
    i18n_title = "alerts_thresholds_config.throughput",
    i18n_description = "alerts_thresholds_config.alert_throughput_description",
    i18n_field_unit = user_scripts.field_units.mbits,
    input_builder = user_scripts.threshold_cross_input_builder,
    post_handler = user_scripts.threshold_cross_post_handler,
  }
}

-- #################################################################

function script.hooks.all(params)
  local value = alerts_api.interface_delta_val(script.key, params.granularity, params.entity_info["stats"]["bytes"]) * 8 / granularity2sec(params.granularity)

  -- Check if the configured threshold is crossed by the value and possibly trigger an alert
  alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_threshold_cross, value)
end

-- #################################################################

return script
