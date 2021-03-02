#!/usr/bin/env ruby

require 'digest'
require 'pathname'
require 'pp'

$cnt = 0
$hash_to_path = {}
$path_to_hash = {}
$dedupped = []

def idx_add hash, path
    if $hash_to_path[hash].nil?
        $hash_to_path[hash] = []
    end
    $hash_to_path[hash] << path
    $path_to_hash[path] = hash
end

def walk_idx level, start
    dir_size = 0
    dir_key = []

    Dir.foreach start do |name|
        path = File.join start, name

        next if name == "." or name == ".."

        if File.symlink? path
            dir_key << "#{File.readlink(path)} symlink #{name}"

        elsif File.directory? path
            sum, size = walk_idx level + 1, path
            dir_key << "#{sum} dir #{name}"
            dir_size += size
            #puts "#{sum} dir #{path}"

        elsif File.file? path
            sum = Digest::SHA256.file path
            dir_key << "#{sum.hexdigest} file #{name}"
            idx_add sum.hexdigest, path
            dir_size += File.size(path)
        else
            # block device??
            raise "type not hoandled: #{path}"
        end
    end

    if dir_key.size > 0 and dir_size > 100
        dir_key.sort!
        #pp dir_key
        sum = Digest::SHA256.hexdigest dir_key.join(" ")
        #puts "#{start} #{dir_size}"
        idx_add sum, start
    end

    return sum, dir_size
end

def walk_dedup level, start
    #puts "#{level}dedup walk: #{start}"
    # dedup before walking
    Dir.foreach start do |name|
        path = File.join start, name

        next if name == "." or name == ".."
        next if File.symlink? path
        next if $dedupped.include? path

        #puts "#{level}loop start: #{path}"

        if File.directory? path or File.file? path
            matches = []
            begin
                h = $path_to_hash[path]
                matches = $hash_to_path[h]
            rescue
            end
            matches = [] if matches.nil?


            if matches.size > 1
                cur = Pathname.new(path)
                #puts ""
                #puts "keep: #{path}"

                matches.each do |m|
                    $dedupped << m
                    next if m == path
                    dup = Pathname.new(File.dirname(m))
                    link = cur.relative_path_from dup

                    #puts "dup: #{m}"
                    #puts "ln -s #{link.to_s} #{m}"

                    $cnt += 1
                    %x{rm -rf #{m}}
                    %x{ln -s #{link.to_s} #{m}}
                end
            end
        else
        end
    end

    # walk
    Dir.foreach start do |name|
        path = File.join start, name

        next if name == "." or name == ".."
        next if File.symlink? path

        next if $dedupped.include? path

        next if name == "legal-info"

        if File.directory? path
            walk_dedup level + "  ", path
        end
    end
end

if ARGV.length == 0
    puts "Please pass the the root path"
    exit
end

puts "Building index"
walk_idx 0, ARGV[0]
puts "Doing deduplication"
walk_dedup "", ARGV[0]
puts $cnt

