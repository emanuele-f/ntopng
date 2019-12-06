--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")

local script

-- #################################################################

local function check_interface_drops(params)
  local info = params.entity_info
  local stats = info.stats_since_reset
  local threshold = tonumber(params.alert_config.threshold)
  local drop_perc = math.min(stats.drops * 100.0 / (stats.drops + stats.packets + 1), 100)
  local drops_type = alerts_api.tooManyDropsType(stats.drops, drop_perc, threshold)

  if((stats.packets > 100) and (drop_perc > threshold)) then
    alerts_api.trigger(params.alert_entity, drops_type, nil, params.cur_alerts)
  else
    alerts_api.release(params.alert_entity, drops_type, nil, params.cur_alerts)
  end
end

-- #################################################################

script = {
  default_enabled = true,
  default_value = {
    -- "> 5%"
    operator = "gt",
    threshold = 5,
  },

  hooks = {
    min = check_interface_drops,
  },

  gui = {
    i18n_title = "show_alerts.interface_drops_threshold",
    i18n_description = "show_alerts.interface_drops_threshold_descr",
    i18n_field_unit = user_scripts.field_units.percentage,
    input_builder = user_scripts.threshold_cross_input_builder,
    post_handler = user_scripts.threshold_cross_post_handler,
    field_max = 99,
    field_min = 1,
    field_operator = "gt";
  }
}

-- #################################################################

return script
