/*
 *
 * (C) 2013-19 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* *************************************** */

LocalHost::LocalHost(NetworkInterface *_iface, Mac *_mac, u_int16_t _vlanId, IpAddress *_ip) : Host(_iface, _mac, _vlanId, _ip) {
#ifdef LOCALHOST_DEBUG
  char buf[48];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Instantiating local host %s", _ip ? _ip->print(buf, sizeof(buf)) : "");
#endif
  initialize();
}

/* *************************************** */

LocalHost::LocalHost(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId) : Host(_iface, ipAddress, _vlanId) {
  initialize();
}

/* *************************************** */

LocalHost::~LocalHost() {
  if(data_delete_requested)
    deleteRedisSerialization();
  else if((ntop->getPrefs()->is_idle_local_host_cache_enabled()
      || ntop->getPrefs()->is_active_local_host_cache_enabled())
     && (!ip.isEmpty())) {
    checkStatsReset();
    serializeToRedis();
  }

  freeLocalHostData();
}

/* *************************************** */

void LocalHost::initialize() {
  char buf[64];

  stats = allocateStats();
  updateHostPool(true /* inline with packet processing */, true /* first inc */);

  local_network_id = -1;
  drop_all_host_traffic = false;
  os = NULL;

  ip.isLocalHost(&local_network_id);
  networkStats = getNetworkStats(local_network_id);

  systemHost = ip.isLocalInterfaceAddress();

  PROFILING_SUB_SECTION_ENTER(iface, "LocalHost::initialize: local_host_cache", 16);
  if(ntop->getPrefs()->is_idle_local_host_cache_enabled()) {
    /* First try to deserialize with the mac based key */
    is_in_broadcast_domain = true;

    if(!deserializeFromRedis()) {
      deleteRedisSerialization();

      /* Deserialize by IP */
      is_in_broadcast_domain = false;

      if(!deserializeFromRedis())
        deleteRedisSerialization();
    }
  }
  PROFILING_SUB_SECTION_EXIT(iface, 16);

  char host[96];
  char *strIP = ip.print(buf, sizeof(buf));
  snprintf(host, sizeof(host), "%s@%u", strIP, vlan_id);
  char rsp[256];

  ntop->getRedis()->getAddress(strIP, rsp, sizeof(rsp), true);

  PROFILING_SUB_SECTION_ENTER(iface, "LocalHost::initialize: updateHostTrafficPolicy", 18);
  updateHostTrafficPolicy(host);
  PROFILING_SUB_SECTION_EXIT(iface, 18);

  iface->incNumHosts(true /* Local Host */);

#ifdef LOCALHOST_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s is %s [%p]",
			       ip.print(buf, sizeof(buf)),
			       isSystemHost() ? "systemHost" : "", this);
#endif
}

/* *************************************** */

char* LocalHost::getSerializationKey(char *redis_key, uint bufsize) {
  Mac *mac = getMac();

  if(isBroadcastDomainHost() && isDhcpHost() && mac &&
      iface->serializeLbdHostsAsMacs()) {
    char mac_buf[128];

    get_mac_based_tskey(mac, mac_buf, sizeof(mac_buf));

    return(getMacBasedSerializationKey(redis_key, bufsize, mac_buf));
  }

  return(getIpBasedSerializationKey(redis_key, bufsize));
}

/* *************************************** */

void LocalHost::deserialize(json_object *o) {
  json_object *obj;

  stats->deserialize(o);

  if(! mac) {
    u_int8_t mac_buf[6];
    memset(mac_buf, 0, sizeof(mac_buf));

    if(json_object_object_get_ex(o, "mac_address", &obj)) Utils::parseMac(mac_buf, json_object_get_string(obj));

    // sticky hosts enabled, we must bring up the mac address
    if((mac = iface->getMac(mac_buf, true /* create if not exists*/)) != NULL)
      mac->incUses();
    else
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: NULL mac. Are you running out of memory or MAC hash is full?");
  }

  if(json_object_object_get_ex(o, "seen.first", &obj)) first_seen = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "seen.last", &obj))  last_seen  = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "last_stats_reset", &obj)) last_stats_reset = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "broadcastDomainHost", &obj) && json_object_get_boolean(obj))
    setBroadcastDomainHost();

  if(json_object_object_get_ex(o, "os", &obj))
    inlineSetOS(json_object_get_string(obj));

  /* We commented the line below to avoid strings too long */
