#!/usr/bin/env ruby

require 'mk_catalog'

class Job
  attr_accessor :grid_resource, :data_dir, :app_dir, :name, :port
  attr_reader :submit_file

  def gen_submit(count = 1)
    job = %q[
      universe = grid
      stream_output = False
      stream_error = False
      transfer_executable = False
      periodic_remove = JobStatus == 5
      periodic_hold = (JobStatus == 2) \\
                      && ((CurrentTime - EnteredCurrentStatus) > 14400)
      notification = Never

      globus_rsl = (maxwalltime=240)
      grid_resource = <%= @grid_resource %>
      executable = <%= @app_dir %>/worker.pl
      arguments = http://128.135.125.17:<%= port %> <%= name %> /tmp
      log = worker.log

      <% count.times { %>queue
      <% } %>
    ]

    ERB.new(job.gsub(/^\s+/, ""), 0, "%<>", "@submit_file").result(binding)
  end

  def submit_job(count)
    puts "Submitting #{@name} #{count} jobs"
    output = ""
    submitfile = gen_submit(count)
    IO.popen("condor_submit", "w+") do |submit|
      submit.puts submitfile
      submit.close_write
      output = submit.read
    end
    output
  end

  def queue
    jobs = `condor_q -const 'GridResource == \"#{@grid_resource}\" && JobStatus == 1' -format \"%s \" GlobalJobId`
    jobs.split(" ").size
  end
end

if __FILE__ == $0
  raise "No whitelist file" if !ARGV[0]

  start_port = 64000
  ctr        = 0
  alljobs    = 0
  threads    = []
  ARGV[1]    = "scec" if !ARGV[1]
  whitelist  = IO.readlines(ARGV[0]).map { |line| line.chomp! }

  ress_parse(ARGV[1]) do |name, value|
    next if not whitelist.index(name) and not whitelist.empty?
    site               = Job.new
    site.name          = name
    site.grid_resource = "gt2 #{value.url}/jobmanager-#{value.jm}"
    site.app_dir       = value.app_dir
    site.data_dir      = value.data_dir
    site.port          = start_port + ctr
    throttle           = (value.total * 2.5).to_i
    idle               = (value.total * 0.10).to_i

    site.gen_submit

    threads << Thread.new(name) do |job|
      total = 0
      puts "Submitting to #{name} #{throttle} jobs"
      while total < throttle do
        queued = site.queue
        if queued < idle then
          tosend = [idle - queued, throttle - total].min
          puts "Sending to #{name} #{tosend} jobs"
          site.submit_job(tosend)
          total += tosend
        end
        sleep 60
        puts "Sent to #{name}: #{total}"
        puts "Remaining in #{name}: #{throttle - total} out of #{throttle}"
      end
      puts "Finished #{name}"
    end

    ctr += 1
    alljobs += throttle
  end
  threads.each { |job| job.join }
  puts "Finished pool of #{alljobs} jobs."
end
