--
-- (C) 2019 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")

-- #################################################################

local script = {
   key = "blacklisted",

   -- NOTE: hooks defined below
   hooks = {},
}

-- #################################################################

function script.hooks.protocolDetected(params)
   if flow.isBlacklisted() then
      flow.triggerStatus(flow_consts.status_types.status_blacklisted.status_id, flow.getBlacklistedInfo())
   end
end

-- #################################################################

return script
