require 'zip'
require 'zip/filesystem'

# This is a simple wrapper class that makes building a tempfile backed zip file easier.
# This class is primarily only useful for creating temporal zip files that
# should be ftp'ed or emailed directly after being created.
module OpenChain; class ZipBuilder

  # Creates and yields a zip builder and cleans up after itself.
  #
  # Typical usage would look something like this:
  #
  # OpenChain::ZipBuilder.create_zip_builder("myfile.zip") do |zip|
  #  zip.add_file("file1.txt", some_file_object)
  #  zip.add_file("path/to/file2.jpg", another_file)
  #
  #  ftp_file zip.to_tempfile, ftp_credentails
  # end
  #
  def self.create_zip_builder filename
    Tempfile.open([File.basename(filename, ".*"), File.extname(filename)]) do |temp_file|
      temp_file.binmode
      Attachment.add_original_filename_method temp_file, filename
      zip_file = Zip::File.new(temp_file, true, false)
      zip_builder = self.new temp_file, zip_file

      begin
        yield zip_builder
      ensure
        zip_builder.close!
      end
    end
  end

  # Don't use this method..use the create_zip_builder method
  def initialize tempfile, zipfile
    @tempfile = tempfile
    @zipfile = zipfile
    @closed = false
    @file_added = false
    @tempfile_accessed = false
  end

  # Adds the given io-like object to the zip file at the path name.  Multi-level paths are accepted (.ie path/to/file.txt )
  #
  # Any object that could be used the by IO.copy_stream method can be utilized here.
  # From IO.copy_stream docs: "IO-like object ... should have readpartial or read method."
  def add_file zip_relative_path, io_object
    raise "You cannot add new files to closed zip files." if @closed
    # I'm pretty sure there's actually some way to make this work where a Zip file can be written to being committed
    # to a tempfile.  However, I'm not really sure at this poitn how to do that, and I don't really see an
    # actual use-case for being able to do that at this point.
    raise "You cannot add new files to zip builders that have been converted to tempfiles." if @tempfile_accessed

    @zipfile.file.open(zip_relative_path, "w") { |zip_file| IO.copy_stream(io_object, zip_file) }
    @file_added = true
    nil
  end

  # Returns the underlying file implementation of the zip file's contents.
  #
  # NOTE: The file object returned WILL answer to the 'original_file_name' method
  # so it should be safe to directly pass this file to ftp methods and email methods
  # that look for this method to name the files being emailed/ftp'ed.
  def to_tempfile
    raise "You cannot access the tempfile of a closed zip builder." if @closed
    check_if_needs_committing
    @tempfile_accessed = true
    @tempfile
  end

  # Closes the zip tempfile wrapper.
  # You will not need to call this method if you utilize the zip builder create_zip_builder method as you should
  def close!
    return if @closed

    @tempfile.close!
  ensure
    @closed = true
  end

  def closed?
    @closed
  end

  private

    def check_if_needs_committing
      return unless @file_added

      # this will flush the contents of the zip to the tempfile and then reopen the tempfile (unfortunately
      # zip doesn't work to stream data to blank files when building a zip)
      @zipfile.commit
      @tempfile.reopen(@tempfile.path)
      nil
    end

end; end
