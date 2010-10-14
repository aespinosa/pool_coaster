import("sys.k")
import("task.k")

element(removeJM, [url]
  if(matches(url, ".*/jobmanager-.*") first(split(url, "/")) url)
) 

element(pool, [handle, ..., optional(workdir), optional(appdir), channel(properties)]
  list(
    host(name = handle
      each(...)
      to(properties
        each(properties)
      )
    )
    try(appdir, "")
    try(workdir, "")
  )
)
        
element(servicelist, [type, provider, url]
  service(type, provider=provider, jobManager="fork", url=removeJM(url))
  /*list(type, provider, url, service(type, provider=provider, jobManager="fork", url=removeJM(url)))*/
)
        
element(gridftp, [url, optional(storage), optional(major), optional(minor), optional(patch)]
  if(
    url == "local://localhost" 
    servicelist("file", "local", "")
    servicelist("file", "gsiftp", url)
  )
)

element(jobmanager, [url, major, optional(universe), optional(minor), optional(patch)]
  provider := if(
    url == "local://localhost" "local"
    url == "pbs://localhost" "pbs"
    major == "4" "GT4"
    major == "2" "GT2"
    throw("Unknown job manager version: major = {major}, minor = {minor}, patch = {patch}, url = {url}")
  )
  servicelist(type="execution", provider=provider, url=url)
)
      
element(execution, [provider, url]
  servicelist(type="execution", provider=provider, url=url)
)
      
element(filesystem, [provider, url, optional(storage)]
  servicelist(type="file", provider=provider, url=url)
)
      
element(profile, [namespace, key, value]
  if(
    namespace == "karajan"
    property("{key}", value)
    property("{namespace}:{key}", value)
  )
)
        
element(workdirectory, [dir]
  workdir = dir
)

element(appdirectory, [dir]
  appdir = dir
)
    
sitesFile := "gt2_osg.xml"
sites := list(executeFile(sitesFile))

for(site, sites
  rhost   := list:first(site)
  appdir  := list:get(site, 2)
  workdir := list:last(site)

  if(not(file:exists(workdir, host=rhost, provider="gsiftp"))
    dir:make(workdir, host=rhost, provider="gsiftp")
  )
  if(not(file:exists(appdir, host=rhost, provider="gsiftp"))
    dir:make(appdir, host=rhost, provider="gsiftp")
  )

  task:transfer(srcfile="worker.pl", destfile="worker.pl", destdir=appdir, desthost=rhost, provider="gsiftp")
  torm := file:list(workdir, host=rhost, provider="gsiftp")

  print("{rhost} Removing {torm}")
  if(not(list:isEmpty(torm)) then(
    foo := list:prepend(torm, "-rf")
    task:execute("/bin/rm", arguments=torm, host=rhost, directory=workdir, provider="GT2")
    )
  )
)
