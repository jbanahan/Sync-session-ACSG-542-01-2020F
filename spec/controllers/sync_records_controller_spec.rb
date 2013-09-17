require 'spec_helper'

describe SyncRecordsController do

  before :each do
    @user = Factory(:master_user,:email=>'a@example.com', :product_view => true)
    activate_authlogic
    UserSession.create! @user
  end

  it "should mark a sync record to be resent" do
    p = Factory(:product)
    p.sync_records.create! sent_at: Time.zone.now, confirmed_at: Time.zone.now + 1.minute, confirmation_file_name: "file.txt", failure_message: "Message!", :trading_partner => "Testing"

    post :resend, :id=>p.sync_records.first.id
    response.should redirect_to request.referrer

    p.reload
    Product.scoped.need_sync("Testing").all.include?(p).should be_true

    sr = p.sync_records.first
    sr.sent_at.should be_nil
    sr.confirmed_at.should be_nil
    sr.confirmation_file_name.should be_nil
    sr.failure_message.should be_nil

    flash[:notices].include?("This record will be resent the next time the sync program is executed for Testing.").should be_true
  end

  it "should not allow users without access" do
    @user.product_view = false
    @user.save!

    p = Factory(:product)
    p.sync_records.create! sent_at: Time.zone.now, confirmed_at: Time.zone.now + 1.minute, confirmation_file_name: "file.txt", failure_message: "Message!", :trading_partner => "Testing"

    post :resend, :id=>p.sync_records.first.id
    response.should redirect_to request.referrer

    flash[:errors].include?("You do not have permission to resend this record.").should be_true
  end
end