#if 0
  activityStats.reset();
  if(json_object_object_get_ex(o, "activityStats", &obj)) activityStats.deserialize(obj);
#endif

  checkStatsReset();
}

/* *************************************** */

void LocalHost::updateHostTrafficPolicy(char *key) {
  char buf[64], *host;

  if(key)
    host = key;
  else
    host = get_hostkey(buf, sizeof(buf));

  if(iface->isPacketInterface()) {
    if((ntop->getRedis()->hashGet((char*)DROP_HOST_TRAFFIC, host, buf, sizeof(buf)) == -1)
       || (strcmp(buf, "true") != 0))
      drop_all_host_traffic = false;
    else
      drop_all_host_traffic = true;

  }
}

/* ***************************************** */

char * LocalHost::get_os(char * const buf, ssize_t buf_len) {
  if(buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", os ? os : "");
    m.unlock(__FILE__, __LINE__);
  }

  return buf;
}

/* *************************************** */

void LocalHost::lua(lua_State* vm, AddressTree *ptree,
		    bool host_details, bool verbose,
		    bool returnHost, bool asListElement) {
  char buf_id[64], *host_id = buf_id;
  char *local_net;
  bool mask_host = Utils::maskHost(isLocalHost());

  if((ptree && (!match(ptree))) || mask_host)
    return;

  Host::lua(vm,
	    NULL /* ptree already checked */,
	    host_details, verbose, returnHost,
	    false /* asListElement possibly handled later */);

  lua_push_int32_table_entry(vm, "local_network_id", local_network_id);

  local_net = ntop->getLocalNetworkName(local_network_id);
  if(local_net == NULL)
    lua_push_nil_table_entry(vm, "local_network_name");
  else
    lua_push_str_table_entry(vm, "local_network_name", local_net);

  if(asListElement) {
    host_id = get_hostkey(buf_id, sizeof(buf_id));

    lua_pushstring(vm, host_id);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

void LocalHost::inlineSetOS(const char * const _os) {
  if((mac == NULL)
     /*
       When this happens then this is a (NAT+)router and
       the OS would be misleading
     */
     || (mac->getDeviceType() == device_networking)
     ) return;

  if(os || !_os)
    return; /* Already set */
  

  if((os = strdup(_os))) {
    if(strcasestr(os, "iPhone")
       || strcasestr(os, "Android")
       || strcasestr(os, "mobile"))
      mac->setDeviceType(device_phone);
    else if(strcasestr(os, "Mac OS")
	    || strcasestr(os, "Windows")
	    || strcasestr(os, "Linux"))
      mac->setDeviceType(device_workstation);
    else if(strcasestr(os, "iPad") || strcasestr(os, "tablet"))
      mac->setDeviceType(device_tablet);
  }
}

/* *************************************** */

void LocalHost::tsLua(lua_State* vm) {
  char buf_id[64], *host_id;

  stats->tsLua(vm);

  lua_push_str_table_entry(vm, "tskey", get_tskey(buf_id, sizeof(buf_id)));

  host_id = get_hostkey(buf_id, sizeof(buf_id));
  lua_pushstring(vm, host_id);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void LocalHost::freeLocalHostData() {
  /* Better not to use a virtual function as it is called in the destructor as well */
  if(os) { free(os); os = NULL; }
}

/* *************************************** */

void LocalHost::deleteHostData() {
  Host::deleteHostData();

  m.lock(__FILE__, __LINE__);
  freeLocalHostData();
  m.unlock(__FILE__, __LINE__);

  updateHostTrafficPolicy(NULL);
}

/* *************************************** */

char * LocalHost::getMacBasedSerializationKey(char *redis_key, size_t size, char *mac_key) {
  /* Serialize both IP and MAC for static hosts */
  snprintf(redis_key, size, HOST_BY_MAC_SERIALIZED_KEY,
      iface->get_id(), mac_key);

  return redis_key;
}

/* *************************************** */

char * LocalHost::getIpBasedSerializationKey(char *redis_key, size_t size) {
  char buf[CONST_MAX_LEN_REDIS_KEY];

  snprintf(redis_key, size, HOST_SERIALIZED_KEY, iface->get_id(), ip.print(buf, sizeof(buf)), vlan_id);

  return redis_key;
}
