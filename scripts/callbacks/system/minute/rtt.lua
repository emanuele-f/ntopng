--
-- (C) 2013-19 - ntop.org
--

local ts_utils = require("ts_utils_core")
local rtt_utils = require("rtt_utils")
local format_utils = require("format_utils")
local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local probe = {
  name = "RTT Monitor",
  description = "Monitors the round trip time of an host",
  page_script = "rtt_stats.lua",
  page_order = 1500,
}

-- ##############################################

function probe.entityConfig(entity_type, entity_value)
   local h_info = hostkey2hostinfo(entity_value)
   local h_ip = h_info["host"]
   local rtt_host_key = rtt_utils.host2key(h_ip, ternary(isIPv4(h_ip), "ipv4", "ipv6"), "icmp")

   res = {}
   if entity_type == "host" then
      return {url = ntop.getHttpPrefix().."/lua/system/rtt_stats.lua?rtt_host="..rtt_host_key}
   end
end

-- ##############################################

function probe.getTimeseriesMenu(ts_utils)
  return {
    {schema="monitored_host:rtt",              label=i18n("graphs.num_ms_rtt")},
  }
end

-- ##############################################

return probe
