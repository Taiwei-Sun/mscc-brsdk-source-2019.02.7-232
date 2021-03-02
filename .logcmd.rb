#!/usr/bin/env ruby

require 'pp'
require 'open3'
require 'optparse'

$log = nil

def ts t
    t.strftime("%T")
end

BLOCK_SIZE = 1024
def process_lines data
    while true
        head, sep, tail = data.partition("\n")
        if sep == "\n"
            if $run_line
                log_or_console $run_line
                $run_line = nil
            end

            yield head
            data = tail
        else
            return data
        end
    end
end

def console line
    f = nil
    begin
        n = File.expand_path(__FILE__) + ".lock"
        f = File.open(n, File::CREAT)
        f.flock(File::LOCK_EX)
        puts line
        f.flock(File::LOCK_UN)
    rescue
    ensure
        if f
            f.close
        end
    end
end

def log line
    begin
        $log.flock(File::LOCK_EX)
        $log.puts line
    rescue
    ensure
        $log.flock(File::LOCK_UN)
    end
end

def log_or_console line
    if $log
        return log(line)
    end

    console line
end

def log_and_console line
    log(line) if $log
    console(line)
end

$msg = ""
$dir = nil
OptionParser.new do |opt|
    opt.banner = """Usage: logcmd.rb [options] -- cmd
    """
    opt.on('--log=file', "Log file") do |n|
        $log = File.open(n, "a")
    end

    #opt.on('--stdout-silent', "Do not print anything on stdout") { |o| }
    opt.on('--trace', "This is not a command to be run, but a trace statement for the log") do
        $trace = true
    end

    opt.on('--line-prepend=msg', "Prepen msg to each line") do |msg|
        $msg = "#{msg} "
    end

    opt.on('--simplegrid=dir', "Folder from which to read ip of blade server") do |dir|
        system "mkdir #{dir}"
        $dir = "#{dir}"
    end
end.parse!

cmd = ARGV.join(" ")

if $trace
    log_and_console "#{ts(Time.now)}-%05d-TRACE:  #{cmd}" % [Process.ppid]
    exit 0
end

ts_start = Time.now

$buf_out = ""
$buf_err = ""
$spid = ""

s = ""
Open3.popen3("sh -c \"#{cmd}\"") do |stdin, _o, _e, wait_thr|
    stdin.close
    $spid = "%05d" % [wait_thr[:pid]]
    $run_line = "#{ts(Time.now)}-#{$spid}-RUN:     #{$msg}#{cmd}"

    fds_ = [_o, _e]

    s += " "
    begin
        while not fds_.empty?
            fds = IO.select([_o, _e])

            begin
                s = IO.read("#{$dir}/sg-offer.stamp") if $dir
            rescue
            end

            if fds[0].include? _o
                begin
                    $buf_out << _o.read_nonblock(BLOCK_SIZE)
                    $buf_out = process_lines($buf_out) do |l|
                        if $dir
                            log_or_console "#{ts(Time.now)}-#{$spid}-STDOUT:  #{$msg}@#{s} #{l}"
                        else
                            log_or_console "#{ts(Time.now)}-#{$spid}-STDOUT:  #{$msg}#{l}"
                        end
                    end
                rescue EOFError
                    fds_.delete_if {|s| s == _o}
                end
            end

            if fds[0].include? _e
                begin
                    $buf_err << _e.read_nonblock(BLOCK_SIZE)
                    $buf_err = process_lines($buf_err) do |l|
                        if $dir
                            log_or_console "#{ts(Time.now)}-#{$spid}-STDERR:  #{$msg}@#{s} #{l}"
                        else
                            log_or_console "#{ts(Time.now)}-#{$spid}-STDERR:  #{$msg}#{l}"
                        end
                    end
                rescue EOFError
                    fds_.delete_if {|s| s == _e}
                end
            end
        end
    rescue IOError => e
        puts "IOError: #{e}"
    end

    $exit_status = wait_thr.value.exitstatus
end

if $run_line
    log_or_console "#{ts(Time.now)}-#{$spid}-CMD:     #{$msg}\"#{cmd}\" return val: #{$exit_status} took #{Time.now.sec - ts_start.sec} seconds (#{cmd})"
else
    log_or_console "#{ts(Time.now)}-#{$spid}-DONE:    #{$msg}return val: #{$exit_status} took #{Time.now.sec - ts_start.sec} seconds (#{cmd})"
end

if $log
    took = (Time.now - ts_start).to_i
    stook = ""
    if took > 59940 # more than 999 minutes
        stook = "%03dh" % [took / 3600]
    elsif took > 999
        stook = "%03dm" % [took / 60]
    else
        stook = "%03ds" % [took]
    end

    if $exit_status == 0
        if $dir
            console "#{ts(Time.now)}-#{stook}-OK:       #{$msg}@#{s} #{cmd}"
        else
            console "#{ts(Time.now)}-#{stook}-OK:       #{$msg} #{cmd}"
        end
    else
        if $dir
            console "#{ts(Time.now)}-#{stook}-ERR(%3d): #{$msg}@#{s} #{cmd}" % [ $exit_status ]
        else
            console "#{ts(Time.now)}-#{stook}-ERR(%3d): #{$msg} #{cmd}" % [ $exit_status ]
        end
    end

    $log.close
end

exit $exit_status
