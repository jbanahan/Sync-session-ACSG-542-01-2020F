require 'open_chain/ftp_file_support'
require 'open_chain/s3'

module OpenChain; module CustomHandler; module GpgDecryptPassthroughSupport
  include OpenChain::FtpFileSupport
  extend ActiveSupport::Concern

  module ClassMethods
    def parse_file data, log, opts = {}
      self.new.parse_file(data, log, opts)
    end
  end

  def parse_file data, log, opts = {}
    bucket = opts[:bucket]
    key = opts[:key]

    log.error_and_raise "All invocations of this parser must include :bucket and :key options." if bucket.blank? || key.blank?

    filename = opts[:original_filename].presence || File.basename(key)

    OpenChain::S3.download_to_tempfile(bucket, key, original_filename: filename) do |infile|
      decrypt_file_to_tempfile(infile) do |decrypted|
        ftp_file(decrypted)
      end
    end
  end

  def decrypt_file_to_tempfile file
    filename = file.respond_to?(:original_filename) ? file.original_filename : File.basename(file.path)
    # Strip any gpg / pgp file extensions to mimic how the actual gpg/pgp command line programs work
    if filename.upcase.ends_with?(".PGP")
      filename = File.basename(filename, ".pgp")
    elsif filename.upcase.ends_with?(".GPG")
      filename = File.basename(filename, ".gpg")
    end

    Tempfile.open([File.basename(filename, ".*"), File.extname(filename)]) do |outfile|
      outfile.binmode

      Attachment.add_original_filename_method(outfile, filename)

      gpg_helper().decrypt_file(file, outfile, gpg_passphrase())

      yield outfile
    end
  end

  def gpg_passphrase
    # By default, assume we don't need a passphrase to decrypt
    nil
  end
end; end; end;