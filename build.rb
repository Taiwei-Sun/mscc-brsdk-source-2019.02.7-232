#!/usr/bin/env ruby

require 'pp'
require 'open3'
require 'logger'
require 'optparse'
require 'fileutils'
require 'yaml'
require 'thread'
require_relative '.resultnode.rb'

$steps = ["build", "pack", "relocate", "all"]

if ARGV.length < 1 or (not $steps.include?(ARGV[0]) and ARGV[0] != "--help")
    puts "One argument mandatory"
    exit
end

def sys(msg, cmd)
    begin
        system "#{$options[:build_path]}/.logcmd.rb --line-prepend \"#{"%-20s" % [msg]}\" --log #{File.expand_path(__FILE__) + ".log"} -- \"#{cmd}\""
        raise "Running '#{cmd}' failed" if $? != 0 and $options[:fail_on_error]
    rescue
        save_log
        raise
    end
end

def sys_safe(msg, cmd)
    system "#{$options[:build_path]}/.logcmd.rb --line-prepend \"#{"%-20s" % [msg]}\" --log #{File.expand_path(__FILE__) + ".log"} -- \"#{cmd}\""
end

def sys_ret(msg, file, cmd)
        system "#{$options[:build_path]}/.logcmd.rb --line-prepend \"#{"%-20s" % [msg]}\" --log #{$options[:build_path]}/#{file + ".log"} -- \"#{cmd}\""
        return $? == 0 ? true : false
end

def sys_log(msg, file, cmd)
    begin
        system "#{$options[:build_path]}/.logcmd.rb --line-prepend \"#{"%-20s" % [msg]}\" --log #{$options[:build_path]}/#{file + ".log"} -- \"#{cmd}\""
        raise "Running '#{cmd}' failed" if $? != 0 and $options[:fail_on_error]
    rescue
        save_log
        raise
    end
end

def save_log
    log_folder = "#{$src_ws}/#{$log_name}"
    sys_safe "save_log>", "mkdir -p #{log_folder}/"

    Dir.glob("configs/*.yaml").each do |conf_yaml|
        conf = YAML.load_file(conf_yaml)
        t = conf["defconfig_name"]
        next if not File.exists?("#{t}")

        sys_safe "save_log>", "cp #{t}/#{t}.log #{log_folder}/"
    end
    sys_safe "save_log>", "cd #{$src_ws} && tar -czf #{$log_name}.tar.gz --owner=root --group=root #{$log_name}"
    sys_safe "save_log>", "cd #{$src_ws}; mkdir -p artifact"
    sys_safe "save_log>", "cd #{$src_ws}; cp *.tar.gz artifact/"
end

def find_keyword(array, keyword)
    array.each{ |x|
        if x.start_with?(keyword)
            return x.split(" ")[2]
        end
    }
end

def get_uboot_version()
    uboot_sha = $config["vars"]["MSCC_UBOOT_SHA"]
    sys "uboot-version", "tar -xf dl/uboot/#{uboot_sha}.tar.gz -C /tmp/"
    file_array = File.readlines("/tmp/uboot-#{uboot_sha}/Makefile")
    version = find_keyword(file_array, "VERSION")
    patchlevel = find_keyword(file_array, "PATCHLEVEL")
    sublevel = find_keyword(file_array, "SUBLEVEL")
    extraversion = find_keyword(file_array, "EXTRAVERSION")

    sys "uboot-version", "rm -rf /tmp/uboot-#{uboot_sha}"

    res = "#{version}.#{patchlevel}"
    res += "-#{sublevel}" if not sublevel.nil?
    res += extraversion if not extraversion.nil?
    return res
end

def get_linux_version()
    linux_sha = $config["vars"]["MSCC_LINUX_KERNEL_SHA"]
    sys "linux-version", "tar -xf dl/linux/#{linux_sha}.tar.gz -C /tmp/"
    file_array = File.readlines("/tmp/linux-#{linux_sha}/Makefile")
    version = find_keyword(file_array, "VERSION")
    patchlevel = find_keyword(file_array, "PATCHLEVEL")
    sublevel = find_keyword(file_array, "SUBLEVEL")
    extraversion = find_keyword(file_array, "EXTRAVERSION")

    sys "linux-version", "rm -rf /tmp/linux-#{linux_sha}"

    res = "#{version}.#{patchlevel}"
    res += "-#{sublevel}" if not sublevel.nil?
    res += extraversion if not extraversion.nil?
    return res
end

