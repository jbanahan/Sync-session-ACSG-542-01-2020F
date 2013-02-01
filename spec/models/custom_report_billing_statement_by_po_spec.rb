require 'spec_helper'
require 'spreadsheet'

describe CustomReportBillingStatementByPo do
  
  context "Class Methods" do

    before :each do
      @r = CustomReportBillingStatementByPo
    end
    
    it "should only allow broker invoice users to view" do
      user = double("user")
      user.stub(:view_broker_invoices?).and_return(true)
      @r.can_view?(user).should be_true

      user.stub(:view_broker_invoices?).and_return(false)
      @r.can_view?(user).should be_false
    end

    it "should return broker invoice column fields and criterion fields" do
      user = double("user")
      mf = {:mf => ModelField.new(1, :mf, CoreModule::BROKER_INVOICE, "Test")}
      CoreModule::BROKER_INVOICE.should_receive(:model_fields).twice.with(user).and_return(mf)

      @r.column_fields_available(user).should == mf.values
      @r.criterion_fields_available(user).should == mf.values
    end
  end

  context "run report" do

    before :each do
      @user = Factory(:master_user)
      @user.stub(:view_broker_invoices?).and_return(true)
      @invoice = Factory(:broker_invoice, :suffix=>"Test", :invoice_total=>"100", :invoice_date=>Date.parse("2013-01-01"))
      @invoice.entry.update_attributes(:broker_reference=>"Entry", :po_numbers=>"1\n 2\n 3")
      @entry = @invoice.entry
      @report = CustomReportBillingStatementByPo.create!
    end

    it "should split the invoice into 3 po lines and prorate the invoice amount across each line" do
      @report.search_columns.create!(:model_field_uid=>:bi_brok_ref, :rank=>1)
      @report.search_columns.create!(:model_field_uid=>:bi_ent_po_numbers, :rank=>2)

      r = @report.to_arrays @user
      #4 rows..1 header, 3 PO lines
      r.length.should == 4
      row = r[0]
      row.should == ["Invoice Number", "Invoice Date", "Invoice Total", "PO Number", ModelField.find_by_uid(:bi_brok_ref).label, ModelField.find_by_uid(:bi_ent_po_numbers).label]

      row = r[1]
      row.should == ["EntryTest", Date.parse("2013-01-01"), BigDecimal.new("33.33"), "1", "Entry", "1\n 2\n 3"]

      row = r[2]
      row.should == ["EntryTest", Date.parse("2013-01-01"), BigDecimal.new("33.33"), "2", "Entry", "1\n 2\n 3"]

      row = r[3]
      row.should == ["EntryTest", Date.parse("2013-01-01"), BigDecimal.new("33.33"), "3", "Entry", "1\n 2\n 3"]
    end

    it "should show a message if now results are returned" do
      @report.search_criterions.create!(:model_field_uid=>:bi_brok_ref, :operator=>"eq", :value=>"FAIL")

      r = @report.to_arrays @user
      
      r.length.should == 2
      row = r[0]
      row.should == ["Invoice Number", "Invoice Date", "Invoice Total", "PO Number"]

      row = r[1]
      row.should == ["No data was returned for this report."]
    end
  
    it "should include hyperlinks when enabled" do
      MasterSetup.get.update_attributes(:request_host=>"http://host.xxx")
      @report.include_links = true
      
      r = @report.to_arrays @user
      r.length.should == 4
      r[0].should == ["Web Links", "Invoice Number", "Invoice Date", "Invoice Total", "PO Number"]

      r[1].should == [@entry.view_url, "EntryTest", Date.parse("2013-01-01"), BigDecimal.new("33.33"), "1"]
    end

    it "should show invoices with no po numbers as 1 line" do
      @entry.update_attributes(:po_numbers => "")

      r = @report.to_arrays @user
      r.length.should == 2

      r[1].should == ["EntryTest", Date.parse("2013-01-01"), BigDecimal.new("100"), ""]
    end

    it "should raise an error if the user cannot view broker invoices" do
      unpriv_user = Factory(:user)
      unpriv_user.stub(:view_broker_invoices?).and_return(false)

      expect{@report.to_arrays unpriv_user}.to raise_error {|e|
        e.message.should == "User #{unpriv_user.email} does not have permission to view invoices and cannot run the #{CustomReportBillingStatementByPo.template_name} report."
      }
    end
  end

end
