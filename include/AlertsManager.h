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

#ifndef _ALERTS_MANAGER_H_
#define _ALERTS_MANAGER_H_

#include "ntop_includes.h"

class Flow;

class AlertsManager : protected StoreManager {
 private:
  char queue_name[CONST_MAX_LEN_REDIS_KEY];
  bool store_opened, store_initialized;
  u_int32_t num_alerts_engaged;
  bool alerts_stored;
  int openStore();

  /* methods used for alerts that have a timespan */
  int isAlertExisting(AlertType alert_type, AlertLevel alert_severity, AlertEntity alert_entity, const char * const alert_entity_value, u_int32_t alert_hash, time_t when, char * const query_buf, ssize_t query_buf_len, bool * const is_existing, u_int64_t * const cur_rowid, u_int64_t * const cur_counter) const;
  int updateExistingAlert(u_int64_t rowid, u_int64_t new_counter, time_t new_timestamp_end, char * const query_buf, ssize_t query_buf_len) const;
  void markForMakeRoom(bool on_flows);

  bool notifyAlert(AlertEntity alert_entity, const char *alert_entity_value,
		   AlertType alert_type, AlertLevel alert_severity, const char *alert_json,
		   const char *alert_origin, const char *alert_target,
		   bool engage, time_t now, Flow *flow);

  /* Compute a unique hash used to group alerts together */
  static u_int32_t alertHash(const char * const alert_json);

  /* methods used to retrieve alerts and counters with possible sql clause to filter */
  int queryAlertsRaw(lua_State *vm, const char *selection, const char *clauses, const char *table_name, bool ignore_disabled);

  /* private methods to check the goodness of submitted inputs and possible return the input database string */
  bool isValidHost(Host *h, char *host_string, size_t host_string_len);
  bool isValidFlow(Flow *f);
  bool isValidNetwork(const char *cidr);
  bool isValidInterface(NetworkInterface *n);

 public:
  AlertsManager(int interface_id, const char *db_filename);
  ~AlertsManager() {};

  /*
    ========== Generic alerts API =========
   */
  int emitAlert(time_t when, AlertEngine alert_engine, AlertType alert_type,
      AlertLevel alert_severity, AlertEntity alert_entity, const char *alert_entity_value,
      const char *alert_json, const char *alert_origin=NULL, const char *alert_target=NULL,
      bool ignore_disabled=false, bool check_maximum=true);

  /*
    ========== FLOW alerts API =========
   */
  int storeFlowAlert(Flow *f);

  /*
    ========== raw API ======
  */
  inline int queryAlertsRaw(lua_State *vm, const char *selection, const char *clauses, bool ignore_disabled) {
    return queryAlertsRaw(vm, selection, clauses, ALERTS_MANAGER_TABLE_NAME, ignore_disabled);
  };
  inline int queryFlowAlertsRaw(lua_State *vm, const char *selection, const char *clauses, bool ignore_disabled) {
    return queryAlertsRaw(vm, selection, clauses, ALERTS_MANAGER_FLOWS_TABLE_NAME, ignore_disabled);
  };
};

#endif /* _ALERTS_MANAGER_H_ */
