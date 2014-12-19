require 'spec_helper'

describe CoreObjectSupport do
  describe :workflow_instances do
    it "should have many workflow instances" do
      o = Factory(:order)
      2.times {|x| Factory(:workflow_instance,base_object:o)}
      o.reload
      expect(o.workflow_instances.count).to eq 2
    end
  end
  describe :business_rules_state do
    it "should set worst state from business_validation_results" do
      ent = Factory(:entry)
      bv1 = Factory(:business_validation_result,state:'Pass')
      bv2 = Factory(:business_validation_result,state:'Fail')
      [bv1,bv2].each do |b|
        b.validatable = ent
        b.save!
      end
      expect(ent.business_rules_state).to eq 'Fail'
    end
  end
  describe :process_linked_attachments do
    before :each do
      LinkableAttachmentImportRule.create!(:path=>'X',:model_field_uid=>'ord_ord_num')
      @ws = Delayed::Worker.delay_jobs
      Delayed::Worker.delay_jobs = false
    end
    after :each do
      Delayed::Worker.delay_jobs = @ws
    end
    it "should kick off job if import rule exists for this module" do
      LinkedAttachment.should_receive(:create_from_attachable_by_class_and_id).with(Order,instance_of(Fixnum))
      Order.create!(:order_number=>'onum',:vendor_id=>Factory(:company,:vendor=>true).id)
    end
    it "should not kick off job if only import rules are for another module" do
      LinkedAttachment.should_not_receive(:create_from_attachable_by_class_and_id)
      Product.create!(:unique_identifier=>"PLA")
    end
    it "should not kick off job if don't process linked attachments = true" do
      LinkedAttachment.should_not_receive(:create_from_attachable_by_class_and_id)
      o = Order.new(order_number:'onum',vendor_id:Factory(:company,:vendor=>true).id)
      o.dont_process_linked_attachments = true
      o.save!
    end
  end
  describe :need_sync do
    before :each do
      @tp = "tradingpartner"
      @p = Factory(:product)
    end
    it "should find products with no sync records" do
      ns = Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should find product with a sync record for a different trading partner" do
      @p.sync_records.create!(:trading_partner=>'other',:sent_at=>1.minute.ago,:confirmed_at=>10.seconds.ago)
      Product.connection.execute("UPDATE products SET updated_at = NOW() - INTERVAL 1 DAY;")
      ns = Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should find products with changed records that haven't been sent" do
      @p.sync_records.create!(:trading_partner=>@tp)
      Product.connection.execute("UPDATE products SET updated_at = NOW() - INTERVAL 1 DAY;") #hasn't been changed since last send
      ns = Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should find products sent but not confirmed" do
      @p.sync_records.create!(:trading_partner=>@tp,:sent_at=>1.minute.ago,:confirmed_at=>nil)
      Product.connection.execute("UPDATE products SET updated_at = NOW() - INTERVAL 1 DAY;") #hasn't been changed since last send
      ns = Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should find products sent after last confirmation" do
      @p.sync_records.create!(:trading_partner=>@tp,:sent_at=>1.minute.ago,:confirmed_at=>2.minutes.ago)
      Product.connection.execute("UPDATE products SET updated_at = NOW() - INTERVAL 1 DAY;") #hasn't been changed since last send
      ns = Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should find products changed after sent" do
      @p.sync_records.create!(:trading_partner=>@tp,:sent_at=>1.minute.ago,:confirmed_at=>10.seconds.ago)
      ns = Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should not find product where updated_at < sent < confirmed" do
      @p.sync_records.create!(:trading_partner=>@tp,:sent_at=>1.minute.ago,:confirmed_at=>10.seconds.ago)
      Product.connection.execute("UPDATE products SET updated_at = NOW() - INTERVAL 1 DAY;")
      ns = Product.need_sync @tp
      ns.should be_empty
    end
    it "should not find products based on additional where clauses" do
      dont_find = Factory(:product,:unique_identifier=>"DONTFINDME")
      sc = SearchCriterion.new(:model_field_uid=>'prod_uid',:operator=>'nq',:value=>dont_find.unique_identifier)
      ns = sc.apply Product.need_sync @tp
      ns.size.should == 1
      ns.first.should == @p
    end
    it "should not find products updated before ignore_updates_before" do
      dont_find = Factory(:product,unique_identifier:'DONTFINDME',updated_at:1.day.ago)
      dont_find.sync_records.create!(trading_partner:@tp,sent_at:2.days.ago,ignore_updates_before:1.hour.ago)
      expect(Product.need_sync(@tp).to_a).to eq [@p]
    end
  end
  describe :view_url do
    it "should make url based on request_host" do
      MasterSetup.any_instance.stub(:request_host).and_return "x.y.z"
      p = Factory(:product)
      expect(p.view_url).to eq XlsMaker.excel_url("/products/#{p.id}")
    end
    it "should raise exception if id not set" do
      expect{Product.new.view_url}.to raise_error
    end
  end
  describe "excel_url" do
    it "should make url based on request_host with class method" do
      MasterSetup.any_instance.stub(:request_host).and_return "x.y.z"
      expect(Product.excel_url 1).to eq XlsMaker.excel_url("/products/1")
    end
  end
  describe :relative_url do
    it "should make url without host" do
      p = Factory(:product)
      p.relative_url.should == "/products/#{p.id}"
    end

    it "should make url without host with class method" do
      expect(Product.relative_url 1).to eq "/products/1"
    end 
  end
  describe :all_attachments do
    it "should sort by attachment type then attached file name then id" do
      p = Factory(:product)
      third = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A")
      second = p.attachments.create!(:attachment_type=>"A",:attached_file_name=>"R")
      first = p.attachments.create!(:attachment_type=>"A",:attached_file_name=>"Q")
      fourth = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A")
      r = p.all_attachments
      r[0].should == first
      r[1].should == second
      r[2].should == third
      r[3].should == fourth
    end
  end

  context :TestCoreObject do
    before :each do
      class TestCoreObject < ActiveRecord::Base
        include CoreObjectSupport

        def self.name 
          "Class' Name"
        end
      end
    end

    describe :need_sync_join_clause do
      it "should generate sql for joining to sync_records table" do
        sql = TestCoreObject.need_sync_join_clause "Trading's Partner"
        sql.should include ".syncable_type = 'Class\\' Name'"
        sql.should include "sync_records.syncable_id = test_core_objects"
        sql.should include "sync_records.trading_partner = 'Trading\\'s Partner'"
      end
    end

    describe :need_sync_where_clause do
      it "should generate sql for joining to sync_records table" do
        sql = TestCoreObject.need_sync_where_clause
        sql.should include "test_core_objects.updated_at"
      end
    end
  end
  
  describe "attachment_types" do
    it "lists all attachments associated with a core object in alphabetical order" do
      p = Factory(:product)
      first = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A")
      second = p.attachments.create!(:attachment_type=>"A",:attached_file_name=>"R")
      # Skip blank/null ones
      third = p.attachments.create!(:attached_file_name=>"R")
      third = p.attachments.create!(:attachment_type=>"       ", :attached_file_name=>"R")
      # Skip duplicates
      dup = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"B")

      expect(p.attachment_types).to eq ["A", "B"]
    end

    it "returns blank array if no attachment types" do
      p = Factory(:product)
      expect(p.attachment_types).to eq []
    end
  end

  describe "failed_business_rules" do
    it "lists all failed business rules for an object" do
      entry = Factory(:entry)
      entry.business_validation_results << Factory(:business_validation_rule_result, state: "Fail", business_validation_rule: Factory(:business_validation_rule, name: "Test")).business_validation_result
      entry.business_validation_results << Factory(:business_validation_rule_result, state: "Fail", business_validation_rule: Factory(:business_validation_rule, name: "Test")).business_validation_result
      entry.business_validation_results << Factory(:business_validation_rule_result, state: "Fail", business_validation_rule: Factory(:business_validation_rule, name: "A Test")).business_validation_result
      entry.business_validation_results << Factory(:business_validation_rule_result, state: "Pass", business_validation_rule: Factory(:business_validation_rule, name: "Another Test")).business_validation_result
      
      expect(entry.failed_business_rules).to eq ["A Test", "Test"]
    end
  end
end
