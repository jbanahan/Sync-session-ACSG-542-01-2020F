require 'zip'
require 'zip/filesystem'
require 'open_chain/s3'

module OpenChain; module CreateZipSupport

  # Downloads all given attachments and zips them into a temp zip file
  # yields the tempfile and the zip file after downloading.
  def zip_attachments zip_original_filename, attachments
    l = lambda do |zip|
      attachments.each do |attachment|
        io = StringIO.new
        OpenChain::S3.get_data(attachment.bucket, attachment.path, io)
        Zipper.add_io_to_zip(zip, attachment.attached_file_name, io)
      end
    end

    Zipper.create_zip_tempfile(zip_original_filename, l) do |tempfile|
      yield tempfile
    end
  end

  # Use an inner class to hide internals of zip creation
  class Zipper

    def self.create_zip_tempfile original_filename, file_operation_lambda
      Tempfile.open([File.basename(original_filename, ".*"), File.extname(original_filename)]) do |tempfile|
        tempfile.binmode
        Attachment.add_original_filename_method tempfile, original_filename

        Zip::File.open(tempfile.path, Zip::File::CREATE) do |zipfile|
          file_operation_lambda.call(zipfile)
        end

        # At this point we need to re-open the zip file otherwise it won't know that data has been written to it
        # since zip writes using the file path and not via the IO object/filehandle directly.
        tempfile.reopen(tempfile.path)
        yield tempfile
      end
    end

    def self.add_io_to_zip zip, zip_path, io
      zip.file.open(zip_path, "w") {|f| f << io.read }
    end
  end



end; end;