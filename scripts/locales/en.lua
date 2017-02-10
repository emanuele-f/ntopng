local  en = {
   welcome = "Welcome",
   version = "Your version is %{vers}.",
   error = "Error",
   host = "Host %{host}",
   hour = "Hour",
   day = "Day",
   week = "Week",
   month = "Month",
   time = "Time",
   sent = "Sent",
   received = "Received",
   difference = "Difference",
   total = "Total",
   today = "Today",
   actions = "Actions",
   delete = "Delete",
   undo = "Undo",
   empty = "Empty",
   clone = "Clone",
   from = "from",
   protocol = "Protocol",
   max_rate = "Max Rate",
   duration = "Duration",
   traffic = "Traffic",
   save = "Save",
   close = "Close",
   remove = "Remove",
   save_settings = "Save Settings",
   all = "All",
   define = "Define",
   traffic_policy = "Traffic Policy",

   traffic_report = {
      daily = "Daily",
      weekly = "Weekly",
      monthly = "Monthly",
      header_daily = "Daily report",
      header_weekly = "Weekly report",
      header_monthly = "Monthly report",
      current_day = "Current Day",
      current_week = "Current Week",
      current_month = "Current Month",
      previous_day = "Previous Day",
      previous_week = "Previous Week",
      previous_month = "Previous Month",
   },

   report = {
      period = "Interval",
      date = "%{month}-%{day}-%{year}"
   },

   shaping = {
      protocols = "Protocols",
      manage_policies = "Manage Policies",
      bandwidth_manager = "Bandwidth Manager",
      shaper0_message = "Shaper 0 is the default shaper used for local hosts that have no shaper defined",
      set_max_rate_to = "Set max rate to",
      for_no_shaping = "for no shaping",
      for_dropping_all_traffic = "for dropping all traffic",
      protocols_policies = "Protocols Policies",
      select_to_clone = "Select an existing network to clone the protocol rules from",
      initial_empty_protocols = "Initial protocols rules will be empty",
      initial_clone_protocols = "Initial protocol rules will be cloned",
      shaper_id = "Shaper Id",
      applied_to = "Applied to",
      notes = "NOTES",
      shapers_in_use_message = "Shapers can be deleted only if they are not applied to any network",
      no_shapers_available = "No shapers available",
      protocol_families = "Protocol Families",
      traffic_to = "Traffic to",
      traffic_from = "Traffic from",
      traffic_through = "Traffic through",
      delete_policy = "Delete Policy",
      confirm_delete_policy = "Do you really want to delete",
      policy_from_pool = "policy from pool",
      delete_shaper = "Delete Shaper",
      confirm_delete_shaper = "Do you really want to delete shaper ",
   },

   alert_messages = {
      open_files_limit_too_small = "Ntopng detected that the maximum number of files MySQL can open is potentially too small. "..
	 "This can result in flow data loss due to errors such as "..
	 "[Out of resources when opening file './ntopng/flowsv6#P#p22.MYD' (Errcode: 24 - Too many open files)][23]. "..
	 "Make sure to increase open_files_limit or, if you just want to ignore this warning, disable the check from the preferences."
   },

   show_alerts = {
      alerts = "Alerts",
      engaged_alerts = "Engaged Alerts",
      past_alerts = "Past Alerts",
      flow_alerts = "Flow Alerts",
      older_5_minutes_ago = "older than 5 minutes ago",
      older_30_minutes_ago = "older than 30 minutes ago",
      older_1_hour_ago = "older than 1 hour ago",
      older_1_day_ago = " older than 1 day ago",
      older_1_week_ago = "older than 1 week ago",
      older_1_month_ago = "older than 1 month ago",
      older_6_months_ago = "older than 6 months ago",
      older_1_year_ago = "older than 1 year ago",
      alert_actions = "Actions",
      alert_severity = "Severity",
      alert_type = "Alert Type",
      alert_datetime = "Date/Time",
      alert_duration = "Duration",
      alert_description = "Description",
      alert_counts = "Counts",
      last_minute = "Last Minute",
      last_hour = "Last Hour",
      last_day = "Last Day",
      iface_delete_config_btn = "Delete All Interface Configured Alerts",
      iface_delete_config_confirm = "Do you really want to delete all configured alerts for interface",
      network_delete_config_btn = "Delete All Network Configured Alerts",
      network_delete_config_confirm = "Do you really want to delete all configured alerts for network",
      host_delete_config_btn = "Delete All Host Configured Alerts",
      host_delete_config_confirm = "Do you really want to delete all configured alerts for host",
   },

   alerts_dashboard = {
      flow_alert_origins  = "Flow Alert Origins",
      flow_alert_targets  = "Flow Alert Targets",
      engaged_for_longest = "Engaged for Longest",
      starting_on = "starting on",
      total_alerts = "Total Alerts",
      no_alerts = "No alerts",
      not_engaged = "Not engaged",

      trailing_msg = "Time Window",
      one_min = "Last Minute",
      five_mins = "Last 5 Minutes",
      one_hour = "Last Hour",
      one_day = "Last Day",

      involving_msg = "Flow Alerts Involving",
      all_hosts = "All Hosts",
      local_only = "Local Hosts Only",
      remote_only = "Remote Hosts Only",
      local_origin_remote_target = "Local Origin - Remote Target",
      remote_origin_local_target = "Remote Origin - Local Target",

      search_criteria = "Dashboard Settings",
      submit = "Update Dashboard",

      alert_severity = "Severity",
      alert_type = "Type",
      alert_duration = "Duration",
      alert_counts = "Counts",
      custom_period = "Custom Period",
      last_minute = "Last Minute",
      last_hour = "Last Hour",
      last_day = "Last Day"
   },

   flow_alerts_explorer = {
      label = "Flow Alerts Explorer",
      flow_alert_origin  = "Alert Origin",
      flow_alert_target  = "Alert Target",

      type_explorer = "Type Explorer",
      type_alerts_by_type = "Flow Alerts By Type",
      by_target_port = "By Target Port",
      origins = "Origins",
      targets = "Targets",

      visual_explorer = "Visual Explorer",
      search = "Search Flow Alerts",

      summary_total = "Total Flow Alerts",
      summary_n_origins = "Total Origins",
      summary_n_targets = "Total Targets",
      summary_cli2srv = "Total Origin to Target Traffic",
      summary_srv2cli = "Total Target to Origin Traffic"
   },

   traffic_profiles = {
      edit_traffic_profiles = "Edit Traffic Profiles",
      traffic_filter_bpf = "Traffic Filter (BPF Format)",
      profile_name = "Profile Name",
      no_profiles = "No profiles set",
      filter_examples = "Filter Examples",
      note = "Note",
      hint_1_pre = "Hint: use",
      hint_1_after = "to print all nDPI supported protocols",
      note_0 = "Traffic profile names allow alpha-numeric characters, spaces, and underscores",
      note_1 = "Traffic profiles are applied to flows. Each flow can have up to one profile, thus in case of multiple profile matches, only the first one is selected",
      note_2 = "See ntopng -h for a list of nDPI numeric protocol number to be used with term l7proto. Only numeric protocol identifiers are accepted (no symbolic protocol names)",
      enter_profile_name = "Enter a profile name",
      enter_profile_filter = "Enter the profile filter",
      invalid_bpf = "Invalid BPF filter",
      duplicate_profile = "Duplicate profile name",
      delete_profile = "Delete Profile",
      confirm_delete_profile = "Do you really want to delete the profile",
   },

   host_pools = {
      edit_host_pools = "Edit Host Pools",
      pool = "Pool Name",
      manage_pools = "Manage Pool Membership",
      create_pools = "Manage Pools",
      empty_pool = "Empty Pool",
      delete_pool = "Delete Pool",
      remove_member = "Remove Member",
      pool_name = "Pool Name",
      no_pools_defined = "No Host Pools defined.",
      create_pool_hint = "You can create new pools from the Manage Pools tab.",
      member_address = "Member Address",
      specify_pool_name = "Specify a pool name",
      specify_member_address = "Specify an IPv4/IPv6 address or network or a MAC address",
      invalid_member = "Invalid member address format",
      duplicate_member = "Duplicate member address",
      duplicate_pool = "Duplicate pool name",
      confirm_delete_pool = "Do you really want to delete host pool",
      confirm_remove_member = "Do you really want to remove member",
      confirm_empty_pool = "Do you really want to remove all members from the host pool",
      from_pool = "from host pool",
      and_associated_members = "its RRD data and any associated members",
      search_member = "Search Member",
   },

   snmp = {
      bound_interface_description = "Binding a network interface to an SNMP interface is useful to compare network traffic monitored by ntopng with that reported by SNMP",
   },

   noTraffic = "No traffic has been reported for the specified date/time selection",
   error_rrd_low_resolution = "You are asking to fetch data at lower resolution than the one available on RRD, which will lead to invalid data."..
      "<br>If you still want data with such granularity, please tune <a href=\"%{prefs}\">Protocol/Networks Timeseries</a> preferences",
   error_no_search_results = "No results found. Please modify your search criteria.";
   enterpriseOnly = "This feature is only available in the ntopng enterprise edition",

   uploaders = "Upload Volume",
   downloaders = "Download Volume",
   unknowers =  "Unknown Traffic Volume",
   incomingflows = "Incoming Flows Count",
   outgoingflows = "Outgoing Flows Count",

   flow_search_criteria = "Flow Search Criteria",
   flow_search_results = "Flow Search Results",
   summary = "Summary",
   date_from = "Begin Date/Time:",
   date_to    = "End Date/Time:"

}

return {en = en}
