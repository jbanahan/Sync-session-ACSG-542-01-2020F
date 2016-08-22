require 'spec_helper'

describe Api::V1::Admin::KewillEntryDocumentsController do

  let (:user) { Factory(:admin_user) }

  describe "send_google_drive_file_to_kewill" do

    before :each do
      allow_api_access user
    end

    it "receives file params and forwards to sender" do
      expect(OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender).to receive(:delay).and_return OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender
      expect(OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender).to receive(:send_google_drive_document_to_kewill).with("email", "path")

      post :send_google_drive_file_to_kewill, {path: "path", email: "email"}
      expect(response).to be_success
      expect(JSON.parse response.body).to eq({"ok" => "ok"})
    end
  end
end