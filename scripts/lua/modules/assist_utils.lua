--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local os_utils = require("os_utils")

local SERVICE_NAME = "n2n"
local DEVICE_IP = "192.168.166.1"
local SUPERNODE_ADDRESS = "dns.ntop.org:7777"
local CONF_DIR = dirs.workingdir.."/n2n"
local CONF_FILE = CONF_DIR .. "/edge.conf"
local assist_utils = {}

-- ########################################################

function assist_utils.isAvailable()
  --return isAdministrator() and os_utils.hasService(SERVICE_NAME)
  return true
end

-- ########################################################

function assist_utils.createConfig(community, key)
  local prefs = ntop.getPrefs()

  if not ntop.mkdir(CONF_DIR) then
    return false
  end

  local f = io.open(CONF_FILE, "w")

  if not f then
    return false
  end

  f:write("-d=n2n0\n")
  f:write("-l=".. SUPERNODE_ADDRESS .."\n")
  f:write("-c=".. community .."\n")
  f:write("-k=".. key .."\n")

  if not isEmptyString(prefs.user) then
    -- uid=999(ntopng) gid=999(ntopng) groups=999(ntopng)
    local res = os_utils.execWithOutput("id " .. prefs.user) or ""
    local uid = res:gmatch("uid=(%d+)")()
    local gid = res:gmatch("gid=(%d+)")()

    if((uid ~= nil) and (gid ~= nil)) then
      f:write("-u=".. uid .."\n");
      f:write("-g=".. gid .."\n");
    end
  end

  f:write("-a=".. DEVICE_IP .."\n")

  f:close()

  return true
end

-- ########################################################

function assist_utils.isEnabled()
  return(ntop.getPref("ntopng.prefs.remote_assistance.enabled") == "1")
end

-- ########################################################

function assist_utils.enableAndStart()
  os_utils.enableService(SERVICE_NAME)
  return os_utils.restartService(SERVICE_NAME)
end

-- ########################################################

function assist_utils.disableAndStop()
  os_utils.disableService(SERVICE_NAME)
  return os_utils.stopService(SERVICE_NAME)
end

-- ########################################################

function assist_utils.getStatus()
  return os_utils.serviceStatus(SERVICE_NAME)
end

-- ########################################################

function assist_utils.statusLabel()
  local rv = os_utils.serviceStatus(SERVICE_NAME)
  local color
  local status

  if rv == "active" then
    status = i18n("running")
    color = "success"
  elseif rv == "inactive" then
    status = i18n("nedge.status_inactive")
    color = "default"
  else -- error
    status = i18n("error")
    color = "danger"
  end

  return [[<span class="label label-]] .. color .. [[">]] .. status ..[[</span>]]
end

-- ########################################################

return assist_utils
