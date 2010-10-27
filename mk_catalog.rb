#!/usr/bin/env ruby

require 'erb'
require 'ostruct'

# starting ports for the templates
coaster_service = 62000
worker_service  = 61000

swift_workflow = %q[
<% ctr = 0
   sites.each_key do |name|
     jm       = sites[name].jm
     url      = sites[name].url
     app_dir  = sites[name].app_dir
     data_dir = sites[name].data_dir
     throttle = sites[name].throttle %>
app (external o) worker<%= ctr %>() {
  worker<%= ctr %> "http://128.135.125.17:<%= worker_service + ctr %>" "<%= name %>" "/tmp" "7200";
}

external rups<%= ctr %>[];
int arr<%= ctr %>[];
iterate i{
  arr<%= ctr %>[i] = i;
} until (i == <%= ((throttle * 100 + 2) * 1.2).to_i %>);

foreach a,i in arr<%= ctr %> {
  rups<%= ctr %>[i] = worker<%= ctr %>();
}

<%   ctr += 1
   end %>
]

slave_workflow = %q[
int t = 300;

app (external o) sleep_pads(int time) {
  sleep_pads time;
}
external o_pads;
o_pads = sleep_pads(t);

<% ctr = 0
   sites.each_key do |name|
     jm       = sites[name].jm
     url      = sites[name].url
     app_dir  = sites[name].app_dir
     data_dir = sites[name].data_dir
     throttle = sites[name].throttle %>
app (external o) sleep<%= ctr %>(int time) {
  sleep<%= ctr %> time;
}

external o<%=ctr%>;
o<%=ctr%> = sleep<%=ctr%>(t);

<%   ctr += 1
   end %>

]

swift_tc = %q[
PADS  sleep_pads     /bin/sleep      INSTALLED INTEL32::LINUX GLOBUS::maxwalltime="00:05:00"
<% ctr = 0
   sites.each_key do |name|
     jm       = sites[name].jm
     url      = sites[name].url
     app_dir  = sites[name].app_dir
     data_dir = sites[name].data_dir
     throttle = sites[name].throttle %>
<%=name%>  worker<%= ctr %>    <%=app_dir%>/worker.pl      INSTALLED INTEL32::LINUX GLOBUS::maxwalltime="02:00:00"
<%=name%>  sleep<%= ctr %>     /bin/sleep      INSTALLED INTEL32::LINUX GLOBUS::maxwalltime="00:05:00"
<%=name%>  sleep     /bin/sleep      INSTALLED INTEL32::LINUX GLOBUS::maxwalltime="00:05:00"
<%   ctr += 1
   end %>
]

condor_sites = %q[
<config>
<% sites.each_key do |name| %>
<%   jm       = sites[name].jm
     url      = sites[name].url
     app_dir  = sites[name].app_dir
     data_dir = sites[name].data_dir
     throttle = sites[name].throttle %>

  <pool handle="<%=name%>">
    <execution provider="condor" url="none"/>

    <profile namespace="globus" key="jobType">grid</profile>
    <profile namespace="globus" key="gridResource">gt2 <%=url%>/jobmanager-<%=jm%></profile>

    <profile namespace="karajan" key="initialScore">20.0</profile>
    <profile namespace="karajan" key="jobThrottle"><%=throttle%></profile>

    <gridftp  url="gsiftp://<%=url%>"/>
    <workdirectory><%=data_dir%>/swift_scratch</workdirectory>
  </pool>
<% end %>
</config>
]

# GT2 for installing the workers
gt2_sites = %q[
<config>
<% sites.each_key do |name| %>
<%   jm       = sites[name].jm
     url      = sites[name].url
     app_dir  = sites[name].app_dir
     data_dir = sites[name].data_dir
     throttle = sites[name].throttle %>

  <pool handle="<%=name%>">
    <jobmanager universe="vanilla" url="<%=url%>/jobmanager-fork" major="2" />

    <gridftp  url="gsiftp://<%=url%>"/>
    <workdirectory><%= data_dir %>/swift_scratch</workdirectory>
    <appdirectory><%= app_dir %></appdirectory>
  </pool>
<% end %>
</config>
]
    #<workdirectory><%=data_dir%>/swift_scratch</workdirectory>

