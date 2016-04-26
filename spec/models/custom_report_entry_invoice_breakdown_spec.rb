require 'spec_helper'

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


  it "produces report" do
    master_user = Factory(:master_user)
    master_user.stub(:view_broker_invoices?).and_return(true)
    invoice_line = Factory(:broker_invoice_line,:charge_description=>"CD1",:charge_amount=>100.12)
    invoice_line.broker_invoice.entry.update_attributes(:entry_number=>"31612345678",:broker_reference=>"1234567")
    Factory(:broker_invoice_line,:broker_invoice=>invoice_line.broker_invoice,:charge_description=>"CD2",:charge_amount=>55)
    broker_invoice_2 = Factory(:broker_invoice, entry: invoice_line.broker_invoice.entry)
    Factory(:broker_invoice_line, :broker_invoice => broker_invoice_2, :charge_description=>"CD3",:charge_amount=>50.02)
    Factory(:broker_invoice_line,:broker_invoice=> broker_invoice_2, :charge_description=>"CD4",:charge_amount=>26.40)

    rpt = described_class.create!
    rpt.search_columns.create!(:model_field_uid=>:bi_entry_num,:rank=>1)
    rpt.search_columns.create!(:model_field_uid=>:bi_brok_ref,:rank=>1)
    sheet = rpt.to_arrays master_user

    expect(sheet[0][0]).to eq ModelField.find_by_uid(:bi_entry_num).label
    expect(sheet[0][2]).to eq "CD1"
    expect(sheet[1][0]).to eq "31612345678"
    expect(sheet[1][2]).to eq 100.12
    expect(sheet[2][0]).to eq "31612345678"
  end

end
