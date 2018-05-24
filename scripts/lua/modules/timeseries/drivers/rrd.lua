--
-- (C) 2018 - ntop.org
--

local driver = {}

local os_utils = require("os_utils")
local ts_types = require("ts_types")

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

-- E.g
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

local function get_fname_for_schema(schema_name)
  if string.find(schema_name, "traffic") then
    return "bytes"
  end

  return nil
end

local function schema_get_path(base_path, schema, tags)
  local parts = {schema.name, }

  for _, tag in ipairs(schema._tags) do
    parts[#parts + 1] = getPathFromKey(trimSpace(tags[tag]))
  end

  local fname = get_fname_for_schema(schema.name)
  if fname ~= nil then
    parts[#parts + 1] = fname
  end

  -- remove the RRD name
  local rrd = parts[#parts]
  parts[#parts] = nil

  return base_path .. "/" .. table.concat(parts, "/"), rrd
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

  if starts(schema.name, "iface:tcp_") then
    -- This is an extended counter
    step_k = step_k .. "_ext"
  end

  return step_k
end

local function create_rrd(schema, path)
  if not ntop.exists(path) then
    local heartbeat = schema.options.step * 2
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
    io.write("[TS_RRD.ERROR] Unsupported step: " .. schema.options.step)
    return false
  end

  if schema.tags.ifid == nil then
    io.write("[TS_RRD.ERROR] Missing ifid tag")
    return false
  end

  return true
end

function driver:append(schema, timestamp, tags, metrics)
  if not verify_schema_compatibility(schema) then
    return false
  end

  local base, rrd = schema_get_path(self.base_path, schema, tags)
  local rrdfile = os_utils.fixPath(base .. "/" .. rrd .. ".rrd")

  ntop.mkdir(base)
  create_rrd(schema, rrdfile)
  update_rrd(schema, rrdfile, timestamp, tags, metrics)

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
