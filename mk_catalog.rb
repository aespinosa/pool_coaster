#!/usr/bin/env ruby

require 'erb'
require 'ostruct'

swift_tc = %q[
<%=name%>  worker     <%=app_dir%>/worker.pl      INSTALLED INTEL32::LINUX GLOBUS::maxwalltime="02:00:00"
<%=name%>  sleep     /bin/sleep      INSTALLED INTEL32::LINUX GLOBUS::maxwalltime="02:00:00"
]

condor_sites = %q[
  <pool handle="<%=name%>">
    <execution provider="condor" url="none"/>

    <profile namespace="globus" key="jobType">grid</profile>
    <profile namespace="globus" key="gridResource">gt2 <%=url%>/jobmanager-<%=jm%></profile>

    <profile namespace="karajan" key="initialScore">20.0</profile>
    <profile namespace="karajan" key="jobThrottle"><%=throttle%></profile>

    <gridftp  url="gsiftp://<%=url%>"/>
    <workdirectory><%=data_dir%>/swift_scratch</workdirectory>
  </pool>
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
blacklist = [ "GridUNESP_CENTRAL" ]

# Removes duplicate site entries (i.e. multilpe GRAM endpoints)
sites = {}
ress_parse do |name, value|
  next if blacklist.index(name)
  sites[name] = value if sites[name] == nil
end

tc_out     = File.open("tc.data", "w")
condor_out = File.open("condor_osg.xml", "w")

condor_out.puts "<config>"
sites.each_key do |name|
  condor = ERB.new(condor_sites, 0, "%<>")
  tc     = ERB.new(swift_tc, 0, "%<>")

  jm       = sites[name].jm
  url      = sites[name].url
  app_dir  = sites[name].app_dir
  data_dir = sites[name].data_dir
  throttle = sites[name].throttle

  tc_out.puts     tc.result(binding)
  condor_out.puts condor.result(binding)
end
condor_out.puts "</config>"

tc_out.close
condor_out.close
