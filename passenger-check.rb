#!/usr/bin/env ruby

require 'stringio'
require 'ostruct'
require 'pp'

module Passenger
	class Instance
		attr_accessor :dir, :pid, :processes
		
		def initialize(info)
			lines = info.split("\n")
			@dir = lines.shift
			@processes = lines.map { |l| 
				l =~ /^\s+PID: (\d+)\s+Sessions: (\d+)$/
				OpenStruct.new(:pid => $1, :sessions => $2)
			}
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
		  @active / @max
		end
		
		private 
		
		def read_attribute(delim = /\s+=\s+/)
			io.readline.chomp.split(delim).last
		end
	end
end

Dir['/tmp/passenger_status.*.fifo'].map { |f| open(f) }.each do |io|
	status = Passenger::Status.new(io)
	puts "Using #{status.active} of #{status.max} (#{status.percent_used}%)"
end
