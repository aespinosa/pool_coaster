#!/usr/bin/env ruby

require 'erb'
require 'ostruct'

swift_tc = %q[
<% sites.each_key do |name| %>
<%   jm       = sites[name].jm
     url      = sites[name].url
     app_dir  = sites[name].app_dir
     data_dir = sites[name].data_dir
     throttle = sites[name].throttle %>
<%=name%>  worker     <%=app_dir%>/worker.pl      INSTALLED INTEL32::LINUX GLOBUS::maxwalltime="02:00:00"
<%=name%>  sleep     /bin/sleep      INSTALLED INTEL32::LINUX GLOBUS::maxwalltime="00:00:05"
<% end %>
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
    <workdirectory><%=app_dir%></workdirectory>
  </pool>
<% end %>
</config>
]

coaster_sites = %q[
<config>
<% sites.each_key do |name| %>
<%   jm       = sites[name].jm
     url      = sites[name].url
     app_dir  = sites[name].app_dir
     data_dir = sites[name].data_dir
     throttle = sites[name].throttle %>

  <pool handle="<%=name%>">
    <execution provider="coaster" url="communicado.ci.uchicago.edu"
        jobmanager="local:local" />

    <profile namespace="globus" key="workerManager">passive</profile>

    <profile namespace="karajan" key="initialScore">20.0</profile>
    <profile namespace="karajan" key="jobThrottle"><%=throttle%></profile>

    <profile namespace="globus" key="lowOverallocation">36</profile>

    <gridftp  url="gsiftp://<%=url%>"/>
    <workdirectory><%=data_dir%>/swift_scratch</workdirectory>
  </pool>
<% end %>
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
blacklist = [ "GridUNESP_CENTRAL", "RENCI-Blueridge", "RENCI-Engagement" ]
#blacklist = [ "FNAL_FERMIGRID",
  #"Firefly", "GLOW", "GridUNESP_CENTRAL", "LIGO_UWM_NEMO",
  #"MIT_CMS", "MIT_CMS", "NWICG_NotreDame", "NYSGRID_CORNELL_NYS1", "Nebraska",
  #"Nebraska", "Prairiefire", "Purdue-RCAC", "RENCI-Blueridge", "RENCI-Engagement",
  #"SBGrid-Harvard-East", "SMU_PHY", "SPRACE", "SWT2_CPB", "UCHC_CBG", "UCR-HEP",
  #"UCSDT2", "UCSDT2", "UConn-OSG", "UFlorida-HPC", "UFlorida-PG", "UJ-OSG",
  #"UMissHEP", "USCMS-FNAL-WC1", "UTA_SWT2", "WQCG-Harvard-OSG"
#]

# Removes duplicate site entries (i.e. multilpe GRAM endpoints)
sites = {}
ress_parse do |name, value|
  next if blacklist.index(name)
  sites[name] = value if sites[name] == nil
end

condor_out = File.open("condor_osg.xml", "w")
gt2_out = File.open("gt2_osg.xml", "w")
coaster_out = File.open("coaster_osg.xml", "w")

tc_out     = File.open("tc.data", "w")

condor = ERB.new(condor_sites, 0, "%<>")
gt2 = ERB.new(gt2_sites, 0, "%<>")
coaster = ERB.new(coaster_sites, 0, "%<>")

tc     = ERB.new(swift_tc, 0, "%<>")

condor_out.puts condor.result(binding)
gt2_out.puts gt2.result(binding)
coaster_out.puts coaster.result(binding)

tc_out.puts tc.result(binding)

condor_out.close
gt2_out.close
coaster_out.close

tc_out.close