def update_legal_info(output_folder)
    sys "legal>", "./licensedata.rb --legal-info #{output_folder} --kernel #{get_linux_version()} --uboot #{get_uboot_version()} > #{output_folder}/licensedata.txt"
    sys "legal>", "xz --check=none --lzma2=preset=6e,dict=64KiB --stdout #{output_folder}/licensedata.txt > #{output_folder}/licensedata.xz"
    sys "legal>", "rm -rf #{output_folder}/host-sources"
    sys "legal>", "rm -rf #{output_folder}/sources"
end

def generate_sdk_setup(arch, output)
    setup = ""
    if arch == "mips"
        setup += <<EOF
MSCC_SDK_PATH        ?= $(MSCC_SDK_BASE)/mipsel-mips32r2-linux-gnu/$(MSCC_SDK_FLAVOR)/x86_64-linux/usr/bin
MSCC_SDK_ROOT        ?= $(MSCC_SDK_BASE)/mipsel-mips32r2-linux-gnu/$(MSCC_SDK_FLAVOR)/rootfs.squashfs
MSCC_SDK_SYSROOT     ?= $(MSCC_SDK_BASE)/mipsel-mips32r2-linux-gnu/$(MSCC_SDK_FLAVOR)/x86_64-linux/usr/mipsel-buildroot-linux-gnu/sysroot
MSCC_SDK_PREFIX      ?= $(MSCC_SDK_PATH)/mipsel-linux-
MSCC_SDK_TARGET_OPTS ?= -mel -mabi=32 -msoft-float -march=mips32
EOF
    elsif arch == "arm"
        setup += <<EOF
MSCC_SDK_PATH        ?= $(MSCC_SDK_BASE)/arm-cortex_a8-linux-gnu/bbb/x86_64-linux/usr/bin
MSCC_SDK_ROOT        ?= $(MSCC_SDK_BASE)/arm-cortex_a8-linux-gnu/bbb/rootfs.squashfs
MSCC_SDK_SYSROOT     ?= $(MSCC_SDK_BASE)/arm-cortex_a8-linux-gnu/bbb/x86_64-linux/usr/arm-buildroot-linux-gnueabihf/sysroot
MSCC_SDK_PREFIX      ?= $(MSCC_SDK_PATH)/arm-linux-
MSCC_SDK_TARGET_OPTS ?= -march=armv7-a -mtune=cortex-a8 -mfpu=neon
EOF
    elsif arch == "arm64"
        setup += <<EOF
MSCC_SDK_PATH        ?= $(MSCC_SDK_BASE)/arm64-armv8_a-linux-gnu/ls1046/x86_64-linux/usr/bin
MSCC_SDK_ROOT        ?= $(MSCC_SDK_BASE)/arm64-armv8_a-linux-gnu/ls1046/rootfs.squashfs
MSCC_SDK_SYSROOT     ?= $(MSCC_SDK_BASE)/arm64-armv8_a-linux-gnu/ls1046/x86_64-linux/usr/aarch64-buildroot-linux-gnu/sysroot
MSCC_SDK_PREFIX      ?= $(MSCC_SDK_PATH)/aarch64-linux-
MSCC_SDK_TARGET_OPTS ?= -march=armv8-a -mtune=generic
EOF
    end

    setup += <<EOF
MSCC_TOOLCHAIN_FILE ?= #{$tool_file}
MSCC_TOOLCHAIN_DIR  ?= #{$tool_dir}
MSCC_TOOLCHAIN_BRANCH ?= #{$tool_br}
EOF

    IO.write("#{output}/sdk-setup.mk", setup)
end

def simplegrid_build(conf)
    ret = true
    begin
        cmd  = "SimpleGridClient -w #{$src_ws}/#{$src_name}.tar.gz --stamps #{conf["defconfig_name"]}/#{conf["defconfig_name"]} "
        cmd += "-c 'hostname && pwd && "
        cmd += "./#{$src_name}/build.rb build --configs=#{conf["defconfig_name"]} --build-path=#{$src_name} "
        if $options[:fail_on_error]
            cmd += "--fail-on-error "
        end
        cmd += "&& "
        cmd += "rm -rf #{conf["defconfig_name"]}/build && "
        cmd += "pwd' "
        cmd += "-a #{$src_name}/#{conf["defconfig_name"]} "
        cmd += "-o #{conf["defconfig_name"]}.tar "
        ret = sys_ret "sg-#{conf["defconfig_name"]}>", "#{conf["defconfig_name"]}/#{conf["defconfig_name"]}", "#{cmd}"
        sys "sg-#{conf["defconfig_name"]}>", "tar xf #{conf["defconfig_name"]}.tar --strip-components 1"
        sys "sg-#{conf["defconfig_name"]}>", "rm #{conf["defconfig_name"]}.tar"
    rescue
        ret = false
    end
    $buildTop.addSibling(ResultNode.new(conf["defconfig_name"], ret == true ? "OK" : "Failure"))
    return ret
