require 'spec_helper'

describe SentEmail do
  before(:each) do
    @user = Factory(:user)
    @email_1 = SentEmail.create
    @email_2 = SentEmail.create
  end

  describe :can_view? do
    it "grants permission to sys-admins" do
      expect(@email_1.can_view? @user).to be_falsey
      
      @user.sys_admin = true
      expect(@email_1.can_view? @user).to be_truthy
    end
  end

  describe "self.find_can_view" do
    it "shows all records to sys-admins" do
      expect(SentEmail.find_can_view @user).to be_nil
      
      @user.sys_admin = true
      expect((SentEmail.find_can_view @user).count).to eq 2
    end
  end
end
