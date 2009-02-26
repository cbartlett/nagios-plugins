#!/usr/bin/env ruby

require 'ostruct'
require 'pp'

AMCLI="C:/Program Files/Dell/OpenManage/Array Manager/amcli.exe"

class String
    def methodize; downcase.gsub(/\s+/,'_').gsub('.',''); end
    def carve_into_fields; split(/\t|\s{3,}/).map { |v| v.gsub('.','') }; end
end

def volumes
    content = IO.popen("#{AMCLI} /dv").readlines.map { |v| v.strip }.reject { |v| v == "" }[3..-1]
    fields = content.shift.carve_into_fields.map { |v| v.methodize }
    content.map { |v| OpenStruct.new(Hash[ *(fields.zip(v.carve_into_fields).flatten) ]) }
end 

status = 0
msgs = []

volumes.each do |volume|
  status = 2 unless volume.state == 'READY' && volume.redundant == 'Yes' 
  msgs << "#{volume.name} [state: #{volume.state}, redundant: #{volume.redundant}]"
end

if msgs.length > 0
  puts "#{ %w/OK WARN CRIT UNKNOSN/[status] }: #{msgs.join(', ')}"
  exit(status)
else
  puts "UNKNOWN: no raid volumes found using amcli"
  exit(2)
end


    