end

#####################################################
$options = {
    :configs => ".*",
    :branch => "brsdk",
    :build_path => ".",
}

OptionParser.new do |opt|
    opt.banner = """
usage: ./build.rb build|pack|relocate|all [--configs=<regex>] [--simplegrid]
                  [--local] [--fail-on-error] [--summary]

Available steps:
    The step is the first argument and it is mandatory. It must be one of the
    following: build, pack, relocate, all.

    build   - builds the sources. This step can be used to fiddle around the
              buildroot and then just run this step again, in this way the
              sources are not generated again. The following options are
              available for this step:
                - configs - accepts a regex expression that will be matched with
                            the configuration names, and only those that will
                            match will be build. If nothing is passed will match
                            all configurations
                - simplegrid - this enables to build using SimpleGridClient,
                               the result will be stored in the sources. This
                               option removes the build folder from output dir
                               therefore running again the BUILD step it takes
                               the same amount of time.
    pack    - this collects all the results and add them to a folder. The
              result folder is 'ws/mscc-brsdk-<arch>-<version>-<build-no>'.
              The following options are available for this step:
                - configs - it is similar with the one from the build step.
    relocate- this step creates the artifact folder needed by Jenkins or copies
              the result folder to /opt/mscc/ folder. The following options are
              available for this step:
                - configs - it is similar with the one from the build step.
                - local - choses to copy the result folder to /opt/mscc
                          othwerwise it creates an archive folder that is used
                          by Jenkins
                - summary - creates a summary of the build. This options is
                            mainly used by Jenkins, because the output folder
                            depends on the build step.
    all   - it executes all the previous steps in the order: build, pack,
            relocate.

Few examples:
    - build all configurations for local use:
        ./build.rb all --simplegrid --local
    - build a single configuration for local use:
        ./build.rb all --configs mscc_ocelot_stage1 --local
    - rebuild all stage1 configurations:
        ./build.rb build --configs stage1
        After running  this step the result target is still in the sources
        directory therefore you still need collect the results and copy them
        to /opt/mscc to use them, therefore the commands will do that
            ./build.rb pack
            ./build.rb relocate --local

Options:
    """
    opt.on('--configs x,y,z',   "Configurations which to be build") { |o| $options[:configs] = o }
    opt.on('--build-path=x',    "Configure the path to build.rb script") { |o| $options[:build_path] = o }
    opt.on('--simplegrid',      "If set use simple grid for building") { |o| $options[:simplegrid] = o }
    opt.on('--fail-on-error',   "If set it would failed on any error") { |o| $options[:fail_on_error] = o }
    opt.on('--summary=s',       "Write summary status JSON file") { |o| $options[:summary] = o }
    opt.on('--local',           "Skips the tar files that are needed for deploy.
                                       It can be used when building locally to test different changes") { |o| $options[:local] = o }
end.parse!

$config     = YAML.load_file("#{$options[:build_path]}/.config.yaml")

$topRes     = ResultNode.new('brsdk', "OK", {"sdkversion" => $options[:version]})
$buildTop   = ResultNode.new('build', "OK")

$src_ws     = ENV['WS'] || ".."

$src_name   = %x(basename $PWD).chomp
$log_name   = $src_name.gsub("source", "logs")

$version    = $src_name.gsub("mscc-brsdk-source-", "")

$regexp     = Regexp.new($options[:configs])
$step       = ARGV[0]

$tool_ver   = $config["tool_ver"]
$tool_br    = $config["tool_br"]
$tool_dir   = "#{$tool_ver}-#{$tool_br}"
$tool_file  = "#{$tool_ver}"
$tool_file  = "#{$tool_file}-#{$tool_br}" if $tool_br != "toolchain"

sdk_install = "/usr/local/bin/mscc-install-pkg"
if File.exists?(sdk_install)
    sys "toolchain", "sudo #{sdk_install} -t toolchains/#{$tool_dir} mscc-toolchain-bin-#{$tool_file}"
elsif not File.exists?("/opt/mscc/mscc-toolchain-bin-#{$tool_file}")
    puts "ABORT: Required toolchain: mscc-toolchain-bin-#{$tool_file} doesn't exits"
    exit
end

if $step == "all" or $step == "build"
    $threads = []
    semaphore = Mutex.new
    ret = true
    Dir.glob("#{$options[:build_path]}/configs/*.yaml").each do |conf_yaml|
        conf = YAML.load_file(conf_yaml)
        next if not $regexp.match(conf["defconfig_name"])

        t = conf["defconfig_name"]

        if $options[:simplegrid]
            $threads << Thread.new do
                tmp = simplegrid_build conf
                semaphore.synchronize {
                    ret &= tmp
                }
            end
        else
            $threads << Thread.new do
                ret = true
                begin
                    sys_log "#{t}>", "#{File.join("#{t}", "#{t}")}", "cd #{$options[:build_path]}; make O=#{t}"
                    sys_log "#{t}>", "#{File.join("#{t}", "#{t}")}", "cd #{$options[:build_path]}; make O=#{t} sdk"
                    sys_log "#{t}>", "#{File.join("#{t}", "#{t}")}", "cd #{$options[:build_path]}; make O=#{t} legal-info"
                rescue
                    ret = false
                end
                $buildTop.addSibling(ResultNode.new(conf["defconfig_name"], ret == true ? "OK" : "Failure"))
            end
        end
    end

    $threads.each do |t|
        t.join
    end

    if ret == false and $options[:simplegrid]
        save_log
        exit -1
    end
end

$topRes.addSibling($buildTop)
$topRes.reCalc

if $step == "all" or $step == "pack"
    result_folders = []
    log_folder = "#{$src_ws}/#{$log_name}"
    sys "pack >", "mkdir -p #{log_folder}/"

    Dir.glob("configs/*.yaml").each do |conf_yaml|
        conf = YAML.load_file(conf_yaml)
        next if not $regexp.match(conf["defconfig_name"])

        t = conf["defconfig_name"]
        next if not File.exists?("#{t}")

        img_folder    = "#{$src_ws}/images/#{conf["output_path"]}"
        result_folder = "#{$src_ws}/#{conf["output_packet"]}-#{$version}/#{conf["output_path"]}"
        result_folders << "#{$src_ws}/#{conf["output_packet"]}-#{$version}"

        sys "pack>", "mkdir -p #{img_folder}"
        sys "pack>", "mkdir -p #{result_folder}/x86_64-linux"

        sys "pack>", "cp -r #{t}/host/* #{result_folder}/x86_64-linux/"
        sys "pack>", "cp -r #{t}/images/* #{result_folder}"
        sys "pack>", "cp -r #{t}/images/* #{img_folder}/."
        legal_output = "#{result_folder}/legal-info"
        sys "pack>", "mkdir -p #{legal_output}"
        sys "pack>", "cp -r #{t}/legal-info/* #{legal_output}"
        sys "pack>", "cp  .mscc-version #{$src_ws}/#{conf["output_packet"]}-#{$version}"
        sys "pack>", "cp #{t}/#{t}.log #{result_folder}"
        sys "pack>", "mv #{result_folder}/*.log #{log_folder}/"

        generate_sdk_setup "#{conf["arch"]}", "#{$src_ws}/#{conf["output_packet"]}-#{$version}"
        update_legal_info legal_output
    end

    result_folders = result_folders.uniq
    result_folders.each { |x|
        sys "dedup>", "./dedup.rb #{x}"
    }
end

if $step == "all" or $step == "relocate"
    # create arch
    Dir.glob("configs/*.yaml").each do |conf_yaml|
        conf = YAML.load_file(conf_yaml)
        next if not $regexp.match(conf["defconfig_name"])

        t = conf["defconfig_name"]
        next if not File.exists?("#{t}")

        result_folder = "#{conf["output_packet"]}-#{$version}"
        if not File.exists?("#{$src_ws}/#{result_folder}.tar.gz")
            sys "relocate>", "cd #{$src_ws} && tar -czf #{result_folder}.tar.gz --owner=root --group=root #{result_folder}"
        end
    end

    sys "relocate>", "cd #{$src_ws} && tar -czf #{$log_name}.tar.gz --owner=root --group=root #{$log_name}"

    if $options[:local]
        system "cd #{$src_ws}; for f in *.tar.gz; do sudo tar -xzf $f -C /opt/mscc; done"
    else
        sys "relocate", "cd #{$src_ws}; mkdir -p artifact"
        sys "relocate", "cd #{$src_ws}; cp *.tar.gz artifact/"
        sys "relocate", "cd #{$src_ws}; cp -r images/* artifact/"

        if $options[:summary]
            $topRes.to_file($options[:summary])
            sys "relocate", "mv #{$options[:summary]} #{$src_ws}/artifact"
        end

        sys "relocate", "cd #{$src_ws}/artifact; echo 'toolchain: #{$tool_file}' > dependencies.txt"
        sys "relocate", "cd #{$src_ws}/artifact; find . -type f ! -iname files.md5 -print0 | xargs -0 md5sum > files.md5"
    end
end

if $topRes.status == "OK"
    exit 0
else
    exit -1
end
