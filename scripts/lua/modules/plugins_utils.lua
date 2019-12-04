--
-- (C) 2019 - ntop.org
--

local plugins_utils = {}

local os_utils = require("os_utils")
local persistence = require("persistence")
require "lua_trace"

local dirs = ntop.getDirs()

-- TODO support pro/enterprise
plugins_utils.PLUGINS_SOURCE_DIR = os_utils.fixPath(dirs.scriptdir .. "/plugins")

-- TODO: use more appropriate runtime path
plugins_utils.PLUGINS_RUNTIME_PATH = os_utils.fixPath(dirs.workingdir .. "/plugins")

local RUNTIME_PATHS = {}

-- ##############################################

function plugins_utils.listPlugins()
  local plugins = {}

  for plugin_name in pairs(ntop.readdir(plugins_utils.PLUGINS_SOURCE_DIR)) do
    local plugin_dir = os_utils.fixPath(plugins_utils.PLUGINS_SOURCE_DIR .. "/" .. plugin_name)

    if ntop.exists(plugin_dir .. "/plugin.lua") then
      package.path = plugin_dir .. "/?.lua;" .. package.path

      local metadata = require("plugin")

      -- Augument information
      metadata.path = plugin_dir
      metadata.key = plugin_name

      -- TODO check plugin dependencies

      plugins[plugin_name] = metadata
    end
  end

  return(plugins)
end

-- ##############################################

local function init_runtime_paths()
  RUNTIME_PATHS = {
    -- Definitions
    alert_definitions = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/alert_definitions"),
    status_definitions = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/status_definitions"),

    -- Modules
    modules = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/modules"),

    -- Locales
    locales = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/locales"),

    -- User/Alerts scripts
    interface_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/interface"),
    interface_alerts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/interface/alerts"),
    host_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/host"),
    host_alerts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/host/alerts"),
    network_scripts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/network"),
    network_alerts = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/interface/network/alerts"),
    syslog = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/syslog"),
    system = os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks/system"),
  }
end

-- ##############################################

local function copy_file(fname, src_path, dst_path)
  local src = os_utils.fixPath(src_path .. "/" .. fname)
  local dst = os_utils.fixPath(dst_path .. "/" .. fname)
  local infile, err = io.open(src, "r")

  if(ntop.exists(dst)) then
    -- NOTE: overwriting is not allowed as it means that a file was already provided by
    -- another plugin
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Trying to overwrite existing file %s", dst))
    return(false)
  end

  if(infile == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not open file %s for read: %s", src, err or ""))
    return(false)
  end

  local instr = infile:read("*a")
  infile:close()

  local outfile, err = io.open(dst, "w")
  if(outfile == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not open file %s for write", dst, err or ""))
    return(false)
  end

  outfile:write(instr)
  outfile:close()

  return(true)
end

local function recursive_copy(src_path, dst_path)
  for fname in pairs(ntop.readdir(src_path)) do
    if not copy_file(fname, src_path, dst_path) then
      return(false)
    end
  end

  return(true)
end

-- ##############################################

local function load_plugin_definitions(plugin)
  return(
    recursive_copy(os_utils.fixPath(plugin.path .. "/alert_definitions"), RUNTIME_PATHS.alert_definitions) and
    recursive_copy(os_utils.fixPath(plugin.path .. "/status_definitions"), RUNTIME_PATHS.status_definitions)
  )
end

-- ##############################################

local function load_plugin_modules(plugin)
  return(recursive_copy(os_utils.fixPath(plugin.path .. "/modules"), RUNTIME_PATHS.modules))
end

-- ##############################################

local function load_plugin_i18n(locales, default_locale, plugin)
  local locales_dir = os_utils.fixPath(plugin.path .. "/locales")
  local locales_path = ntop.readdir(locales_dir)

  if table.empty(locales_path) then
    return
  end

  -- Ensure that the plugin localization will not override any existing
  -- key
  if default_locale[plugin.key] then
    traceError(TRACE_WARNING, TRACE_CONSOLE, string.format(
      "Plugin name %s overlaps with an existing i18n key. Please rename the plugin.", plugin.key))
    return(false)
  end

  for fname in pairs(locales_path) do
    if string.ends(fname, ".lua") then
      local full_path = os_utils.fixPath(locales_dir .. "/" .. fname)
      local locale = persistence.load(full_path)

      if locale then
        locales[fname] = locales[locale_name] or {}
        locales[fname][plugin.key] = locale
      else
        return(false)
      end
    end
  end

  return(true)
end

-- ##############################################

local function load_plugin_user_scripts(plugin)
  local scripts_path = os_utils.fixPath(plugin.path .. "/user_scripts")

  return(
    recursive_copy(os_utils.fixPath(scripts_path .. "/interface"), RUNTIME_PATHS.interface_scripts) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/alerts/interface"), RUNTIME_PATHS.interface_alerts) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/host"), RUNTIME_PATHS.host_scripts) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/alerts/host"), RUNTIME_PATHS.host_alerts) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/network"), RUNTIME_PATHS.network_scripts) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/alerts/network"), RUNTIME_PATHS.network_alerts) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/syslog"), RUNTIME_PATHS.syslog) and
    recursive_copy(os_utils.fixPath(scripts_path .. "/system"), RUNTIME_PATHS.system)
  )
end

-- ##############################################

-- @brief Loads the ntopng plugins into a single directory tree.
-- @notes This should be called at startup
function plugins_utils.loadPlugins()
  local locales_utils = require("locales_utils")
  local plugins = plugins_utils.listPlugins()
  local locales = {}
  local en_locale = locales_utils.readDefaultLocale()

  -- Clean previous structure
  ntop.rmdir(plugins_utils.PLUGINS_RUNTIME_PATH)

  -- Initialize directories
  init_runtime_paths()

  for _, path in pairs(RUNTIME_PATHS) do
    ntop.mkdir(path)
  end

  for _, plugin in pairs(plugins) do
    if load_plugin_definitions(plugin) and
        load_plugin_i18n(locales, en_locale, plugin) and
        load_plugin_modules(plugin) and
        load_plugin_user_scripts(plugin) then
      traceError(TRACE_INFO, TRACE_CONSOLE, string.format("Successfully loaded plugin %s", plugin.key))
    else
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Errors occurred while processing plugin %s", plugin.key))
    end
  end

  -- Save the locales
  for fname, plugins_locales in pairs(locales) do
    local locale_path = os_utils.fixPath(RUNTIME_PATHS.locales .. "/" .. fname)

    persistence.store(locale_path, plugins_locales)
  end
end

-- ##############################################

return(plugins_utils)
