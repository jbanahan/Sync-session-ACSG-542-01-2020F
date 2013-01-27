require 'spec_helper'

describe Mailbox do
  describe "permissions" do
    before :each do
      @m = Factory(:mailbox)
      @u = Factory(:user)
    end
    it "should allow if user is assigned to mailbox" do
      @m.users << @u
      @m.can_view?(@u).should be_true
      @m.can_edit?(@u).should be_true
    end
    it "should allow if user is sys_admin" do
      @u.sys_admin = true
      @u.save!
      @m.can_view?(@u).should be_true
      @m.can_edit?(@u).should be_true
    end
    it "should disallow if user is not assigned to mailbox and not sys_admin" do
      @m.can_view?(@u).should be_false
      @m.can_edit?(@u).should be_false
    end
  end
end
