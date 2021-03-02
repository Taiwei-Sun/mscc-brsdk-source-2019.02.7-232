#!/usr/bin/env ruby

require 'yaml'

def get_conf(file)
    res = []
    File.open(file).each_line do |line|
        if line.length != 0
            res << line.chomp
        end
    end
    return res
end

def display_diff(search, where)
    search.each { |x|
        if not where.include?(x)
            puts x
        end
    }
end

def display_result(old_conf, new_conf)
    puts "Removed options: "
    display_diff(old_conf, new_conf)
    puts "New options: "
    display_diff(new_conf, old_conf)
end

def kernel_show_diff(defconfig_name, olddef_file)
    savedef_file = "#{defconfig_name}/build/linux-custom/defconfig"
    return if not File.exists?(savedef_file)

    old_conf = get_conf(olddef_file)
    new_conf = get_conf(savedef_file)
    display_result(old_conf, new_conf)
end

def uboot_show_diff(defconfig_name, olddef_file)
    savedef_file = "#{defconfig_name}/build/uboot-custom/defconfig"
    return if not File.exists?(savedef_file)

    old_conf = get_conf(olddef_file)
    new_conf = get_conf(savedef_file)
    display_result(old_conf, new_conf)
end

def busybox_show_diff(newdef_file, olddef_file)
    return if not File.exists?(olddef_file)

    old_conf = get_conf(olddef_file)
    new_conf = get_conf(newdef_file)
    display_result(old_conf, new_conf)
end

def split_diff(output)
    added = []
    removed = []

    output.each { |x|
        if x[0] == "+" and x[1] != "+"
            added << x[1..-1]
        elsif x[0] == "-" and x[1] != "-"
            removed << x[1..-1]
        end
    }
    return added, removed
end

def buildroot_show_diff(output)
    diff_output = %x(git diff #{output}).chomp
    return if diff_output.length == 0
    added, removed = split_diff(diff_output.split("\n"))
    display_result(removed, added)
end

def get_config_file(defconfig, name)
    defconfig = defconfig.chomp("_defconfig")
    conf = YAML.load_file("configs/#{defconfig}.yaml")
    conf["append_files"].each do |c|
        output = c["config_file"]
        if output.include?(name)
            return output
        end
    end
    raise "Naspa"
end

def exists_conf(defconfig)
    return File.exists?("configs/#{defconfig}")
end

################################################################################
$menuconfigs = ["buildroot", "linux", "uboot", "busybox"]

if ARGV.length < 2 and ARGV[0] != "--help"
    puts "One argument mandatory"
    exit
end

if ARGV[0] == "--help"

    puts  """
usage: ./edit_config.rb config_name buildroot|busybox|linux|uboot [diff]

    config_name - name of the config that you want to edit.
                    For example: mscc_stage1_ocelot_defconfig
    options     - this has to be one of the 4 values: buildroot, busybox, linux,
                  uboot and for this option will open the menuconfig.
    diff        - in case diff is set, then the menuconfig is not open anymore
                  and it is just showing the differences.

    Examples:
        ./edit_config mscc_stage2_smb_defconfig buildroot
            - opens menuconfig, save defconfig and shows the differences between
              what was initially and the new changes.
        ./edit_config mscc_ls1046_defconfig linux-menuconfig diff
            - shows only the differences between configs

    OBS!
        All the changes are added together. So if the user open twice the
        menuconfig for buildroot and changes some parameters, second time it
        would show also the changes from the first modification.
"""
    exit
end

$defconfig = ARGV[0]
$option = ARGV[1]
$diff_only = ARGV[2]

$busybox_version = "1.28.4"

if not exists_conf($defconfig)
    puts "deconfig doesn't exist"
    exit
end

if not $menuconfigs.include?($option)
    puts "second argument needs to be one of:"
    puts "  buildroot"
    puts "  busybox"
    puts "  linux"
    puts "  uboot"
    exit
end

if $diff_only and $diff_only != "diff"
    puts "last argument needs to 'diff' to show only the differences"
    exit
end

if not File.exists?(".edit_config_run")
    system "git add configs; git commit -m \"init\""
    system "touch .edit_config_run"
end

if $option == "buildroot"
    if $diff_only == nil
        system "make O=#{$defconfig} menuconfig"
        system "make O=#{$defconfig} savedefconfig"
    end
    buildroot_show_diff(get_config_file($defconfig, "_defconfig"))
end
if $option == "linux"
    if $diff_only == nil
        system "make O=#{$defconfig} toolchain"
        system "make O=#{$defconfig} linux-menuconfig"
        system "make O=#{$defconfig} linux-savedefconfig"
    end
    kernel_show_diff("#{$defconfig}", get_config_file($defconfig, "_kernel"))
end
if $option == "uboot"
    if $diff_only == nil
        system "make O=#{$defconfig} toolchain"
        system "make O=#{$defconfig} uboot-menuconfig"
        system "make O=#{$defconfig} uboot-savedefconfig"
    end
    uboot_show_diff("#{$defconfig}", get_config_file($defconfig, "_uboot"))
end
if $option == "busybox"
    if $diff_only == nil
        system "make O=#{$defconfig} toolchain"
        if not File.exists?(".#{$defconfig}_busybox.config")
            system "cp #{$defconfig}/build/busybox-#{$busybox_version}/.config .#{$defconfig}_busybox.config"
        end
        system "make O=#{$defconfig} busybox-menuconfig"
    end
    busybox_show_diff("#{$defconfig}/build/busybox-#{$busybox_version}/.config", ".#{$defconfig}_busybox.config")
end
