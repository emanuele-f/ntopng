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

#ifndef _HOST_H_
#define _HOST_H_

#include "ntop_includes.h"

class Host : public GenericHashEntry {
 protected:
  IpAddress ip;
  Mac *mac;
  char *asname;
  bool stats_reset_requested, data_delete_requested;
  u_int16_t vlan_id, host_pool_id;
  HostStats *stats, *stats_shadow;
  time_t last_stats_reset;

  /* Host data: update Host::deleteHostData when adding new fields */
  char *symbolic_name; /* write protected by mutex */
  char *info, *info_shadow;
  char *ssdpLocation, *ssdpLocation_shadow;
  bool host_label_set;
  /* END Host data: */

  u_int32_t num_alerts_detected;
  AlertCounter *syn_flood_attacker_alert, *syn_flood_victim_alert;
  AlertCounter *flow_flood_attacker_alert, *flow_flood_victim_alert;
  bool trigger_host_alerts;

  u_int32_t num_active_flows_as_client, num_active_flows_as_server;
  u_int32_t low_goodput_client_flows, low_goodput_server_flows;

  u_int32_t asn;
  AutonomousSystem *as;
  Country *country;
  Vlan *vlan;
  bool blacklisted_host;

  Mutex *m;
  u_int32_t mac_last_seen;
  u_int8_t num_resolve_attempts;
  time_t nextResolveAttempt;

  bool good_low_flow_detected;
  FlowAlertCounter *flow_alert_counter;
#ifdef NTOPNG_PRO
  TrafficShaper **host_traffic_shapers;
  bool has_blocking_quota, has_blocking_shaper;
#endif
  bool hidden_from_top;

  void initialize(Mac *_mac, u_int16_t _vlan_id, bool init_all);
  bool statsResetRequested();
  void checkStatsReset();
  virtual bool readDHCPCache() { return false; };
#ifdef NTOPNG_PRO
  TrafficShaper *get_shaper(ndpi_protocol ndpiProtocol, bool isIngress);
  void get_quota(u_int16_t protocol, u_int64_t *bytes_quota, u_int32_t *secs_quota, u_int32_t *schedule_bitmap, bool *is_category);
#endif

  char* printMask(char *str, u_int str_len) { return ip.printMask(str, str_len, isLocalHost()); };
  virtual void deleteHostData();
 public:
  Host(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId);
  Host(NetworkInterface *_iface, Mac *_mac, u_int16_t _vlanId, IpAddress *_ip);

  virtual ~Host();

  virtual bool isLocalHost()  = 0;
  virtual bool isSystemHost() = 0;
  inline void setSystemHost()               { /* TODO: remove */ };

  inline nDPIStats* get_ndpi_stats()       { return(stats->getnDPIStats()); };

  virtual void set_to_purge() { /* Saves 1 extra-step of purge idle */
    iface->decNumHosts(isLocalHost());
    GenericHashEntry::set_to_purge();
  };

  inline bool isChildSafe() {
#ifdef NTOPNG_PRO
    return(iface->getHostPools()->isChildrenSafePool(host_pool_id));
#else
    return(false);
#endif
  };

  inline bool forgeGlobalDns() {
#ifdef NTOPNG_PRO
    return(iface->getHostPools()->forgeGlobalDns(host_pool_id));
#else
    return(false);
#endif
  };

  virtual HostStats* allocateStats()                { return(new HostStats(this)); };
  void updateStats(struct timeval *tv);
  void incLowGoodputFlows(bool asClient);
  void decLowGoodputFlows(bool asClient);
  inline u_int16_t get_host_pool()         { return(host_pool_id);   };
  inline u_int16_t get_vlan_id()           { return(vlan_id);        };

  inline void incRetransmittedPkts(u_int32_t num)   { stats->incRetransmittedPkts(num);      };
  inline void incOOOPkts(u_int32_t num)             { stats->incOOOPkts(num);                };
  inline void incLostPkts(u_int32_t num)            { stats->incLostPkts(num);               };
  inline void incKeepAlivePkts(u_int32_t num)       { stats->incKeepAlivePkts(num);          };
  inline void incSentStats(u_int pkt_len)           { stats->incSentStats(pkt_len);          };
  inline void incRecvStats(u_int pkt_len)           { stats->incRecvStats(pkt_len);          };
  
