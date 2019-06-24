--
-- (C) 2013-19 - ntop.org
--

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--~ require "alert_utils"
local json = require("dkjson")

local alerts = {}

-- ##############################################

-- Define a new alert
function alerts:newAlert(metadata)
  -- TODO necessary checks
  local obj = table.clone(metadata)

  setmetatable(obj, self)
  self.__index = self

  return(obj)
end

-- ##############################################

-- Get an existing alert
function alerts:getAlert(metadata)
  --TODO
  return(self:newAlert(metadata))
end

-- ##############################################

function alerts:emit(entity_value, alert_message, when)
  local force = false
  local msg = alert_message
  when = when or os.time()

  if(type(alert_message) == "table") then
    msg = json.encode(alert_message)
  end

  return(interface.emitAlert(when, alertEngine(self.periodicity),
    alertType(self.type), alertSeverity(self.severity),
    alertEntity(self.entity_type), entity_value, msg))
end

-- ##############################################

return(alerts)