coaster_sites = %q[
<config>
  <pool handle="PADS">
    <execution provider="coaster-persistent" url="https://communicado.ci.uchicago.edu:<%= coaster_service - 1 %>"
        jobmanager="local:local" />

    <profile namespace="globus" key="workerManager">passive</profile>

    <profile namespace="karajan" key="initialScore">10000.0</profile>
    <profile namespace="karajan" key="jobThrottle">3.66</profile>

    <profile namespace="globus" key="lowOverallocation">36</profile>

    <gridftp  url="local://localhost"/>
    <workdirectory>/gpfs/pads/swift/aespinosa/swift-runs</workdirectory>
  </pool>
<% ctr = 0
   sites.each_key do |name|
     jm       = sites[name].jm
     url      = sites[name].url
     app_dir  = sites[name].app_dir
     data_dir = sites[name].data_dir
     throttle = sites[name].throttle %>

  <pool handle="<%=name%>">
    <execution provider="coaster-persistent" url="https://communicado.ci.uchicago.edu:<%= coaster_service + ctr %>"
        jobmanager="local:local" />

    <profile namespace="globus" key="workerManager">passive</profile>

    <profile namespace="karajan" key="initialScore">20.0</profile>
    <profile namespace="karajan" key="jobThrottle"><%=throttle%></profile>

    <profile namespace="globus" key="lowOverallocation">36</profile>

    <gridftp  url="gsiftp://<%=url%>"/>
    <workdirectory><%=data_dir%>/swift_scratch</workdirectory>
  </pool>
<%   ctr += 1
   end %>
</config>
]

def ress_query(class_ads)
  cmd = "condor_status -pool engage-submit.renci.org"
  class_ads[0..-2].each do |class_ad|
    cmd << " -format \"%s|\" #{class_ad}"
  end
  cmd << " -format \"%s\\n\" #{class_ads[-1]}"
  `#{cmd}`
end

def ress_parse
  dir_suffix = "/engage-scec"
  class_ads  = [
    "GlueSiteUniqueID", "GlueCEInfoHostName", "GlueCEInfoJobManager",
    "GlueCEInfoGatekeeperPort", "GlueCEInfoApplicationDir", "GlueCEInfoDataDir",
    "GlueCEInfoTotalCPUs"
  ]
  ress_query(class_ads).each_line do |line|
    line.chomp!
    set = line.split("|")

    value = OpenStruct.new

    value.app_dir = set[class_ads.index("GlueCEInfoApplicationDir")]
    value.app_dir.sub!(/\/$/, "")
    value.app_dir += dir_suffix

    value.data_dir = set[class_ads.index("GlueCEInfoDataDir")]
    value.data_dir.sub!(/\/$/, "")
    value.data_dir += dir_suffix

    name           = set[class_ads.index("GlueSiteUniqueID")]
    value.jm       = set[class_ads.index("GlueCEInfoJobManager")]
    value.url      = set[class_ads.index("GlueCEInfoHostName")]
    value.throttle = (set[class_ads.index("GlueCEInfoTotalCPUs")].to_f - 2.0) / 100.0

    yield name, value
  end
end

# Blacklist of non-working sites
blacklist = []
#whitelist = ["UCHC_CBG"]
whitelist = IO.readlines(ARGV[0]).map { |line| line.chomp }

# Removes duplicate site entries (i.e. multilpe GRAM endpoints)
sites = {}
ress_parse do |name, value|
  next if blacklist.index(name) and not blacklist.empty?
  next if not whitelist.index(name) and not whitelist.empty?
  sites[name] = value if sites[name] == nil
end

condor_out = File.open("condor_osg.xml", "w")
gt2_out = File.open("gt2_osg.xml", "w")
coaster_out = File.open("coaster_osg.xml", "w")

tc_out     = File.open("tc.data", "w")
workflow_out = File.open("worker.swift", "w")
slave_out = File.open("slave.swift", "w")

condor = ERB.new(condor_sites, 0, "%<>")
gt2 = ERB.new(gt2_sites, 0, "%<>")
coaster = ERB.new(coaster_sites, 0, "%<>")

tc     = ERB.new(swift_tc, 0, "%<>")
workflow = ERB.new(swift_workflow, 0, "%<>")
slave = ERB.new(slave_workflow, 0, "%<>")

condor_out.puts condor.result(binding)
gt2_out.puts gt2.result(binding)
coaster_out.puts coaster.result(binding)

tc_out.puts tc.result(binding)
workflow_out.puts workflow.result(binding)
slave_out.puts slave.result(binding)

condor_out.close
gt2_out.close
coaster_out.close

tc_out.close
workflow_out.close
slave_out.close
