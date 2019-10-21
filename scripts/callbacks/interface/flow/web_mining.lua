--
-- (C) 2019 - ntop.org
--

local flow_consts = require("flow_consts")

-- #################################################################

local script = {
  key = "web_mining",

  -- NOTE: hooks defined below
  hooks = {},
}

-- #################################################################

function script.setup()
  local enabled = (ntop.getPref("ntopng.prefs.mining_alerts") == "1")
  return(enabled)
end

-- #################################################################

function script.hooks.protocolDetected(params)
  local info = params.flow_info

  if(info["proto.ndpi_cat"] == "Mining") then
    flow.triggerStatus(flow_consts.status_types.status_web_mining_detected.status_id)
  end
end

-- #################################################################

return script
