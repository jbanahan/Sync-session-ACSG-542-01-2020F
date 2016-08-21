require 'spec_helper'

describe SyncRecordsController do

  before :each do
    @user = Factory(:master_user,:email=>'a@example.com', :product_view => true)

    sign_in_as @user
  end

  it "should mark a sync record to be resent" do
    p = Factory(:product)
    p.sync_records.create! sent_at: Time.zone.now, confirmed_at: Time.zone.now + 1.minute, confirmation_file_name: "file.txt", failure_message: "Message!", :trading_partner => "Testing", :fingerprint => "fingerprint", ignore_updates_before: Time.zone.now

    post :resend, :id=>p.sync_records.first.id
    expect(response).to redirect_to request.referrer

    p.reload
    expect(Product.scoped.need_sync("Testing").all.include?(p)).to be_truthy

    sr = p.sync_records.first
    expect(sr.sent_at).to be_nil
    expect(sr.confirmed_at).to be_nil
    expect(sr.confirmation_file_name).to be_nil
    expect(sr.failure_message).to be_nil
    expect(sr.fingerprint).to be_nil
    expect(sr.ignore_updates_before).to be_nil

    expect(flash[:notices].include?("This record will be resent the next time the sync program is executed for Testing.")).to be_truthy
  end

  it "should not allow users without access" do
    @user.product_view = false
    @user.save!

    p = Factory(:product)
    p.sync_records.create! sent_at: Time.zone.now, confirmed_at: Time.zone.now + 1.minute, confirmation_file_name: "file.txt", failure_message: "Message!", :trading_partner => "Testing"

    post :resend, :id=>p.sync_records.first.id
    expect(response).to redirect_to request.referrer

    expect(flash[:errors].include?("You do not have permission to resend this record.")).to be_truthy
  end
end