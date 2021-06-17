#!/usr/bin/ruby

puts ARGV[1]
puts ARGV[2]
puts ARGV[3]

chipfamily = ARGV[3]
input = "#{ARGV[2]}/u-boot-#{chipfamily}.bin"
output = "#{ARGV[2]}/u-boot-#{chipfamily}.img"

# Rename the U-Boot binary from the generic
# u-boot.bin to a chip specific name.
system("mv #{ARGV[1]} #{input}")

# Create a signed copy of the U-Boot binary,
# recognizable by the WebStaX software stack.
archid = ""
chipid = ""
case chipfamily
    when "luton26"
      chipid = "0x7428"
      archid = 2
    when "serval1"
      chipid = "0x7418"
      archid = 2
    when "jaguar2c"
      chipid = "0x7468"
      archid = 2
    when "serval2"
      chipid = "0x7438"
      archid = 2
    when "servalt"
      chipid = "0x7415"
      archid = 2
    when "ocelot"
      chipid = "0x7514"
      archid = 2
    else
      printf "Illegal chip family: #{chipfamily}\n"
      exit 1
    end

system("perl -Iboard/mscc/lib board/mscc/mkbootimage.pl -T #{archid} -C #{chipid} -o #{output} #{input}")
