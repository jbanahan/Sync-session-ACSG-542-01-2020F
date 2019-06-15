require 'open_chain/custom_handler/vandegrift/kewill_entry_documents_sender'

module Api; module V1; module Admin; class KewillEntryDocumentsController < AdminApiController
  include Api::V1::SnsApiControllerSupport
  # Skip all the normal API filters for the SNS subscription endpoint
  skip_filters :send_s3_file_to_kewill

  def send_s3_file_to_kewill
    # Heroic-SNS (middleware) places the sns message for us into the request env
    if message = request.env['sns.message']

      # The body of the SNS notification is the information about which s3 files were updated
      s3_payload = JSON.parse(message.body)

      Array.wrap(s3_payload['Records']).each do |record|
        s3_record = record["s3"]
        next unless s3_record 

        # Ignore files that are 0 length.  The GUI console makes these for some reason when uploading / replacing files for some reason.
        file_size = s3_record['object'].try(:[], "size")
        next unless !file_size.nil? && BigDecimal(file_size.to_s).nonzero?

        # All we're looking for out of this message is the bucket, key and version....backend will handle the rest.
        bucket = s3_record['bucket'].try(:[], "name")
        key = s3_record['object']['key']
        version = s3_record['object']['versionId']

        if bucket && key
          # We should unescape the key here because any spaces in the key path are changed to +'s .ie "1234 - Test.pdf" -> "1234+-+Test.pdf"
          # That key will not be able to retrieve the file, the escaped value must be unescaped
          key = CGI.unescape key
          OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender.delay.send_s3_document_to_kewill bucket, key, version
        end
      end

    elsif error = request.env['sns.error']
      # Not entirely certain what errors would get encountered here...however, the readme page for the gem has this, so I'm keeping it.
      error.log_me
    end

    head :ok
  end

end; end; end; end
