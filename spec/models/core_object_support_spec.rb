require 'spec_helper'

describe CoreObjectSupport do
  describe "find_by_custom_value" do
    it "shuould find by value" do
      cd = Factory(:custom_definition,module_type:'Product')
      p = Factory(:product)
      p.update_custom_value!(cd,'myuid')
      expect(Product.find_by_custom_value(cd,'myuid')).to eq p
      expect(Product.find_by_custom_value(cd,'def')).to be_nil
    end
  end
  describe "process_linked_attachments" do

    let! (:order_rule) { LinkableAttachmentImportRule.create!(:path=>'X',:model_field_uid=>'ord_ord_num') }

    it "is referenced in save callback " do 
      inst = nil
      expect_any_instance_of(Order).to receive(:process_linked_attachments) do |i|
        inst = i
      end

      order = Order.create!(:order_number=>'onum',:vendor_id=>Factory(:company,:vendor=>true).id)

      expect(inst).to eq order
    end

    it "should kick off job if import rule exists for this module" do
      klass, id = nil
      expect(LinkedAttachment).to receive(:delay).with(priority: 600).and_return LinkedAttachment
      expect(LinkedAttachment).to receive(:create_from_attachable_by_class_and_id) do |k, i|
        klass = k
        id = i
      end

      Order.new(:order_number=>'onum').process_linked_attachments
    end

    it "should not kick off job if only import rules are for another module" do
      expect(LinkedAttachment).not_to receive(:delay)
      Product.new(unique_identifier: "PLA").process_linked_attachments
    end
    it "should not kick off job if don't process linked attachments = true" do
      expect(LinkedAttachment).not_to receive(:delay)
      o = Order.new(:order_number=>'onum')
      o.dont_process_linked_attachments = true
      o.process_linked_attachments
    end
  end
  describe "need_sync" do
    before :each do
      @tp = "tradingpartner"
      @p = Factory(:product)
    end
    it "should find products with no sync records" do
      ns = Product.need_sync @tp
      expect(ns.size).to eq(1)
      expect(ns.first).to eq(@p)
    end
    it "should find product with a sync record for a different trading partner" do
      @p.sync_records.create!(:trading_partner=>'other',:sent_at=>1.minute.ago,:confirmed_at=>10.seconds.ago)
      Product.connection.execute("UPDATE products SET updated_at = NOW() - INTERVAL 1 DAY;")
      ns = Product.need_sync @tp
      expect(ns.size).to eq(1)
      expect(ns.first).to eq(@p)
    end
    it "should find products with changed records that haven't been sent" do
      @p.sync_records.create!(:trading_partner=>@tp)
      Product.connection.execute("UPDATE products SET updated_at = NOW() - INTERVAL 1 DAY;") #hasn't been changed since last send
      ns = Product.need_sync @tp
      expect(ns.size).to eq(1)
      expect(ns.first).to eq(@p)
    end
    it "should find products sent but not confirmed" do
      @p.sync_records.create!(:trading_partner=>@tp,:sent_at=>1.minute.ago,:confirmed_at=>nil)
      Product.connection.execute("UPDATE products SET updated_at = NOW() - INTERVAL 1 DAY;") #hasn't been changed since last send
      ns = Product.need_sync @tp
      expect(ns.size).to eq(1)
      expect(ns.first).to eq(@p)
    end
    it "should find products sent after last confirmation" do
      @p.sync_records.create!(:trading_partner=>@tp,:sent_at=>1.minute.ago,:confirmed_at=>2.minutes.ago)
      Product.connection.execute("UPDATE products SET updated_at = NOW() - INTERVAL 1 DAY;") #hasn't been changed since last send
      ns = Product.need_sync @tp
      expect(ns.size).to eq(1)
      expect(ns.first).to eq(@p)
    end
    it "should find products changed after sent" do
      @p.sync_records.create!(:trading_partner=>@tp,:sent_at=>1.minute.ago,:confirmed_at=>10.seconds.ago)
      ns = Product.need_sync @tp
      expect(ns.size).to eq(1)
      expect(ns.first).to eq(@p)
    end
    it "should not find product where updated_at < sent < confirmed" do
      @p.sync_records.create!(:trading_partner=>@tp,:sent_at=>1.minute.ago,:confirmed_at=>10.seconds.ago)
      Product.connection.execute("UPDATE products SET updated_at = NOW() - INTERVAL 1 DAY;")
      ns = Product.need_sync @tp
      expect(ns).to be_empty
    end
    it "should not find products based on additional where clauses" do
      dont_find = Factory(:product,:unique_identifier=>"DONTFINDME")
      sc = SearchCriterion.new(:model_field_uid=>'prod_uid',:operator=>'nq',:value=>dont_find.unique_identifier)
      ns = sc.apply Product.need_sync @tp
      expect(ns.size).to eq(1)
      expect(ns.first).to eq(@p)
    end
    it "should not find products updated before ignore_updates_before" do
      dont_find = Factory(:product,unique_identifier:'DONTFINDME',updated_at:1.day.ago)
      dont_find.sync_records.create!(trading_partner:@tp,sent_at:2.days.ago,ignore_updates_before:1.hour.ago)
      expect(Product.need_sync(@tp).to_a).to eq [@p]
    end
  end
  describe "view_url" do
    it "should make url based on request_host" do
      allow_any_instance_of(MasterSetup).to receive(:request_host).and_return "x.y.z"
      p = Factory(:product)
      expect(p.view_url).to eq XlsMaker.excel_url("/products/#{p.id}")
    end
    it "should raise exception if id not set" do
      expect{Product.new.view_url}.to raise_error(/view_url/)
    end
  end
  describe "excel_url" do
    it "should make url based on request_host with class method" do
      allow_any_instance_of(MasterSetup).to receive(:request_host).and_return "x.y.z"
      expect(Product.excel_url 1).to eq XlsMaker.excel_url("/products/1")
    end
  end
  describe "relative_url" do
    it "should make url without host" do
      p = Factory(:product)
      expect(p.relative_url).to eq("/products/#{p.id}")
    end

    it "should make url without host with class method" do
      expect(Product.relative_url 1).to eq "/products/1"
    end
  end
  describe "all_attachments" do
    it "should sort by attachment type then attached file name then id" do
      p = Factory(:product)
      third = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A")
      second = p.attachments.create!(:attachment_type=>"A",:attached_file_name=>"R")
      first = p.attachments.create!(:attachment_type=>"A",:attached_file_name=>"Q")
      fourth = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A")
      r = p.all_attachments
      expect(r[0]).to eq(first)
      expect(r[1]).to eq(second)
      expect(r[2]).to eq(third)
      expect(r[3]).to eq(fourth)
    end
  end
  describe "clear_attributes" do
    it "it sets every attribute to nil except those specified, timestamps, primary key, foreign keys" do
      e = Factory(:entry)
      ci = Factory(:commercial_invoice, entry: e, invoice_number: "123456", currency: "USD", created_at: DateTime.new(2018,1,1))
      ci.clear_attributes([:currency])
      ci.save!
      expect(ci.invoice_number).to be_nil
      expect(ci.currency).to eq "USD"
      expect(ci.entry).to eq e
      expect(ci.created_at).to eq DateTime.new(2018,1,1)
    end
  end

  describe "options_for_attachments_select" do
    it "Returns an array of items used to create a select dropdown list starting with nil valued option" do
      p = Factory(:order)
      att1 = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A",:attached_content_type=>"application/pdf")
      att2 = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"B",:attached_content_type=>"image/png")
      expect(p.options_for_attachments_select "application/pdf").to eq [["Select an option", "nil"], [att1.attachment_type + " - " + att1.attached_file_name,att1.id]]
    end

    it "Does not return an array of items if none are appropriate" do
      p = Factory(:order)
      att1 = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A",:attached_content_type=>"image/jpeg")
      att2 = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"B",:attached_content_type=>"image/png")
      expect(p.options_for_attachments_select "application/pdf").to eq [["No appopriate attachments exist.", "nil"]]
    end

    it "handles missing attachment_types" do
      p = Factory(:order)
      att1 = p.attachments.create!(:attached_file_name=>"A",:attached_content_type=>"image/jpeg")
      expect(p.options_for_attachments_select "image/jpeg").to eq [["Select an option", "nil"], [att1.attached_file_name,att1.id]]
    end
  end

  context "TestCoreObject" do
    before :each do
      class TestCoreObject < ActiveRecord::Base
        include CoreObjectSupport

        def self.name
          "Class' Name"
        end
      end
    end

    describe "need_sync_join_clause" do
      it "should generate sql for joining to sync_records table" do
        sql = TestCoreObject.need_sync_join_clause "Trading's Partner"
        expect(sql).to include ".syncable_type = 'Class\\' Name'"
        expect(sql).to include "sync_records.syncable_id = test_core_objects"
        expect(sql).to include "sync_records.trading_partner = 'Trading\\'s Partner'"
      end
    end

    describe "need_sync_where_clause" do
      it "should generate sql for joining to sync_records table" do
        sql = TestCoreObject.need_sync_where_clause
        expect(sql).to include "test_core_objects.updated_at"
      end
    end

    describe "has_never_been_synced_where_clause" do
      it "finds objects that have never been synced" do
        entry = Factory(:entry)
        found = Entry.joins(Entry.need_sync_join_clause('partner')).where(Entry.has_never_been_synced_where_clause).first
        expect(found).to eq entry
      end

      it "finds objects that have been synced but have a blank sent_at" do
        entry = Factory(:entry)
        entry.sync_records.create! trading_partner: 'partner'
        found = Entry.joins(Entry.need_sync_join_clause('partner')).where(Entry.has_never_been_synced_where_clause).first
        expect(found).to eq entry
      end

      it "does not find objects that have a sync record with a sent_at value" do
        entry = Factory(:entry)
        entry.sync_records.create! trading_partner: 'partner', sent_at: Time.zone.now
        found = Entry.joins(Entry.need_sync_join_clause('partner')).where(Entry.has_never_been_synced_where_clause).first
        expect(found).to be_nil
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

  describe "attachment_filenames" do
    it "lists all attachments associated with a core object in alphabetical order" do
      p = Factory(:product)
      first = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A")
      second = p.attachments.create!(:attachment_type=>"A",:attached_file_name=>"R")
      third = p.attachments.create!(:attachment_type=>"A", :attached_file_name=>"R")
      dup = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"B")

      expect(p.attachment_filenames).to eq ["A", "B", "R"]
    end

    it "returns blank array if no attachment types" do
      p = Factory(:product)
      expect(p.attachment_filenames).to eq []
    end
  end

  context "business rules" do
    let(:template) { Factory(:business_validation_template, private: false) }
    let(:priv_template) { Factory(:business_validation_template, private: true) }
    let(:entry) { Factory(:entry) }

    describe "business_rules_state" do
      before do
        entry.business_validation_results << Factory(:business_validation_result, state: "Fail", business_validation_template: priv_template)
        entry.business_validation_results << Factory(:business_validation_result, state: "Review", business_validation_template: template)
        entry.business_validation_results << Factory(:business_validation_result, state: "Pass", business_validation_template: template)
      end
      
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

      it "returns 'worst' state of all rule results" do
        expect(entry.business_rules_state).to eq "Fail"
      end

      it "returns 'worst' state of all rule results except private ones" do
        expect(entry.business_rules_state(include_private: false)).to eq "Review"
      end
    end

    describe "business_rules_state_for_user" do
      let(:u) { Factory(:user, company: Factory(:company, show_business_rules: true)) }
      
      before do
        entry.business_validation_results << Factory(:business_validation_result, state: "Fail", business_validation_template: priv_template)
        entry.business_validation_results << Factory(:business_validation_result, state: "Review", business_validation_template: template)
        entry.business_validation_results << Factory(:business_validation_result, state: "Pass", business_validation_template: template)
      end

      it "returns 'worst' state of all rule results for user with full privileges" do
        expect(u).to receive(:view_all_business_validation_results?).and_return true
        expect(entry.business_rules_state_for_user(u)).to eq "Fail"
      end

      it "returns 'worst' state of all rule results except private ones for user without full privileges" do
        expect(u).to receive(:view_all_business_validation_results?).and_return false
        expect(entry.business_rules_state_for_user(u)).to eq "Review"
      end
    end

    describe "business_rules" do
      def prep_results state
        entry.business_validation_results << Factory(:business_validation_rule_result, state: state, business_validation_rule: Factory(:business_validation_rule, name: "Test", business_validation_template: priv_template)).business_validation_result
        entry.business_validation_results << Factory(:business_validation_rule_result, state: state, business_validation_rule: Factory(:business_validation_rule, name: "Test", business_validation_template: priv_template)).business_validation_result
        entry.business_validation_results << Factory(:business_validation_rule_result, state: state, business_validation_rule: Factory(:business_validation_rule, name: "A Test", business_validation_template: template)).business_validation_result
        entry.business_validation_results << Factory(:business_validation_rule_result, state: "Pass", business_validation_rule: Factory(:business_validation_rule, name: "Another Test", business_validation_template: template)).business_validation_result
      end
      
      context "failed" do
        before { prep_results "Fail" }

        it "lists all failed business rules for an object" do
          expect(entry.business_rules("Fail")).to eq ["A Test", "Test"]
        end
        
        it "lists non-private failed business rules for an object" do
          expect(entry.business_rules("Fail", include_private: false)).to eq ["A Test"]
        end
      end

      context "review" do
        before { prep_results "Review" }

        it "lists all 'review' business rules for an object" do
          expect(entry.business_rules("Review")).to eq ["A Test", "Test"]
        end
        
        it "lists non-private 'review' business rules for an object" do
          expect(entry.business_rules("Review", include_private: false)).to eq ["A Test"]
        end
      end
    end

    describe "business_rule_templates" do
      def prep_results state
        Factory(:business_validation_result, validatable: entry, business_validation_template: Factory(:business_validation_template, module_type: "Entry", name: "bvt 2", private: false), state: state)
        Factory(:business_validation_result, validatable: entry, business_validation_template: Factory(:business_validation_template, module_type: "Entry", name: "bvt 3", private: false,), state: "Pass")
        Factory(:business_validation_result, validatable: entry, business_validation_template: Factory(:business_validation_template, module_type: "Entry", name: "bvt 1", private: true), state: state)
      end

      context "failed" do
        before { prep_results "Fail" }

        it "lists the templates of all failed business rules for an object" do
          expect(entry.business_rule_templates("Fail")).to eq ["bvt 1", "bvt 2"]
        end
        
        it "lists the templates of all non-private failed business rules for an object" do
          expect(entry.business_rule_templates("Fail", include_private: false)).to eq ["bvt 2"]
        end
      end

      context "review" do
        before { prep_results "Review" }

        it "lists the templates of all 'review' business rules for an object" do
          expect(entry.business_rule_templates("Review")).to eq ["bvt 1", "bvt 2"]
        end
        
        it "lists the templates of all non-private 'review' business rules for an object" do
          expect(entry.business_rule_templates("Review", include_private: false)).to eq ["bvt 2"]
        end
      end
    end

    describe "can_run_validations?" do
      before :each do
        @u = Factory(:user)
        allow(@u).to receive(:edit_business_validation_rule_results?).and_return true
        @ent = Factory(:entry)

        @bvrr_1 = Factory(:business_validation_rule_result)
        bvr_1 = @bvrr_1.business_validation_result
        bvr_1.validatable = @ent; bvr_1.save!

        @bvrr_2 = Factory(:business_validation_rule_result)
        bvr_2 = @bvrr_2.business_validation_result
        bvr_2.validatable = @ent; bvr_2.save!
      end

      it "returns true if user has permission to edit all rule results associated with object" do
        expect(@ent.can_run_validations? @u).to eq true
      end

      it "returns false if there are any rule results user doesn't have permission to edit" do
        bvru_1 = @bvrr_1.business_validation_rule
        bvru_1.group = Factory(:group); bvru_1.save!
        expect(@ent.can_run_validations? @u).to eq false
      end
    end
  end
  
  describe "split_newline_values" do
    let(:ent) { Factory(:entry) }

    it "splits a string containing newline values into an array" do
      res = ent.split_newline_values(" a
                b \n  c  ")
      expect(res.length).to eq(3)
      expect(res[0]).to eq(' a')
      expect(res[1]).to eq('b ')
      expect(res[2]).to eq('c  ')
    end

    it "handles nil value" do
      res = ent.split_newline_values(nil)
      expect(res).to_not be_nil
      expect(res.length).to eq(0)
    end

    it "works at class level" do
      res = Entry.split_newline_values(" a
                b \n  c  ")
      expect(res.length).to eq(3)
      expect(res[0]).to eq(' a')
      expect(res[1]).to eq('b ')
      expect(res[2]).to eq('c  ')
    end
  end
end
