--
-- (C) 2018 - ntop.org
--

local driver = {}

local os_utils = require("os_utils")
local ts_types = require("ts_types")

-- TODO remove this dependency
require("graph_utils")

local RRD_CONSOLIDATION_FUNCTION = "AVERAGE"

local type_to_rrdtype = {
  [ts_types.counter] = "DERIVE",
  [ts_types.gauge] = "GAUGE",
}

-- NOTE: to get the actual rentention period, multiply retention_dp * aggregation_dp * step
local supported_steps = {
  ["1"] = {
    {aggregation_dp = 1, retention_dp = 86400},   -- 1 second resolution: keep for 1 day
    {aggregation_dp = 60, retention_dp = 43200},  -- 1 minute resolution: keep for 1 month
    {aggregation_dp = 3600, retention_dp = 2400}, -- 1 hour resolution: keep for 100 days
  },
  ["60"] = {
    {aggregation_dp = 1, retention_dp = 1440},    -- 1 minute resolution: keep for 1 day
    {aggregation_dp = 60, retention_dp = 2400},   -- 1 hour resolution: keep for 100 days
    {aggregation_dp = 1440, retention_dp = 365},  -- 1 day resolution: keep for 1 year
  },
  ["60_ext"] = {
    {aggregation_dp = 1, retention_dp = 43200},   -- 1 minute resolution: keep for 1 month
    {aggregation_dp = 60, retention_dp = 24000},  -- 1 hour resolution: keep for 100 days
    {aggregation_dp = 1440, retention_dp = 365},  -- 1 day resolution: keep for 1 year
  },
  ["300"] = {
    {aggregation_dp = 1, retention_dp = 288},     -- 5 minute resolution: keep for 1 day
    {aggregation_dp = 12, retention_dp = 2400},   -- 1 hour resolution: keep for 100 days
    {aggregation_dp = 288, retention_dp = 365},   -- 1 day resolution: keep for 1 year
  },
  ["300_ext"] = {
    {aggregation_dp = 1, retention_dp = 8640},    -- 5 minutes resolution: keep for 1 month
    {aggregation_dp = 12, retention_dp = 2400},   -- 1 hour resolution: keep for 100 days
    {aggregation_dp = 288, retention_dp = 365},   -- 1 day resolution: keep for 1 year
  }
}

-- TODO
--  RRA:HWPREDICT:1440:0.1:0.0035:288

-------------------------------------------------------

