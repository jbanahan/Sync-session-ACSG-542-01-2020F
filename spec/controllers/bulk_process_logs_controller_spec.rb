describe BulkProcessLogsController do

  before :each do
    @u = FactoryBot(:user)
    sign_in_as @u

    @log = BulkProcessLog.create! :user => @u
    @log.change_records.create!(:record_sequence_number => 1).add_message("Testing").save!
  end

  describe 'show' do

    it "should show log to users that can view" do
      get :show, :id=>@log.id
      expect(response).to be_success

      expect(assigns(:bulk_process_log).id).to eq @log.id
      expect(assigns(:change_records).first.id).to eq @log.change_records.first.id
    end

    it "should not show log id to users that can't view" do
      expect_any_instance_of(BulkProcessLog).to receive(:can_view?).and_return false

      get :show, :id=>@log.id
      expect(response).to be_redirect
    end
  end

  describe "messages" do
    it "should return json messages" do
      get :messages, :id=>@log.id, :cr_id=>@log.change_records.first.id, :format=>:json

      expect(response).to be_success
      r = JSON.parse response.body
      expect(r).to eq ["Testing"]
    end

    it "should not show messages to users that can't view" do
      expect_any_instance_of(BulkProcessLog).to receive(:can_view?).and_return false

      get :messages, :id=>@log.id, :cr_id=>@log.change_records.first.id, :format=>:json
      expect(response).to be_redirect
    end
  end
end
