#!/usr/bin/ruby

$path = "mscc_bbb_defconfig/images"
$output = "#{$path}/bbb.img"

# create image
system("dd if=/dev/zero of=#{$output} bs=1M count=10")

# copy the MLO and u-boot.img at specific offsets,
# because the ROM code is looking at these offsets to load the MLO and
# u-boot.img
system("dd if=#{$path}/MLO of=#{$output} count=1 seek=1 bs=128k conv=notrunc")
system("dd if=#{$path}/u-boot.img of=#{$output} count=2 seek=1 bs=384k conv=notrunc")

# create partition layout, first 4M will remained unpartitioned, because
# there is the MLO and u-boot.img. The remained space is used for ext4
system("sfdisk #{$output} <<-__EOF__
4M,,L,*
__EOF__")

# format the partition to be able to save the environment
system("mkfs.ext4 -F -L rootfs -O ^metadata_csum,^64bit #{$output} -E offset=$(( 512 * 8192 ))")

