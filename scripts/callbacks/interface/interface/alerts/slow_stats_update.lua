--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local script = {
  default_enabled = true,
  anomaly_type_builder = alerts_api.slowStatsUpdateType,

  hooks = {
    min = alerts_api.anomaly_check_function,
  },
}

-- #################################################################

return script
