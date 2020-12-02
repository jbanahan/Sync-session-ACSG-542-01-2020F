describe Api::V1::EmailsController do
  describe "#validate_email_list" do
    before do
      @u = create(:user)
      allow_api_access @u
    end

    it "returns JSON with result of call to email_list_valid?" do
      get :validate_email_list, {email: "tufnel@stonehenge.biz"}
      expect(JSON.parse(response.body)).to eq({"valid" => true})
    end
  end
end
