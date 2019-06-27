--
-- (C) 2013-19 - ntop.org
--

local alert_endpoints = {}

package.path = dirs.installdir .. "/scripts/lua/modules/alert_endpoints/?.lua;" .. package.path

-- ##############################################

-- NOTE: order is important as it defines evaluation order
local ALERT_NOTIFICATION_MODULES = {
   "custom", "nagios", "slack", "webhook"
}

if ntop.syslog then
   table.insert(ALERT_NOTIFICATION_MODULES, 1, "syslog")
end

if ntop.sendMail then -- only if email support is available
   table.insert(ALERT_NOTIFICATION_MODULES, 1, "email")
end

-- ##############################################

function alert_endpoints.getAlertNotificationModuleEnableKey(module_name, short)
   if module_name == "syslog" and ntop.getPref("ntopng.prefs.alerts_syslog") ~= "" then
      -- For backward compatibility
      if short then
	 return "alerts_syslog"
      else
	 return "ntopng.prefs.alerts_syslog"
      end
   end

   local short_k = "alerts." .. module_name .. "_notifications_enabled"

   if short then
      return short_k
   else
      return "ntopng.prefs." .. short_k
   end
end

-- ##############################################

function alert_endpoints.getAlertNotificationModuleSeverityKey(module_name, short)
   local short_k = "alerts." .. module_name .. "_severity"

   if short then
      return short_k
   else
      return "ntopng.prefs." .. short_k
   end
end

-- ##############################################

local function getEnabledAlertNotificationModules()
   local notifications_enabled = ntop.getPref("ntopng.prefs.alerts.external_notifications_enabled")
   local has_alerts_disabled = (ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1")

   if not notifications_enabled or has_alerts_disabled then
      return {}
   end

   local enabled_modules = {}

   for _, modname in ipairs(ALERT_NOTIFICATION_MODULES) do
      local module_enabled = ntop.getPref(alert_endpoints.getAlertNotificationModuleEnableKey(modname))
      local min_severity = ntop.getPref(alert_endpoints.getAlertNotificationModuleSeverityKey(modname))
      local req_name = modname

      if module_enabled == "1" then
         local ok, _module, j = pcall(require, req_name)

         if not ok then
            traceError(TRACE_ERROR, TRACE_CONSOLE, "Error while importing alert notification module " .. req_name)

            -- the traceback
            io.write(_module)
         else
	    if isEmptyString(min_severity) then
	       min_severity = _module.DEFAULT_SEVERITY or "warning"
	    end

            enabled_modules[#enabled_modules + 1] = {
               name = modname,
               severity = min_severity,
               export_frequency = tonumber(_module.EXPORT_FREQUENCY) or 60,
               export_queue = "ntopng.alerts.modules_notifications_queue." .. modname,
               ["module"] = _module,
            }
         end
      end
   end

   return enabled_modules
end

-- ##############################################

local modules = nil

local function loadModules()
  if modules == nil then
    modules = getEnabledAlertNotificationModules()
  end

  return(modules)
end

-- ##############################################

function alert_endpoints.dispatchNotification(message, json_message)
   loadModules()

   for _, m in ipairs(modules) do
      if message.severity >= alertSeverity(m.severity) then
         ntop.rpushCache(m.export_queue, json_message, MAX_NUM_PER_MODULE_QUEUED_ALERTS)
      end
   end
end

-- ##############################################

function alert_endpoints.processNotifications(now, periodic_frequency)
  loadModules()

  -- Process export notifications
  for _, m in ipairs(modules) do
    if force_export or ((now % m.export_frequency) < periodic_frequency) then

       local rv = m.module.dequeueAlerts(m.export_queue)

       if not rv.success then
          local msg = rv.error_message or "Unknown Error"

          -- TODO: generate alert
          traceError(TRACE_ERROR, TRACE_CONSOLE, "Error while sending notifications via " .. m.name .. " module: " .. msg)
       end
    end
  end
end

-- ##############################################

return(alert_endpoints)
