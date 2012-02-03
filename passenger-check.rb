#!/usr/bin/env ruby

require 'stringio'
require 'ostruct'
require 'pp'
require 'optparse'

module Passenger
	class Instance
		attr_accessor :dir, :pid, :processes

		def initialize(info)
			lines = info.split("\n")
			@dir = lines.shift
			@processes = []
			for l in lines do
				l =~ /PID: (\d+)\s+Sessions: (\d+)/
				if $1 != nil and $2 != nil then
					@processes << { :pid => $1.to_i, :sessions => $2.to_i }
				end
			end
		end
	end

	class Status
		attr_accessor :io, :max, :count, :active, :inactive, :instances

		def initialize(io)
			@instances = []
			@io = io

			io.readline
			@max,@count,@active,@inactive = read_attribute,read_attribute,read_attribute,read_attribute
			@global_queue = read_attribute(':') == 'no' ? false : true
			@global_waiting = read_attribute(':')

			io.readline
			io.readline

			while(! io.eof?)
				@instances << Instance.new(io.readline("\n\n"))
			end
		end

		def percent_used
		  @count.to_i / @max.to_i
		end

		private 

		def read_attribute(delim = /\s+=\s+/)
			io.readline.chomp.split(delim).last
		end
	end
end

def nag_exit(code, msg)
	txtcodes = [ "OK", "WARNING", "CRITICAL", "UNKNOWN", "DEPEDENT" ]
	puts "PASSENGER #{txtcodes[code]} - #{msg}"
	exit(code)
end

def is_a_number?(s)
	s.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true 
end

def check_max_proc(status, options)
	pct = status.active.to_f / status.max.to_f
	code = 0
	if pct > options[:crit] then
		code = 2
	elsif pct > options[:warn] then
		code = 1
	end
	nag_exit(code, "Using #{status.active} of #{status.max} (#{pct}%)")
end

def check_spike(status, options)
	for i in status.instances do
		tot_ses = 0
		for p in i.processes do
			tot_ses += p[:sessions]
		end
		avg = tot_ses/(i.processes.count)
		for p in i.processes do
			if p[:sessions] > (avg * options[:crit]) then
				nag_exit(2, "PID #{p[:pid]} has #{p[:sessions]} sessions (avg is #{avg})")
			elsif p[:sessions] > (avg * options[:warn]) then
				nag_exit(1, "PID #{p[:pid]} has #{p[:sessions]} sessions (avg is #{avg})")
			end
		end
	end
	nag_exit(0, "No session spikes (avg sessions is #{avg})")
end

def check_sessions(status, options)
	for i in status.instances do
		for p in i.processes do
			if p[:sessions] > options[:crit] then
				nag_exit(2, "PID #{p[:pid]} has #{p[:sessions]} sessions")
			elsif p[:sessions] > options[:warn] then
				nag_exit(1, "PID #{p[:pid]} has #{p[:sessions]} sessions")
			end
		end
	end
	nag_exit(0, "No PID has excessive sessions")
end

options = {}
OptionParser.new do |opts|
	opts.banner = %{Usage #{__FILE__} [options]

The values for warning and critical are treated differently depending on the
check used.

For maxproc:   Warning and critical are percentages; the maximum percent of
               active processes compared to the total max processes.
For spike:     Warning and critical are percentages; the maximum percentage
               per-PID session spike allowed (as compared to the average)
For sessions:  Warning and critical are integers; the maximum number of
               sessions per PID

}

	opts.on("-?", "-h", "Help") do |o|
		nag_exit(3, "Use --help for usage")
	end

	opts.on("-C", "--check CHECK", "Which check to execute: maxproc/spike/sessions") do |o|
		if ["maxproc", "spike", "sessions"].include?(o) then
			options[:check] = o
		else
			nag_exit(3, "Unrecognized check name: use --help for usage")
		end
	end

	opts.on("-w", "--warn", "--warning WARN", "Level for warning") do |o|
		if is_a_number?(o) then
			options[:warn] = o.to_f
		else
			nag_exit(3, "Warning threshold #{o} is not numeric")
		end
	end

	opts.on("-c", "--crit", "--critical CRIT", "Level for critical") do |o|
		if is_a_number?(o) then
			options[:crit] = o.to_f
		else
			nag_exit(3, "Critical threshold #{o} is not numeric")
		end
	end
end.parse!(ARGV)

if (options[:check] == nil) or (options[:warn] == nil) or (options[:crit] == nil) then
	nag_exit(3, "Options check, warn, and crit must all be specified")
end

Dir['/tmp/passenger_status.*.fifo'].map { |f| open(f) }.each do |io|
	status = Passenger::Status.new(io)
	case options[:check]
		when "maxproc"
			check_max_proc(status, options)
		when "spike"
			check_spike(status, options)
		when "sessions"
			check_sessions(status, options)
	end
end