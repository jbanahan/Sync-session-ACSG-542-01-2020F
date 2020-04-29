require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/amazon/amazon_product_parser_support'

module OpenChain; module CustomHandler; module Amazon; class AmazonProductDocumentsParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::Amazon::AmazonProductParserSupport

  def self.parse data, opts = {}
    self.new.process_document(User.integration, data, opts[:key])
  end

  def process_document user, document_data, filename
    meta_data = extract_document_metadata(filename)
    # This is just to make it easy for us to utilize the find_or_create_product method
    # which for every other Amazon parser is utilized with csv data.
    line = [meta_data[:ior_id], nil, meta_data[:sku]]

    checksum = Digest::SHA256.hexdigest(document_data)

    find_or_create_product(line) do |product|
      attachment = find_existing_document(product, meta_data, checksum)

      if attachment.nil?
        # The easiest thing to do here is to write out the file data to a tempfile and then
        # save off the product (letting paperclip do its thing - which includes virus scanning)
        Tempfile.open([File.basename(meta_data[:filename], ".*"), File.extname(meta_data[:filename])]) do |tempfile|
          tempfile.binmode
          tempfile << document_data
          tempfile.flush
          Attachment.add_original_filename_method(tempfile, meta_data[:filename])

          attachment = product.attachments.build attachment_type: meta_data[:oga], checksum: checksum
          attachment.attached = tempfile
          attachment.save!
          product.create_snapshot(user, nil, filename)
        end
      else
        inbound_file.add_warning_message("File '#{meta_data[:filename]}' is already attached to product #{product.unique_identifier}.")
      end

    end
  end

  def extract_document_metadata filename
    # The filename of the document will tell us the Importer, the Part Number, the PGA document type
    # and the actual document name.

    # The filename also at this point will have the timestamp value injected into it by our ftp process.  We'll
    # want to remove that.
    filename = self.class.get_s3_key_without_timestamp(File.basename(filename))
    if filename =~ /\A[^_]+_([^_]+)_([^_]+)_[^_]+_PGA_([^_]+)_(.*)/
      return {ior_id: $1, sku: $2, oga: $3, filename: $4}
    else
      inbound_file.reject_and_raise("File name '#{filename}' does not appear to match the expected format for Amazon PGA documents.")
    end
  end

  def find_existing_document product, meta_data, checksum
    product.attachments.find do |a|
      a.attached_file_name == meta_data[:filename] &&
        a.checksum == checksum
    end
  end

end; end; end; end