  virtual int16_t get_local_network_id() = 0;
  virtual HTTPstats* getHTTPstats()                  { return(NULL);                 };
  inline void set_ipv4(u_int32_t _ipv4)             { ip.set(_ipv4);                 };
  inline void set_ipv6(struct ndpi_in6_addr *_ipv6) { ip.set(_ipv6);                 };
  inline u_int32_t key()                            { return(ip.key());              };
  char* getJSON();
  virtual void setOS(char *_os, bool ignoreIfPresent=true) {};
  inline IpAddress* get_ip()                   { return(&ip);              }
  void set_mac(Mac  *m);
  void set_mac(char *m);
  void set_mac(u_int8_t *m);
  inline bool isBlacklisted()                  { return(blacklisted_host);  };
  void reloadHostBlacklist();
  inline u_int8_t*  get_mac()                  { return(mac ? mac->get_mac() : NULL);      }
  inline Mac* getMac()                         { return(mac);              }
  virtual char* get_os()                       { return((char*)"");        }
  inline char* get_name()                      { return(symbolic_name);    }
#ifdef NTOPNG_PRO
  inline TrafficShaper *get_ingress_shaper(ndpi_protocol ndpiProtocol) { return(get_shaper(ndpiProtocol, true)); }
  inline TrafficShaper *get_egress_shaper(ndpi_protocol ndpiProtocol)  { return(get_shaper(ndpiProtocol, false)); }
  inline void resetQuotaStats()                                        { stats->resetQuotaStats(); }
  bool checkQuota(ndpi_protocol ndpiProtocol, L7PolicySource_t *quota_source, const struct tm *now);
  inline bool hasBlockedTraffic() { return has_blocking_quota || has_blocking_shaper; };
  inline void resetBlockedTrafficStatus(){ has_blocking_quota = has_blocking_shaper = false; };
  void luaUsedQuotas(lua_State* vm);

