require 'spec_helper'
require 'spreadsheet'

describe CustomReportEntryInvoiceBreakdown do

  context "static methods" do
    before :each do
      @kls = CustomReportEntryInvoiceBreakdown
      @master_user = Factory(:master_user)
      @importer_user = Factory(:importer_user)
    end
    it "should have all column fields available from BROKER_INVOICE that the user can see " do
      fields = @kls.column_fields_available @master_user
      to_find = CoreModule::BROKER_INVOICE.model_fields.values.collect {|mf| mf if mf.can_view?(@master_user)}.compact!
      fields.should == to_find
    end
    it "should not show column fields that user doesn't have permission to see" do
      fields = @kls.column_fields_available @importer_user
      fields.index {|mf| mf.uid==:bi_duty_due_date}.should be_nil
    end

    it "should allow all column fields as criterion fields" do
      @kls.criterion_fields_available(@importer_user).should == @kls.column_fields_available(@importer_user)
    end

    it "should allow users who can view broker invoices to view" do
      @master_user.stub(:view_broker_invoices?).and_return(true)
      @kls.can_view?(@master_user).should be_true
    end
    it "should not allow users who cannot view broker invoices to view" do
      @master_user.stub(:view_broker_invoices?).and_return(false)
      @kls.can_view?(@master_user).should be_false
    end
  end
  context "report" do
    before :each do
      @master_user = Factory(:master_user)
      @master_user.stub(:view_broker_invoices?).and_return(true)
      @invoice_line_1 = Factory(:broker_invoice_line,:charge_description=>"CD1",:charge_amount=>100.12)
      @invoice_line_2 = Factory(:broker_invoice_line,:broker_invoice=>@invoice_line_1.broker_invoice,:charge_description=>"CD2",:charge_amount=>55)
    end
    after :each do
      @tmp_files.each {|t| t.delete if t} if @tmp_files
    end
    def get_worksheet file
      @tmp_files ||= []
      @tmp_files << file
      Spreadsheet.open(file).worksheet(0)
    end
    it "should break down a single entry by charge description" do
      sheet = get_worksheet CustomReportEntryInvoiceBreakdown.new.run @master_user
      row = sheet.row(1)
      row[0].should == 100.12
      row[1].should == 55
    end
    it "should write charge description headings" do
      sheet = get_worksheet CustomReportEntryInvoiceBreakdown.new.run @master_user
      row = sheet.row(0)
      row[0].should == "CD1"
      row[1].should == "CD2"
    end
    it "should group the same charge for multiple entries into the same column" do
      second_cd1 = Factory(:broker_invoice_line,:charge_description=>"CD1",:charge_amount=>22)
      sheet = get_worksheet CustomReportEntryInvoiceBreakdown.new.run @master_user
      [sheet.row(1)[0], sheet.row(2)[0]].should == [100.12,22] #ordering isn't guaranteed
    end
    it "should add 2 charges with the same charge code on the same entry" do
      @invoice_line_2.update_attributes(:charge_description=>"CD1")
      sheet = get_worksheet CustomReportEntryInvoiceBreakdown.new.run @master_user
      sheet.row(1)[0].should == 155.12
      sheet.row(1)[1].should be_nil
    end
    context :entry_fields do
      before :each do
        rpt = CustomReportEntryInvoiceBreakdown.create!
        rpt.search_columns.create!(:model_field_uid=>:bi_entry_num,:rank=>1)
        rpt.search_columns.create!(:model_field_uid=>:bi_brok_ref,:rank=>1)
        @invoice_line_1.broker_invoice.entry.update_attributes(:entry_number=>"31612345678",:broker_reference=>"1234567")
        @sheet = get_worksheet rpt.run @master_user
      end
      it "should write entry field headings" do
        r = @sheet.row(0)
        r[0].should == ModelField.find_by_uid(:bi_entry_num).label
        r[1].should == ModelField.find_by_uid(:bi_brok_ref).label
        r[2].should == "CD1"
        r[3].should == "CD2"
      end
      it "should include search_columns before charges" do
        r = @sheet.row(1)
        r[0].should == "31612345678"
        r[1].should == "1234567"
        r[2].should == 100.12
        r[3].should == 55
      end
    end
    it "should include web links as first column" do
      MasterSetup.get.update_attributes(:request_host=>"http://xxxx")
      rpt = CustomReportEntryInvoiceBreakdown.create!(:include_links=>true)
      r = get_worksheet(rpt.run(@master_user)).row(1)
      r[0].should == "Web View"
      r[0].href.should == @invoice_line_1.broker_invoice.entry.view_url
    end
    it "should trim by search criteria" do
      bi2_line = Factory(:broker_invoice_line,:charge_description=>"CD1",:charge_amount=>222)
      bi2_line.broker_invoice.entry.update_attributes(:broker_reference=>"abc")
      @invoice_line_1.broker_invoice.entry.update_attributes(:broker_reference=>"def")
      rpt = CustomReportEntryInvoiceBreakdown.create!(:name=>"SC")
      rpt.search_criterions.create!(:model_field_uid=>:bi_brok_ref,:operator=>"eq",:value=>"def")
      sheet = get_worksheet rpt.run @master_user
      sheet.row(1)[0].should == 100.12
      sheet.row_count.should == 2
    end
    context :isf do
      it "should truncate ISF charges" do
        @invoice_line_1.update_attributes(:charge_description=>"ISF FILI SF#123455677755",:charge_amount=>6)
        @invoice_line_2.destroy
        bi = Factory(:broker_invoice_line,:charge_description=>"ISF FILING",:charge_amount=>8)
        sheet = get_worksheet CustomReportEntryInvoiceBreakdown.new.run @master_user
        [sheet.row(1)[0],sheet.row(2)[0]].should == [6,8]
      end
      it "should truncate ISF heading" do
        @invoice_line_1.update_attributes(:charge_description=>"ISF FILI SF#123455677755",:charge_amount=>6)
        @invoice_line_2.destroy
        sheet = get_worksheet CustomReportEntryInvoiceBreakdown.new.run @master_user
        sheet.row(0)[0].should == "ISF"
      end
    end

    it "should write headings even if no rows returned" do
      Entry.destroy_all
      rpt = CustomReportEntryInvoiceBreakdown.create!
      rpt.search_columns.create!(:model_field_uid => :bi_brok_ref)
      sheet = get_worksheet rpt.run @master_user
      sheet.row(0)[0].should == ModelField.find_by_uid(:bi_brok_ref).label
    end
    it "should write no data message if no rows returned" do
      Entry.destroy_all
      rpt = CustomReportEntryInvoiceBreakdown.create!
      rpt.search_columns.create!(:model_field_uid => :bi_brok_ref)
      sheet = get_worksheet rpt.run @master_user
      sheet.row(1)[0].should == "No data was returned for this report." 
    end
    
    context :security do
      before :each do
        @importer_user = Factory(:importer_user)
      end
      it "should secure entries by linked companies for importers" do
        @importer_user.stub(:view_broker_invoices?).and_return(true)
        @invoice_line_1.broker_invoice.entry.update_attributes(:importer_id=>@importer_user.company_id)
        dont_find = Factory(:broker_invoice_line)
        sheet = get_worksheet CustomReportEntryInvoiceBreakdown.new.run @importer_user
        sheet.row(1)[0].should == 100.12 
        sheet.row_count.should == 2
      end
      it "should raise exception if user does not have view_broker_invoices? permission" do
        @importer_user.stub(:view_broker_invoices?).and_return(false)
        lambda {CustomReportEntryInvoiceBreakdown.new.run @importer_user}.should raise_error
      end
    end
  end
end
