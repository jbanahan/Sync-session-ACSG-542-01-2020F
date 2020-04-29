require_relative File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))
require 'open_chain/s3'

# User provided arguements.
# For example, to zero out all files older than 4 hours from the asdf/zxcv/ prefix in the globallyuniquebucket:
#  `ruby script/zero_s3_documents.rb globallyuniquebucket asdf/zxcv/ 14400`
#
#  Arguments must be provided to avoid mistakes. If you want no age provide a zero and '' for the entire bucket
#  ie - `ruby script/zero_s3_documents.rb globallyuniquebucket '' 0`
age = ARGV[0].to_i # provided in seconds
bucket = ARGV[1]
prefix = ARGV[2] # provided in relative file format string

# Given a s3 prefix and age zero out files older than said age
if age == nil || prefix == nil || bucket == nil
  puts "Not all arguments were set! Must provide a bucket, an age in seconds, and prefix."
  puts "Aborting"
else
  # Gather all the files from the given prefix
  files = OpenChain::S3::Client.list_objects(bucket, max_files: 1000, prefix: prefix)

  files.each { |f|
    if f[:last_modified].to_datetime <= (Time.now - age.seconds).to_datetime
      puts "#{f[:key]} - #{f[:last_modified].to_datetime} is being zero'ed..."

      # zero them
      # Note: this will attempt to zero the prefix as well, but won't actually do anything
      OpenChain::S3::zero_file bucket, f[:key]
    else
      puts "#{f[:key]} - Not old enough"
    end
  }

  puts "Finished searching for and zeroing files"

end
