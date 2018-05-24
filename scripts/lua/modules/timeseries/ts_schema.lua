--
-- (C) 2018 - ntop.org
--

local ts_schema = {}

function ts_schema:new(name, options)
  options = options or {}

  -- required options
  if not options.step then
    io.write("[TS.ERROR] Missing 'step' option\n")
    return nil
  end

  local obj = {name=name, options=options, _tags={}, _metrics={}, tags={}, metrics={}}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

function ts_schema:addTag(name)
  self._tags[#self.tags + 1] = name
  self.tags[name] = 1
end

-- metric_type: a type in ts_utils.metrics
function ts_schema:addMetric(name, metric_type)
  self._metrics[#self.metrics + 1] = name
  self.metrics[name] = {["type"]=metric_type}
end

function ts_schema:verifyTags(tags)
  for tag in pairs(self.tags) do
    if not tags[tag] then
      io.write("[TS.ERROR] Missing TAG " .. tag .. "\n")
      return false
    end
  end

  for tag in pairs(tags) do
    if not self.tags[tag] then
      io.write("[TS.ERROR] Unknown TAG " .. tag .. "\n")
      return false
    end
  end

  return true
end

function ts_schema:verifyTagsAndMetrics(tags_and_metrics)
  local tags = {}
  local metrics = {}

  for tag in pairs(self.tags) do
    if not tags_and_metrics[tag] then
      io.write("[TS.ERROR] Missing TAG " .. tag .. "\n")
      return nil
    end

    tags[tag] = tags_and_metrics[tag]
  end

  for metric in pairs(self.metrics) do
    if not tags_and_metrics[metric] then
      io.write("[TS.ERROR] Missing Metric " .. metric .. "\n")
      return nil
    end

    metrics[metric] = tags_and_metrics[metric]
  end

  for item in pairs(tags_and_metrics) do
    if not self.tags[item] and not self.metrics[item] then
      io.write("[TS.ERROR] Unknown TAG/Metric " .. item .. "\n")
      return nil
    end
  end

  return tags, metrics
end

return ts_schema
