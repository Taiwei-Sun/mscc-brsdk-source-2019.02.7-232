#!/usr/bin/env ruby

require 'csv'
require 'json'
require "base64"
require 'optparse' # For command line parsing

globalOptions = {}
global = OptionParser.new do |opts|
  opts.banner = "Usage: licensedata.rb --legal-info <dir>"

  opts.on("-l", "--legal-info <dir>", "Buildroot legal-info directory") do |dir|
    if !File.directory?(dir)
      puts "#{dir}: Must be a directory"
      exit 1
    end
    globalOptions[:dir] = dir
  end

  opts.on("-k", "--kernel <version>", "Kernel version comming from config.yaml") do |kernel|
    globalOptions[:kernel] = kernel
  end

  opts.on("-u", "--uboot <version>", "Uboot version comming from config.yaml") do |uboot|
    globalOptions[:uboot] = uboot
  end

end.order!

modules = CSV.parse(File.read(globalOptions[:dir] + "/manifest.csv"))

records = []

modules.each do |m|

  if m[0] != "PACKAGE"
    e = {}
    e['name'] = m[0]
    e['version'] = m[1]
    e['license_type'] = m[2]
    e['licenses'] = []
    m[3].split(" ").each do |f|
      c = {}
      c['name'] = f
      c['license_text'] = Base64.encode64(File.read(globalOptions[:dir] + "/licenses/" + m[0] + "-" + m[1] + "/" + f))
      e['licenses'].push(c)
    end
    if m[5] != "no upstream"
      e['url'] = m[5] + "/" + m[4]
    end
    if m[1] == "custom" && m[0] == "linux"
      e['version'] = globalOptions[:kernel] + "-custom-" + m[4].chomp('.tar.gz')[0, 7]
    elsif m[1] == "custom" && m[1] == "uboot"
      e['version'] = globalOptions[:uboot] + "-custom-" + m[4].chomp('.tar.gz')[0, 7]
    end
  end

  records << e

end

puts JSON.dump(records)

# now update manifest.csv to replace custom with sha
CSV.open(globalOptions[:dir] + "/manifest.csv", "wb") do |csv|
  modules.each do |m|
    if m[0] != "PACKAGE" and m[1] == "custom"
      if m[0] == "linux"
        m[1] = globalOptions[:kernel] + "-custom-" + m[4].chomp('.tar.gz')[0, 7]
        %x(mv #{globalOptions[:dir]}/licenses/linux-custom #{globalOptions[:dir]}/licenses/linux-#{m[1]})
      elsif m[0] == "uboot"
        m[1] = globalOptions[:uboot] + "-custom-" + m[4].chomp('.tar.gz')[0, 7]
        %x(mv #{globalOptions[:dir]}/licenses/uboot-custom #{globalOptions[:dir]}/licenses/uboot-#{m[1]})
      end
    end

    csv << [m[0], m[1], m[2], m[3], m[4], m[5], m[6]]
  end
end