function driver:new(options)
  local obj = {
    base_path = options.base_path,
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

-------------------------------------------------------

-- TODO remove after migrating to the new path format
-- Maps second tag name to getRRDName
local HOST_PREFIX_MAP = {
  host = "",
  subnet = "net:",
  flowdev_port = "flow_device:",
  sflowdev_port = "sflow:",
  snmp_if = "snmp:",
}

local function get_fname_for_schema(schema, tags)
  if schema.options.rrd_fname ~= nil then
    return schema.options.rrd_fname
  end

  -- return the last defined tag
  return tags[schema._tags[#schema._tags]]
end

local function schema_get_path(schema, tags)
  local parts = {schema.name, }
  local rrd

  -- ifid is mandatory here
  local ifid = tags.ifid
  local host_or_network = nil

  if string.find(schema.name, "iface:") == nil and string.find(schema.name, "mac:") == nil then
    local parts = split(schema.name, ":")
    tprint(schema.name)
    host_or_network = (HOST_PREFIX_MAP[parts[1]] or parts[1]) .. tags[schema._tags[2]]
  end

  local path = getRRDName(ifid, host_or_network)
  local rrd = get_fname_for_schema(schema, tags)

  return path, rrd
end

-------------------------------------------------------

local function getRRAParameters(step, resolution, retention_time)
  local aggregation_dp = math.ceil(resolution / step)
  local retention_dp = math.ceil(retention_time / resolution)
  return aggregation_dp, retention_dp
end

-- This is necessary to keep the current RRD format
local function map_metrics_to_rrd_columns(schema_metrics)
  local num = #schema_metrics

  if num == 1 then
    return {"num"}
  elseif num == 2 then
    return {"sent", "rcvd"}
  elseif num == 3 then
    return {"ingress", "egress", "inner"}
  end

  io.write("[TS_RRD.ERROR] Unsupported number of metrics: " .. num)
  return nil
end

local function get_step_key(schema)
  local step_k = tostring(schema.options.step)

  if string.find(schema.name, "iface:tcp_") == 0 then
    -- This is an extended counter
    step_k = step_k .. "_ext"
  end

  return step_k
end

local function create_rrd(schema, path)
  if not ntop.exists(path) then
    local heartbeat = schema.options.rrd_heartbeat or (schema.options.step * 2)
    local params = {path, schema.options.step}

    local metrics_map = map_metrics_to_rrd_columns(schema._metrics)
    if not metrics_map then
      return false
    end

    for idx, metric in ipairs(schema._metrics) do
      local info = schema.metrics[metric]
      params[#params + 1] = "DS:" .. metrics_map[idx] .. ":" .. type_to_rrdtype[info.type] .. ':' .. heartbeat .. ':U:U'
    end

    for _, rra in pairs(supported_steps[get_step_key(schema)]) do
      params[#params + 1] = "RRA:" .. RRD_CONSOLIDATION_FUNCTION .. ":0.5:" .. rra.aggregation_dp .. ":" .. rra.retention_dp
    end

    ntop.rrd_create(unpack(params))
  end

  return true
end

-------------------------------------------------------

local function update_rrd(schema, rrdfile, timestamp, data)
  local params = {tolongint(timestamp), }

  for _, metric in ipairs(schema._metrics) do
    params[#params + 1] = tolongint(data[metric])
  end

  --io.write("UPDATE: ", rrdfile, " ", table.concat(params, ":"), "\n")
  ntop.rrd_update(rrdfile, unpack(params))
end

-------------------------------------------------------

local function verify_schema_compatibility(schema)
  if not supported_steps[get_step_key(schema)] then
    io.write("[TS_RRD.ERROR] Unsupported step: " .. schema.options.step .. " in shcema " .. schema.name)
    return false
  end

  if schema.tags.ifid == nil then
    io.write("[TS_RRD.ERROR] Missing ifid tag in schema " .. schema.name)
    return false
  end

  return true
end

function driver:append(schema, timestamp, tags, metrics)
  if not verify_schema_compatibility(schema) then
    return false
  end

  -- TEST
  --local ts_schema = require("ts_schema")
  --local _schema = ts_schema:new("host:traffic", {step=300})
  --_schema:addTag("ifid")
  --_schema:addTag("host")
  --_schema:addMetric("bytes_sent", ts_types.counter)
  --_schema:addMetric("bytes_rcvd", ts_types.counter)

  --base, rrd = schema_get_path(_schema, {ifid="0", host="192.168.1.2"})
  --rrdfile = os_utils.fixPath(base .. "/" .. rrd .. ".rrd")
  --tprint(rrdfile)
  -- TEST

  local base, rrd = schema_get_path(schema, tags)
  local rrdfile = os_utils.fixPath(base .. "/" .. rrd .. ".rrd")

  -- TEST
  if (rrdfile ~= "/var/tmp/ntopng/0/rrd/packets.rrd") and (rrdfile ~= "/var/tmp/ntopng/0/rrd/drops.rrd") and (rrdfile ~= "/var/tmp/ntopng/0/rrd/bytes.rrd") then
    tprint(rrdfile)
  end
  -- TEST

  ntop.mkdir(base)
  create_rrd(schema, rrdfile)
  update_rrd(schema, rrdfile, timestamp, metrics)

  return true
end

-------------------------------------------------------

function driver:query(schema, tstart, tend, tags)
  tprint("TODO QUERY")
end

function driver:delete(schema, tags)
  tprint("TODO DELETE")
end

return driver
