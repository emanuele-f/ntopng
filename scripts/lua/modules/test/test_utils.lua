--
-- (C) 2017-18 - ntop.org
--

local test_utils = {}

local alerts = require("alerts_api")
local test_failed_alert = alerts:newAlert({
  type = "test_failed",
  entity = "test"
  severity = "error",
})

local function test_error(msg)
  test_failed_alert:emit("test", msg)
end

local function test_assert(cond, error_msg)
   if not cond then
      test_error(error_msg)
   end
end

function test_utils.check_alerts(ifid, working_status)
   local if_stats = interface.getStats()
   if working_status.granularity == "min" then
      -- minute checks
      test_assert(if_stats.stats.hosts > 0, string.format("No host detected. [hosts: %d]", if_stats.stats.hosts))
      test_assert(if_stats.stats.flows > 0, string.format("No flow detected. [flows: %d]", if_stats.stats.flows))
   elseif working_status.granularity == "5mins" then
      -- 5-minute checks
   elseif working_status.granularity == "hour" then
      -- hourly checks
   elseif working_status.granularity == "day" then
      -- daily checks
   end
end

return test_utils
