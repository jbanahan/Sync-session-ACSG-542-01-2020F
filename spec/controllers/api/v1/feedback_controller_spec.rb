describe Api::V1::FeedbackController do

  let!(:user) { Factory(:user) }

  before :each do
    allow_api_access user
  end

  describe "send" do
    it "should send email" do
      message_delivery = instance_double(ActionMailer::MessageDelivery)
      expect(OpenMailer).to receive(:send_feedback).with(user, "Hello world", "https://sample.com/abc").and_return message_delivery
      expect(message_delivery).to receive(:deliver_later)
      post :send_feedback, url: 'https://sample.com/abc', message:'Hello world'
      expect(response).to be_success
    end
  end
end