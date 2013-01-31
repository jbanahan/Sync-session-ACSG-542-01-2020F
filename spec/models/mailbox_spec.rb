require 'spec_helper'

describe Mailbox do
  describe "assignment breakdown" do
    before :each do 
      @m = Factory(:mailbox)
      @u1 = Factory(:user)
      @u2 = Factory(:user)
      @e1a = Factory(:email,:assigned_to=>@u1,:mailbox=>@m)
      @e1b = Factory(:email,:assigned_to=>@u1,:mailbox=>@m)
      @e1c = Factory(:email,:assigned_to=>@u1,:mailbox=>@m,:archived=>true)
      @e2a = Factory(:email,:assigned_to=>@u2,:mailbox=>@m)
      @e_unassigned = Factory(:email,:mailbox=>@m)
      @dont_find = Factory(:email,:assigned_to=>@u1)
    end
    it "should return a hash with assignment count by email" do
      r = @m.assignment_breakdown false
      r[@u1].should == 2
      r[nil].should == 1
      r[@u2].should == 1
    end
    it "should return archived message breakdown" do
      r = @m.assignment_breakdown true
      r.should have(1).entry
      r[@u1].should == 1
    end
  end
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
