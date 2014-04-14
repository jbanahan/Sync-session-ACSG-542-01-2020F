require 'spec_helper'

describe OpenChain::ProjectDeliverableProcessor do

  before :each do
    / Set up the 'ecosystem':
      User 1 is assigned PD1 (high), PD2 (low), and PD3 (high)
      User 2 is assigned PD3 (high)
      User 3 is assigned PD4 (medium) /

    @u1 = Factory(:user, id: 1000, email: "user1@email.com")
    @u2 = Factory(:user, id: 2000, email: "user2@email.com")
    @u3 = Factory(:user, id: 3000, email: "user3@email.com")

    @pd1 = Factory(:project_deliverable, assigned_to: @u1, priority: "High", id: 1001, description: "PD1 Description")
    @pd2 = Factory(:project_deliverable, assigned_to: @u1, priority: "Low", id: 1002)
    @pd3 = Factory(:project_deliverable, assigned_to: @u1, priority: "High", id: 1003, description: "PD3 Description")
    @pd4 = Factory(:project_deliverable, assigned_to: @u2, priority: "High", id: 2001, description: "PD4 Description")
    @pd5 = Factory(:project_deliverable, assigned_to: @u3, priority: "Medium", id: 3001)

    @p = OpenChain::ProjectDeliverableProcessor.new
  end

  describe :run_schedulable do

    it 'should return the correct hash for the ecosystem' do
      @p.run_schedulable.should == {1000=>[1001, 1003], 2000=>[2001]}
    end

    it 'should call create_emails_from_hash with the correct hash' do
      OpenChain::ProjectDeliverableProcessor.any_instance.should_receive(:create_emails_from_hash).exactly(1).times.with({1000=>[1001, 1003], 2000=>[2001]})
      @p.run_schedulable
    end

  end

  describe :fill_hash_values do

    it 'should fill the hash with the correct information' do
      blank_hash = {}
      @p.fill_hash_values(blank_hash).should == {1000=>[1001, 1003], 2000=>[2001]}
    end

  end

  describe :add_to_hash do

    it 'should make a new key/value pair if the key does not yet exist' do
      start_hash = {"k1" => ["v1"], "k2" => ["v2"]}
      @p.add_to_hash(start_hash, "k3", "v3").should == {"k1" => ["v1"], "k2" => ["v2"], "k3" => ["v3"]}
    end

    it 'should extend the value list if the key does already exist' do
      start_hash = {"k1" => ["v1"], "k2" => ["v2"]}
      @p.add_to_hash(start_hash, "k2", "v3").should == {"k1" => ["v1"], "k2" => ["v2", "v3"]}
    end

  end

  describe :create_emails_from_hash do

    it 'should send emails to correct users with correct projects' do
      @p.run_schedulable
      m = OpenMailer.deliveries.pop
      m.to.first.should == "user2@email.com"
      m.body.should match(/PD4 Description/)

      m = OpenMailer.deliveries.pop
      m.to.first.should == "user1@email.com"
      m.body.should match(/PD1 Description/)
      m.body.should match(/PD3 Description/)
    end

  end
end