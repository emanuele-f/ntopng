--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local remote_assistance = require("remote_assistance")

if((not isAdministrator()) or (not remote_assistance.isAvailable())) then
  return
end

if not table.empty(_POST) then
  local enabled = (_POST["toggle_remote_assistance"] == "1")
  ntop.setPref("ntopng.prefs.remote_assistance.enabled", ternary(enabled, "1", "0"))

  if enabled then
    local create_user = (_POST["create_temporary_user"] == "1")
    local community = _POST["n2n_community"]
    local key = _POST["n2n_key"]

    ntop.setPref("ntopng.prefs.remote_assistance.community", community)
    ntop.setPref("ntopng.prefs.remote_assistance.key", key)
    remote_assistance.createConfig(community, key)
    remote_assistance.enableAndStart()
  else
    remote_assistance.disableAndStop()
  end
end

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print("<hr>")
print("<h2>") print(i18n("remote_assistance.remote_assistance")) print("</h2>")
print("<br>")

local assistace_checked = ""

if remote_assistance.isEnabled() then
  assistace_checked = "checked"
end

print [[
  <form id="remote_assistance_form" class="form-inline" method="post">
    <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />

    <div id="assistance-config" class="tab-pane in active">
      <table class="table table-striped table-bordered">
        <tr>
          <th width=20%>]] print(i18n("remote_assistance.enable_remote_assistance")) print [[</th>
          <td>
            <input id="toggle_remote_assistance" name="toggle_remote_assistance" type="checkbox" value="1" ]] print(assistace_checked) print [[/>
          </td>
        </tr>
        <tr>
          <th>Status</th>
          <td>]] print(remote_assistance.statusLabel()) print[[</td>
        </tr>
        <!-- TODO
        <th>Create Temporary User</th>
          <td>
            <input name="create_temporary_user" type="checkbox" value="1" ]] print(assistace_checked) print [[/><br>
            <small>If enabled, a termporary user with admin rights will be created as long as the Remote Assistance is running.</small>
          </td>
        -->
        <tr>
          <th>Community</th>
          <td><input id="n2n-community" class="form-control" name="n2n_community" value="]] print(ntop.getPref("ntopng.prefs.remote_assistance.community")) print[[" readonly /><br>
          <small>The community defines a virtual network for this device.</small>
          </td>
        </tr>
        <tr>
          <th>Key</th>
          <td><input id="n2n-key" class="form-control" name="n2n_key" value="]] print(ntop.getPref("ntopng.prefs.remote_assistance.key")) print[[" readonly /><br>
          <small>The secret key is used to access the above community.</small>
          </td>
        </tr>
      </table>
    </div>

    <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button>
  </form>
  <br>

  <span>]]
print(i18n("notes"))
print[[
  <ul>
      <li>]] print("The information above is sensitive. Only provide it to the ntopng support team.") print[[</li>
      <li>]] print("Remember to disable the remote assistance when not needed.") print[[</li>
      <li>]] print("When enabled, the remote assistance will create an encrypted virtual network to connect remotely to your device. Ask the network administrator permission before doing this.") print[[</li>]]
   print[[
    </ul>
  </span>

  <script>
    aysHandleForm("#remote_assistance_form");

    function generate_credentials() {
      var today = Math.floor($.now() / 1000 / 86400); // days since first epoch

      $("#n2n-community").val(today + genRandomString(10));   // 15 chars
      $("#n2n-key").val(genRandomString(20));                 // 20 chars
    }

    $("#toggle_remote_assistance").change(function() {
      var is_enabled = $("#toggle_remote_assistance").is(":checked");

      if(is_enabled)
        generate_credentials();
    });
  </script>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
