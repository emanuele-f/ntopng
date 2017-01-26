--
-- (C) 2017 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local host_pools_utils = require "host_pools_utils"
local json = require "dkjson"

sendHTTPHeader('text/html; charset=iso-8859-1')

local ifid = _GET["ifid"]
local pool_id = _GET["pool"]
local res = {data={}, sort={{"column_", "asc"}}, totalRows=0}
local currpage = tonumber(_GET["currentPage"]) or 1
local perpage = tonumber(_GET["perPage"]) or 5

local start_i = (currpage-1) * perpage
local stop_i = start_i + perpage - 1
local i = 0

if((ifid ~= nil) and (isAdministrator())) then
  if pool_id ~= nil then
    local active_hosts = interface.getHostsInfo(false, nil, nil, nil, nil, nil, nil, nil, nil, nil, true--[[no macs]], tonumber(pool_id)).hosts
    local network_stats = interface.getNetworksStats()

    for _,member in ipairs(host_pools_utils.getPoolMembers(ifid, pool_id)) do
      if (i >= start_i) and (i <= stop_i) then
        local _, key = getRedisHostKey(member.key)
        local link

        if active_hosts[key] then
          link = ntop.getHttpPrefix() .. "/lua/host_details.lua?" .. hostinfo2url(active_hosts[key])
        elseif interface.getMacInfo(key) ~= nil then
          link = ntop.getHttpPrefix() .. "/lua/mac_details.lua?host=" .. key
        elseif network_stats[key] ~= nil then
          link = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?network=" .. network_stats[key].network_id
        else
          link = ""
        end

        local alias = getHostAltName(member.key, true --[[ accept null result ]])
        if alias == nil then alias = "" end

        res.data[#res.data + 1] = {
          column_member = member.address,
          column_alias = alias,
          column_icon = ntop.getHashCache("ntopng.host_icons",  member.key),
          column_vlan = member.vlan,
          column_link = link,
        }
      end
      i = i + 1
    end
  else
    for _,pool in ipairs(host_pools_utils.getPoolsList(ifid)) do
      if (i >= start_i) and (i <= stop_i) then
        local undeletable_pools = host_pools_utils.getUndeletablePools()

        if pool.id ~= host_pools_utils.DEFAULT_POOL_ID then
          res.data[#res.data + 1] = {
            column_pool_id = pool.id,
            column_pool_name = pool.name,
            column_pool_undeletable = undeletable_pools[pool.id] or false,
            column_pool_link = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?pool=" .. pool.id
          }
        end
      end
      i = i + 1
    end
  end
end

res.totalRows = i

return print(json.encode(res, nil, 1))
