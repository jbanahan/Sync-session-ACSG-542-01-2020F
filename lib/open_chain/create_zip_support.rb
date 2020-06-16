require 'open_chain/s3'
require 'open_chain/zip_builder'

module OpenChain; module CreateZipSupport

  # Downloads all given attachments and zips them into a temp zip file
  # yields the tempfile and the zip file after downloading.
  def zip_attachments zip_original_filename, attachments
    OpenChain::ZipBuilder.create_zip_builder(zip_original_filename) do |builder|
      attachments.each do |attachment|
        io = StringIO.new
        OpenChain::S3.get_data(attachment.bucket, attachment.path, io)
        io.rewind
        builder.add_file attachment.attached_file_name, io
      end

      yield builder.to_tempfile
    end
  end

end; end;
