--
-- (C) 2018 - ntop.org
--

local driver = {}

local ts_types = require("ts_types")

local json = require("dkjson")
require("ntop_utils")

--
-- Sample query:
--    select * from "iface:ndpi" where ifid='0' and protocol='SSL'
--
-- See also callback_utils.uploadTSdata
--

local INFLUX_QUERY_TIMEMOUT_SEC = 5

-------------------------------------------------------

function driver:new(options)
  local obj = {}

  setmetatable(obj, self)
  self.__index = self

  return obj
end

-------------------------------------------------------

function driver:append(schema, timestamp, tags, metrics)
  local tags_string = table.tconcat(tags, "=", ",")
  local metrics_string = table.tconcat(metrics, "=", ",")

  -- E.g. iface:ndpi_categories,category=Network,ifid=0 bytes=371707
  -- NB: time format is in nanoseconds UTC
  local api_line = schema.name .. "," .. tags_string .. " " .. metrics_string .. " " .. timestamp .. "000000000\n"

  return ntop.appendInfluxDB(api_line)
end

-------------------------------------------------------

local function influx_query(full_url)
  local res = ntop.httpGet(full_url, "", "", INFLUX_QUERY_TIMEMOUT_SEC, true)

  if not res then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid reply")
    return nil
  end

  if res.RESPONSE_CODE ~= 200 then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad response code[" .. res.RESPONSE_CODE .. "]: " .. (res.CONTENT or ""))
    return nil
  end

  if res.CONTENT == nil then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing content")
    return nil
  end

  local jres = json.decode(res.CONTENT)

  if (not jres) or (not jres.results) or (not #jres.results) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid JSON reply[" .. res.CONTENT_LEN .. " bytes]: " .. string.sub(res.CONTENT, 1, 50))
    return nil
  end

  if not jres.results[1].series then
    -- no results fount
    return nil
  end

  return jres.results[1]
end

-------------------------------------------------------

local function influx2Series(schema, tstart, tend, tags, options, data, time_step)
  local data_type = schema.options.metrics_type
  local series = {}

  -- Create the columns
  for i=2, #data.columns do
    series[i-1] = {label=data.columns[i], data={}}
  end

  -- Time tracking to fill the missing points
  local prev_t = tstart + time_step
  local series_idx = 1
  --tprint(tstart .. " vs " .. data.values[1][1])

  -- Convert the data
  for idx, values in ipairs(data.values) do
    local cur_t = data.values[idx][1]

    if (idx == 1) and (data_type ~= ts_types.counter) then
      -- skip first point when no derivative is performed as an issue with GROUP BY
      goto continue
    end

    -- Fill the missing points
    while((cur_t - prev_t) > time_step) do
      for _, serie in pairs(series) do
        serie.data[series_idx] = options.fill_value
      end

      series_idx = series_idx + 1
      prev_t = prev_t + time_step
    end

    for i=2, #values do
      local val = values[i]

      if val < options.min_value then
        val = options.min_value
      elseif val > options.max_value then
        val = options.max_value
      end

      series[i-1].data[series_idx] = val
    end

    series_idx = series_idx + 1
    prev_t = cur_t
    ::continue::
  end

   -- Fill the missing points at the end
  while((tend - prev_t) > time_step) do
    for _, serie in pairs(series) do
      serie.data[series_idx] = options.fill_value
    end

    series_idx = series_idx + 1
    prev_t = prev_t + time_step
  end

  local count = series_idx - 1

  return series, count
end

-------------------------------------------------------

local function getTotalSerieQuery(schema, tstart, tend, tags, time_step, data_type)
  local query = 'SELECT SUM("value") AS "total_serie" FROM ' ..
    '(SELECT (' .. table.concat(schema._metrics, " + ") ..') AS "value" FROM "'.. schema.name ..'" WHERE ' ..
    table.tconcat(tags, "=", " AND ", nil, "'") .. ' AND time >= ' .. tstart .. '000000000 AND time <= ' .. tend .. '000000000)'..
    ' GROUP BY time('.. time_step ..'s)'

  if data_type == ts_types.counter then
    query = "SELECT NON_NEGATIVE_DERIVATIVE(total_serie) AS total_serie FROM (" .. query .. ")"
  end

  return query
end

-------------------------------------------------------

local function makeTotalSerie(schema, tstart, tend, tags, options, url, time_step)
  local data_type = schema.options.metrics_type
  local query = getTotalSerieQuery(schema, tstart, tend, tags, time_step, data_type)

  local full_url = url .. "/query?db=ntopng&epoch=s&q=" .. urlencode(query)
  local data = influx_query(full_url)

  if not data then
    return nil
  end

  data = data.series[1]

  local avg = table.remove(data.values, 1)[3]
  data.columns[3] = nil

  local series, count = influx2Series(schema, tstart, tend, tags, options, data, time_step)
  return series[1].data, avg
end

-------------------------------------------------------

local function calcStats(schema, tstart, tend, tags, time_step, url)
  local data_type = schema.options.metrics_type
  local query = getTotalSerieQuery(schema, tstart, tend, tags, time_step, data_type)
  query = 'SELECT SUM("total_serie") * ' .. schema.options.step .. ', MEAN("total_serie"), PERCENTILE("total_serie", 95) FROM (' .. query .. ")"

  local full_url = url .. "/query?db=ntopng&epoch=s&q=" .. urlencode(query)
  local data = influx_query(full_url)

  if (data and data.series and data.series[1] and data.series[1].values[1]) then
    local data_stats = data.series[1].values[1]
    local total = data_stats[2]

    if data_type == ts_types.gauge then
      -- no total for gauge values!
      total = nil
    end

    return {
      total = total,
      average = data_stats[3],
      ["95th_percentile"] = data_stats[4],
    }
  end

  return nil
end

-------------------------------------------------------

function calculateSampledTimeStep(schema, tstart, tend, options)
  local estimed_num_points = math.ceil((tend - tstart) / schema.options.step)
  local time_step = schema.options.step

  if estimed_num_points > options.max_num_points then
    -- downsample
    local num_samples = math.ceil(estimed_num_points / options.max_num_points)
    time_step = num_samples * schema.options.step
  end

  return time_step
end

-------------------------------------------------------

function driver:query(schema, tstart, tend, tags, options)
  local metrics = {}
  local time_step = calculateSampledTimeStep(schema, tstart, tend, options)
  local data_type = schema.options.metrics_type

  for i, metric in ipairs(schema._metrics) do
    -- NOTE: why we need to device by time_step ? is MEAN+GROUP BY TIME bugged?
    if data_type == ts_types.counter then
      metrics[i] = "(DERIVATIVE(MEAN(\"" .. metric .. "\")) / ".. time_step ..") as " .. metric
    else
      metrics[i] = "MEAN(\"".. metric .."\") as " .. metric
    end
  end

  local url = ntop.getPref("ntopng.prefs.ts_post_data_url")

  -- NOTE: GROUP BY TIME and FILL do not work well together! Additional zeroes produce non-existent derivative values
  -- Will perform fill manually below
  local query = 'SELECT '.. table.concat(metrics, ",") ..' FROM "' .. schema.name .. '" WHERE ' ..
      table.tconcat(tags, "=", " AND ", nil, "'") .. " AND time >= " .. tstart .. "000000000 AND time <= " .. tend .. "000000000" ..
      " GROUP BY TIME(".. time_step .."s)"

  local full_url = url .. "/query?db=ntopng&epoch=s&q=" .. urlencode(query)
  local data = influx_query(full_url)

  if not data then
    return nil
  end

  local series, count = influx2Series(schema, tstart, tend, tags, options, data.series[1], time_step)
  local stats = nil

  if options.calculate_stats then
    stats = calcStats(schema, tstart, tend, tags, time_step, url)
  end

  local rv = {
    start = tstart,
    step = time_step,
    count = count,
    series = series,
    statistics = stats
  }

  return rv
end

-------------------------------------------------------

function driver:flush()
  return true
end

-------------------------------------------------------

function driver:listSeries(schema, tags_filter, wildcard_tags, start_time)
  local url = ntop.getPref("ntopng.prefs.ts_post_data_url")

  -- NOTE: time based query not currently supported on show tags/series, using select
  -- https://github.com/influxdata/influxdb/issues/5668
  local query = 'SELECT * FROM "' .. schema.name .. '" WHERE ' ..
      table.tconcat(tags_filter, "=", " AND ", nil, "'") ..
      " AND time >= " .. start_time .. "000000000" ..
      ternary(not table.empty(wildcard_tags), " GROUP BY " .. table.concat(wildcard_tags, ","), "") ..
      " LIMIT 1"

  local full_url = url .. "/query?db=ntopng&q=" .. urlencode(query)
  local data = influx_query(full_url)

  if not data then
    return nil
  end

  if table.empty(data.series) then
    return {}
  end

  if table.empty(wildcard_tags) then
    -- Simple "exists" check
    if not table.empty(data.series[1].values) then
      return tags_filter
    else
      return {}
    end
  end

  local res = {}

  for _, serie in pairs(data.series) do
    for _, value in pairs(serie.values) do
      local tags = {}

      for i=2, #value do
        local tag = serie.columns[i]

        -- exclude metrics
        if schema.tags[tag] ~= nil then
          tags[tag] = value[i]
        end
      end

      for key, val in pairs(serie.tags) do
        tags[key] = val
      end

      res[#res + 1] = tags
    end
  end

  return res
end

-------------------------------------------------------

function driver:topk(schema, tags, tstart, tend, options, top_tags)
  local url = ntop.getPref("ntopng.prefs.ts_post_data_url")

  if #top_tags ~= 1 then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "InfluxDB driver expects exactly one top tag, " .. #top_tags .. " found")
    return nil
  end

  local top_tag = top_tags[1]
  local query = 'SELECT TOP("value", "'.. top_tag ..'", '.. options.top ..') FROM (SELECT '.. top_tag ..
      ', (' .. table.concat(schema._metrics, " + ") ..') AS "value" FROM "'.. schema.name ..'" WHERE '..
      table.tconcat(tags, "=", " AND ", nil, "'") .. ' AND time >= '.. tstart ..'000000000 AND time <= '.. tend ..'000000000);'
  local full_url = url .. "/query?db=ntopng&epoch=s&q=" .. urlencode(query)

  local data = influx_query(full_url)

  if not data then
    return nil
  end

  if table.empty(data.series) then
    return {}
  end

  data = data.series[1]

  local res = {}

  for idx, value in pairs(data.values) do
    -- top value
    res[idx] = value[2]
  end

  local sorted = {}

  for idx in pairsByValues(res, rev) do
    local value = data.values[idx]

    sorted[#sorted + 1] = {
      tags = table.merge(tags, {[top_tag] = value[3]}),
      value = value[2],
    }
  end

  local time_step = calculateSampledTimeStep(schema, tstart, tend, options)
  local stats = nil

  if options.calculate_stats then
    stats = calcStats(schema, tstart, tend, tags, time_step, url)
  end

  local total_serie, avg = makeTotalSerie(schema, tstart, tend, tags, options, url, time_step)

  return {
    topk = sorted,
    statistics = stats,
     additional_series = {
      total = total_serie,
    },
  }
end

-------------------------------------------------------

return driver
