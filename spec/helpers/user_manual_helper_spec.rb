describe UserManualHelper do

  let!(:um) { create(:user_manual, document_url: "http://www.document_url.com", wistia_code: "wistful") }

  describe "url" do
    it "returns the document_url if it exists" do
      expect(helper.url(um)).to eq "http://www.document_url.com"
    end

    it "returns nil if there's no document_url but wistia_code exists" do
      um.update_attributes! document_url: ""
      expect(helper.url(um)).to be_nil
    end

    it "returns download_user_manual_url if neither document_url nor wistia_code are present" do
      stub_master_setup
      um.update_attributes! document_url: "", wistia_code: ""
      expect(helper.url(um)).to eq Rails.application.routes.url_helpers.download_user_manual_url(um, host: "localhost:3000", protocol: "https")
    end
  end

end
