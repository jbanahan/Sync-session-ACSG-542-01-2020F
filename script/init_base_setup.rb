#!/usr/bin/env ruby

require_relative File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))

if ARGV.length == 0 || ARGV[0].to_s.length == 0
  STDERR.puts "You must pass a Company Name, Sys Admin Email address, and HTTP Host Name as parameter."
  exit 1
elsif !(ARGV[1].to_s =~ /[^@]+@[^\.]+\..+/)
  STDERR.puts "You must pass a valid Sys Admin Email address as a second parameter."
  exit 1
elsif ARGV[2].to_s.length == 0
  STDERR.puts "You must pass the System Code as a parameter."
  exit 1
elsif ARGV[3].to_s.length == 0
  STDERR.puts "You must pass a valid HTTP Host Name as a parameter."
  exit 1
end

STDOUT.puts "Creating Master Setup, primary Company and Sys Admin user records."
ms = MasterSetup.init_base_setup(company_name: ARGV[0], sys_admin_email: ARGV[1], system_code: ARGV[2], host_name: ARGV[3], init_script: true)
if ms.nil?
  STDERR.puts "Failed to generate primary instance data."
end

STDOUT.puts "Creating entity snapshot S3 bucket named: #{EntitySnapshot.bucket_name}"
EntitySnapshot.create_bucket_if_needed!

STDOUT.puts "Creating default scheduled jobs."
SchedulableJob.create_default_jobs!

STDOUT.puts "Creating base country list."
Country.load_default_countries
