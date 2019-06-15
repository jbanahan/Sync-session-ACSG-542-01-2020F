#!/usr/bin/env ruby

require 'pathname'

# With no params, we'll assume Gemfile.lock is in the CWD, otherwise a full path to the file should be given
gemfile = Pathname.new(ARGV.length > 0 ? ARGV[0].to_s.strip : "Gemfile.lock")

if !gemfile.file?
  if ARGV.length > 0
    STDERR.puts "Failed to locate #{gemfile}."
  else
    STDERR.puts "Failed to locate Gemfile.lock.  If no arguments are given, Gemfile.lock is assume to be in the current working directory."
  end
  exit 1
end

found_bundled_with = false
IO.foreach(gemfile.realpath) do |line|
  if !found_bundled_with && (line =~ /BUNDLED WITH/)
    found_bundled_with = true
  elsif found_bundled_with
    # This should be the line immediately following BUNDLED_WITH
    STDOUT.puts line.strip
    exit 0
  end
end

STDERR.puts "Failed to find bundler version from Gemfile.lock."
exit 1