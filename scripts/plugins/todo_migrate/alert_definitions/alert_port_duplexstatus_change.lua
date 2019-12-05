--
-- (C) 2019 - ntop.org
--

local function snmpPortDuplexChangeFormatter(ifid, alert, info)
  if ntop.isPro() then require "snmp_utils" end

  return(i18n("alerts_dashboard.snmp_port_changed_duplex_status",
    {device = info.device,
     port = info.interface_name or info.interface,
     url = snmpDeviceUrl(info.device),
     port_url = snmpIfaceUrl(info.device, info.interface),
     new_op = snmp_duplexstatus(info.status)}))
end

-- #######################################################

return {
  alert_id = 37,
  i18n_title = "alerts_dashboard.snmp_port_duplexstatus_change",
  i18n_description = snmpPortDuplexChangeFormatter,
  icon = "fa-exclamation",
}