  inline void incQuotaEnforcementStats(u_int32_t when, u_int16_t ndpi_proto,
				       u_int64_t sent_packets, u_int64_t sent_bytes,
				       u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
    stats->incQuotaEnforcementStats(when, ndpi_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
  }

  inline void incQuotaEnforcementCategoryStats(u_int32_t when,
				       ndpi_protocol_category_t category_id,
				       u_int64_t sent_bytes, u_int64_t rcvd_bytes) {
    stats->incQuotaEnforcementCategoryStats(when, category_id, sent_bytes, rcvd_bytes);
  }
#endif

  inline u_int64_t getNumBytesSent()           { return(stats->getNumBytesSent());   }
  inline u_int64_t getNumBytesRcvd()           { return(stats->getNumBytesRcvd());   }
  inline u_int64_t getNumDroppedFlows()        { return(stats->getNumDroppedFlows());}
  inline u_int64_t getNumBytes()               { return(stats->getNumBytes());}
  inline bool checkpoint(lua_State* vm, NetworkInterface *iface,
					      u_int8_t checkpoint_id,
					      DetailsLevel details_level)    { return(stats->checkpoint(vm, iface, checkpoint_id, details_level)); }
  inline float getThptTrendDiff()              { return(stats->getThptTrendDiff());  }
  inline float getBytesThpt()                  { return(stats->getBytesThpt());      }
  inline float getPacketsThpt()                { return(stats->getPacketsThpt());    }
  inline void incNumDroppedFlows()             { stats->incNumDroppedFlows();        }

  inline u_int32_t get_asn()                   { return(asn);              }
  inline char*     get_asname()                { return(asname);           }
  inline AutonomousSystem* get_as()            { return(as);               }
  inline bool isPrivateHost()                  { return(ip.isPrivateAddress()); }
  bool isLocalInterfaceAddress();
  char* get_name(char *buf, u_int buf_len, bool force_resolution_if_not_found);
  char* get_visual_name(char *buf, u_int buf_len, bool from_info=false);
  inline char* get_string_key(char *buf, u_int buf_len) { return(ip.print(buf, buf_len)); };
  char* get_hostkey(char *buf, u_int buf_len, bool force_vlan=false);
  bool idle();
  virtual void incICMP(u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer) {};
  virtual void lua(lua_State* vm, AddressTree * ptree, bool host_details,
	   bool verbose, bool returnHost, bool asListElement);
  void resolveHostName();
  void setName(char *name);
  void set_host_label(char *label_name, bool ignoreIfPresent);
  inline bool is_label_set() { return(host_label_set); };
  inline int compare(Host *h) { return(ip.compare(&h->ip)); };
  inline bool equal(IpAddress *_ip)  { return(_ip && ip.equal(_ip)); };
  void incStats(u_int32_t when, u_int8_t l4_proto, u_int ndpi_proto,
		custom_app_t custom_app,
		u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes);
  void incHitter(Host *peer, u_int64_t sent_bytes, u_int64_t rcvd_bytes);
  virtual void updateHostTrafficPolicy(char *key) {};
  virtual json_object* getJSONObject(DetailsLevel details_level);
  char* serialize();
  virtual void  serialize2redis() {};
  bool addIfMatching(lua_State* vm, AddressTree * ptree, char *key);
  bool addIfMatching(lua_State* vm, u_int8_t *mac);
  void updateSynFlags(time_t when, u_int8_t flags, Flow *f, bool syn_sent);
  inline void updateRoundTripTime(u_int32_t rtt_msecs) {
    if(as) as->updateRoundTripTime(rtt_msecs);
  }

  void incNumFlows(bool as_client, Host *peer);
  void decNumFlows(bool as_client, Host *peer);

  inline void incFlagStats(bool as_client, u_int8_t flags)  { stats->incFlagStats(as_client, flags); };
  virtual void incNumDNSQueriesSent(u_int16_t query_type) { };
  virtual void incNumDNSQueriesRcvd(u_int16_t query_type) { };
  virtual void incNumDNSResponsesSent(u_int32_t ret_code) { };
  virtual void incNumDNSResponsesRcvd(u_int32_t ret_code) { };
  virtual void postHashAdd();

  virtual NetworkStats* getNetworkStats(int16_t networkId) { return(NULL);   };
  inline Country* getCountryStats()                        { return country; };

  bool match(AddressTree *tree) { return(get_ip() ? get_ip()->match(tree) : false); };
  void updateHostPool(bool isInlineCall, bool firstUpdate=false);
  virtual bool dropAllTraffic()  { return(false); };
  bool incFlowAlertHits(time_t when);
  virtual bool setRemoteToRemoteAlerts() { return(false); };
  inline void checkPointHostTalker(lua_State *vm, bool saveCheckpoint) { stats->checkPointHostTalker(vm, saveCheckpoint); }
  inline void setInfo(char *s) {
    if(info_shadow) free(info_shadow);
    info_shadow = info;
    info = s ? strdup(s) : NULL;
  }
  inline char* getInfo(char *buf, uint buf_len) { return get_visual_name(buf, buf_len, true); }
  virtual void incrVisitedWebSite(char *hostname) {};
  virtual u_int32_t getActiveHTTPHosts()  { return(0); };
  inline u_int32_t getNumOutgoingFlows()  { return(num_active_flows_as_client); }
  inline u_int32_t getNumIncomingFlows()  { return(num_active_flows_as_server); }
  inline u_int32_t getNumActiveFlows()    { return(getNumOutgoingFlows()+getNumIncomingFlows()); }
  void splitHostVlan(const char *at_sign_str, char *buf, int bufsize, u_int16_t *vlan_id);
  void setMDSNInfo(char *str);
  char* get_country(char *buf, u_int buf_len);
  char* get_city(char *buf, u_int buf_len);
  void get_geocoordinates(float *latitude, float *longitude);
  inline u_int16_t getVlanId() { return (vlan ? vlan->get_vlan_id() : 0); }
  inline void reloadHideFromTop() { hidden_from_top = iface->isHiddenFromTop(this); }
  inline bool isHiddenFromTop() { return hidden_from_top; }
  inline bool isOneWayTraffic() { return !(stats->getRecvBytes() > 0 && stats->getSentBytes() > 0); };
  virtual void tsLua(lua_State* vm) { lua_pushnil(vm); };
  DeviceProtoStatus getDeviceAllowedProtocolStatus(ndpi_protocol proto, bool as_client);

  inline void requestStatsReset()                        { stats_reset_requested = true; };
  inline void requestDataReset()                         { data_delete_requested = true; requestStatsReset(); };
  void checkDataReset();
  bool hasAnomalies();
  void luaAnomalies(lua_State* vm);
  void loadAlertsCounter();
  bool triggerAlerts()                                   { return(trigger_host_alerts); };
  void refreshHostAlertPrefs();
  u_int32_t getNumAlerts(bool from_alertsmanager = false);
  void setNumAlerts(u_int32_t num)                       { num_alerts_detected = num; };

  inline void setSSDPLocation(char *url) {
    if(ssdpLocation_shadow) free(ssdpLocation_shadow);
    ssdpLocation_shadow = ssdpLocation;
    ssdpLocation = url ? strdup(url) : NULL;
  }
};

#endif /* _HOST_H_ */
