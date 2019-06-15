describe Api::V1::Admin::KewillEntryDocumentsController do

  # Implicit in this test is a few checks for the SnsApiControllerSupport module that I don't know how to actually write
  # specs for.  This is due to the LACK of setup that is usually required in all other API tests/specs.

  # 1) JSON Request is not required....ie allow_api_access(user) method is not needed (which sets an Accept header and the user)
  # 2) No authtoken is required
  # 3) No user is required
  # 4) No valid format is required.

  describe "send_s3_file_to_kewill" do
    let (:sns_json) {
      {"Records" => 
        [
          { "s3" => 
            {
              "bucket" => {"name" => "bucket-name"},
              "object" => {
                "key" => "path/to/file.pdf",
                "versionId" => "version-id",
                "size" => 1
              }
            }
          }
        ]
      }
    }

    def set_sns_message sns_json
      message = instance_double("Heroic::SNS::Message")
      allow(message).to receive(:body).and_return sns_json.to_json
      request.env['sns.message'] = message
    end

    it "unwraps SNS / S3 data and sends it to kewill entry documents sender" do
      set_sns_message(sns_json)

      expect(OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender).to receive(:delay).and_return OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender
      expect(OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender).to receive(:send_s3_document_to_kewill).with("bucket-name", "path/to/file.pdf", "version-id")

      post :send_s3_file_to_kewill
      expect(response).to be_success
      expect(response.body).to be_blank
    end

    it "skips files that are marked as zero length" do
      sns_json['Records'].first['s3']['object']['size'] = 0

      set_sns_message(sns_json)

      expect(OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender).not_to receive(:delay)
      expect(OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender).not_to receive(:send_s3_document_to_kewill)

      post :send_s3_file_to_kewill
      expect(response).to be_success
      expect(response.body).to be_blank
    end

    it "raises an error when an error is given from heroic-sns" do
      e = instance_double("StandardError")
      request.env['sns.error'] = e

      expect(e).to receive(:log_me)

      post :send_s3_file_to_kewill
      expect(response).to be_success
      expect(response.body).to be_blank
    end

    it "unescapes file key" do
      sns_json['Records'].first['s3']['object']['key'] = 'file+name.pdf'

      set_sns_message(sns_json)

      expect(OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender).to receive(:delay).and_return OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender
      expect(OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender).to receive(:send_s3_document_to_kewill).with("bucket-name", "file name.pdf", "version-id")

      post :send_s3_file_to_kewill
      expect(response).to be_success
      expect(response.body).to be_blank
    end
  end
end