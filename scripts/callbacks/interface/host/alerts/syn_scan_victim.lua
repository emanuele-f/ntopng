--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")

local script = {
  threshold_type_builder = alerts_api.synScanType,
  default_enabled = true,
  default_value = {
    -- "> 30"
    operator = "gt",
    edge = 30,
  },

  hooks = {
    min = alerts_api.threshold_check_function,
  },

  gui = {
    i18n_title = "entity_thresholds.syn_scan_victim_title",
    i18n_description = "entity_thresholds.syn_scan_victim_description",
    i18n_field_unit = user_scripts.field_units.syn_min,
    input_builder = user_scripts.threshold_cross_input_builder,
    post_handler = user_scripts.threshold_cross_post_handler,
    field_max = 65535,
    field_min = 1,
    field_operator = "gt";
  }
}

-- #################################################################

function script.get_threshold_value(granularity, info)
  local sf = host.getSynScan()
  return(sf["hits.syn_scan_victim"] or 0)
end

-- #################################################################

return script
