require 'spec_helper'
require 'spreadsheet'

describe CustomReportBillingStatementByPo do
  
  context "Class Methods" do

    before :each do
      @r = CustomReportBillingStatementByPo
    end
    
    it "should only allow broker invoice users to view" do
      user = double("user")
      allow(user).to receive(:view_broker_invoices?).and_return(true)
      expect(@r.can_view?(user)).to be_truthy

      allow(user).to receive(:view_broker_invoices?).and_return(false)
      expect(@r.can_view?(user)).to be_falsey
    end

    it "should return broker invoice column fields and criterion fields" do
      user = double("user")
      mf = {:mf => ModelField.new(1, :mf, CoreModule::BROKER_INVOICE, "Test")}
      expect(CoreModule::BROKER_INVOICE).to receive(:model_fields).twice.with(user).and_return(mf)

      expect(@r.column_fields_available(user)).to eq(mf.values)
      expect(@r.criterion_fields_available(user)).to eq(mf.values)
    end
  end

  context "run report" do

    before :each do
      @user = Factory(:master_user)
      allow(@user).to receive(:view_broker_invoices?).and_return(true)
      @invoice = Factory(:broker_invoice, :suffix=>"Test", :invoice_total=>"100", :invoice_date=>Date.parse("2013-01-01"),:invoice_number=>'ZZZ')
      @invoice.entry.update_attributes(:broker_reference=>"Entry", :po_numbers=>"1\n 2\n 3")
      @invoice.broker_invoice_lines.create!(:charge_description => "A", :charge_amount=>1)
      @invoice.broker_invoice_lines.create!(:charge_description => "B", :charge_amount=>2)
      @entry = @invoice.entry
      @report = CustomReportBillingStatementByPo.create!
    end

    it "should split the invoice into 3 po lines and prorate the invoice amount across each line" do
      @report.search_columns.create!(:model_field_uid=>:bi_brok_ref, :rank=>1)
      @report.search_columns.create!(:model_field_uid=>:bi_ent_po_numbers, :rank=>2)
      @report.search_criterions.create!(:model_field_uid=>:bi_brok_ref, :operator=>"eq", :value=>@entry.broker_reference) 

      r = @report.to_arrays @user
      #4 rows..1 header, 3 PO lines
      expect(r.length).to eq(4)
      row = r[0]
      expect(row).to eq(["Invoice Number", "Invoice Date", "Invoice Total", "PO Number", ModelField.find_by_uid(:bi_brok_ref).label, ModelField.find_by_uid(:bi_ent_po_numbers).label])

      row = r[1]
      expect(row).to eq(["ZZZ", Date.parse("2013-01-01"), BigDecimal.new("33.33"), "1", "Entry", "1\n 2\n 3"])

      row = r[2]
      expect(row).to eq(["ZZZ", Date.parse("2013-01-01"), BigDecimal.new("33.33"), "2", "Entry", "1\n 2\n 3"])

      row = r[3]
      expect(row).to eq(["ZZZ", Date.parse("2013-01-01"), BigDecimal.new("33.34"), "3", "Entry", "1\n 2\n 3"])
    end

    it "should use the correct rounding mode when determining pro-rated PO values" do
      # There was a bug in the report where the proration amount should have been truncating the rounded value at 2
      # decimal places, instead, it was rounding up. .ie .995 rounded to 1 instead of .99
      @invoice.update_attributes(:invoice_total=>BigDecimal("99.99"))
      @invoice.entry.update_attributes(:broker_reference=>"Entry", :po_numbers=>"1\n 2")
      @report.search_columns.create!(:model_field_uid=>:bi_brok_ref, :rank=>1)
      @report.search_columns.create!(:model_field_uid=>:bi_ent_po_numbers, :rank=>2)
      @report.search_criterions.create!(:model_field_uid=>:bi_brok_ref, :operator=>"eq", :value=>@entry.broker_reference) 

      r = @report.to_arrays @user
      #4 rows..1 header, 2 PO lines
      expect(r.length).to eq(3)
      row = r[0]
      expect(row).to eq(["Invoice Number", "Invoice Date", "Invoice Total", "PO Number", ModelField.find_by_uid(:bi_brok_ref).label, ModelField.find_by_uid(:bi_ent_po_numbers).label])

      row = r[1]
      expect(row).to eq(["ZZZ", Date.parse("2013-01-01"), BigDecimal.new("49.99"), "1", "Entry", "1\n 2"])

      row = r[2]
      expect(row).to eq(["ZZZ", Date.parse("2013-01-01"), BigDecimal.new("50.00"), "2", "Entry", "1\n 2"])
    end

    it "should show a message if no results are returned" do
      @report.search_criterions.create!(:model_field_uid=>:bi_brok_ref, :operator=>"eq", :value=>"FAIL")

      r = @report.to_arrays @user
      
      expect(r.length).to eq(2)
      row = r[0]
      expect(row).to eq(["Invoice Number", "Invoice Date", "Invoice Total", "PO Number"])

      row = r[1]
      expect(row).to eq(["No data was returned for this report."])
    end
  
    it "should include hyperlinks when enabled" do
      MasterSetup.get.update_attributes(:request_host=>"http://host.xxx")
      @report.include_links = true
      
      r = @report.to_arrays @user
      expect(r.length).to eq(4)
      expect(r[0]).to eq(["Web Links", "Invoice Number", "Invoice Date", "Invoice Total", "PO Number"])

      expect(r[1]).to eq([@entry.view_url, "ZZZ", Date.parse("2013-01-01"), BigDecimal.new("33.33"), "1"])
    end

    it "should show invoices with no po numbers as 1 line" do
      @entry.update_attributes(:po_numbers => "")

      r = @report.to_arrays @user
      expect(r.length).to eq(2)

      expect(r[1]).to eq(["ZZZ", Date.parse("2013-01-01"), BigDecimal.new("100"), ""])
    end

    it "should raise an error if the user cannot view broker invoices" do
      unpriv_user = Factory(:user)
      allow(unpriv_user).to receive(:view_broker_invoices?).and_return(false)

      expect{@report.to_arrays unpriv_user}.to raise_error {|e|
        expect(e.message).to eq("User #{unpriv_user.email} does not have permission to view invoices and cannot run the #{CustomReportBillingStatementByPo.template_name} report.")
      }
    end
  end

end
