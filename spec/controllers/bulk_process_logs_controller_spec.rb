require 'spec_helper'

describe BulkProcessLogsController do

  before :each do
    @u = Factory(:user)
    activate_authlogic
    UserSession.create! @u

    @log = BulkProcessLog.create! :user => @u
    @log.change_records.create!(:record_sequence_number => 1).add_message("Testing").save!
  end

  describe 'show' do

    it "should show log to users that can view" do
      get :show, :id=>@log.id
      response.should be_success

      assigns(:bulk_process_log).id.should eq @log.id
      assigns(:change_records).first.id.should eq @log.change_records.first.id
    end

    it "should not show log id to users that can't view" do
      BulkProcessLog.any_instance.should_receive(:can_view?).and_return false

      get :show, :id=>@log.id
      response.should be_redirect
    end
  end

  describe "messages" do
    it "should return json messages" do
      get :messages, :id=>@log.id, :cr_id=>@log.change_records.first.id, :format=>:json

      response.should be_success
      r = JSON.parse response.body
      r.should eq ["Testing"]
    end

    it "should not show messages to users that can't view" do
      BulkProcessLog.any_instance.should_receive(:can_view?).and_return false

      get :messages, :id=>@log.id, :cr_id=>@log.change_records.first.id, :format=>:json
      response.should be_redirect
    end
  end
end