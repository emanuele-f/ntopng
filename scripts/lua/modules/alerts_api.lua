--
-- (C) 2013-19 - ntop.org
--

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local json = require("dkjson")

local alerts = {}

-- Just helpers
local str_2_periodicity = {
  ["min"]     = 60,
  ["5mins"]   = 300,
  ["hour"]    = 3600,
  ["day"]     = 86400,
}

local known_alerts = {}

-- ##############################################

local function makeAlertId(alert_type, alert_entity)
  return(string.format("%s_%s", alert_type, alert_entity))
end

-- ##############################################

function alerts:newAlert(metadata)
  -- TODO necessary checks
  local obj = table.clone(metadata)

  if type(obj.periodicity == "string") then
    if(str_2_periodicity[obj.periodicity]) then
      obj.periodicity = str_2_periodicity[obj.periodicity]
    else
      -- TODO trace error
    end
  end

  local alert_id = makeAlertId(alertType(obj.type), alertEntity(obj.entity))
  known_alerts[alert_id] = obj

  setmetatable(obj, self)
  self.__index = self

  return(obj)
end

-- ##############################################

function alerts:emit(entity_value, alert_message, when)
  local force = false
  local msg = alert_message
  when = when or os.time()

  if(type(alert_message) == "table") then
    msg = json.encode(alert_message)
  end

  return(interface.emitAlert(when, self.periodicity,
    alertType(self.type), alertSeverity(self.severity),
    alertEntity(self.entity), entity_value, msg, self.subtype))
end

-- ##############################################

function alerts.getFormater(metadata)
  local alert_id = makeAlertId(metadata.alert_type, metadata.alert_entity)
  local alert = known_alerts[alert_id]

  if alert then
    return(alert.formatter)
  end

  return(nil)
end

-- ##############################################

return(alerts)
