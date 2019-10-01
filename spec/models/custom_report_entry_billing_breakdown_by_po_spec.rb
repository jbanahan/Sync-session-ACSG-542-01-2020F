describe CustomReportEntryBillingBreakdownByPo do

  before :each do
    @master_user = Factory(:master_user)
  end

  context "Class Methods" do

    it "should use the correct template name and description" do
      expect(CustomReportEntryBillingBreakdownByPo.template_name).to eq("Entry Billing Breakdown By PO")
      expect(CustomReportEntryBillingBreakdownByPo.description).to eq("Shows Broker Invoices with each charge in its own column and charge code amounts prorated across the number of PO's on the invoice.")
    end

    it "should have all column fields available for user from BROKER_INVOICE" do
      # We'll test the specific model field filterting in another method...here, just test the user limitations
      allow(CustomReportEntryBillingBreakdownByPo).to receive(:valid_model_field).and_return true

      # We really just want to know that the report is using the correct method for getting Broker Invoice field list
      fields = CustomReportEntryBillingBreakdownByPo.column_fields_available @master_user
      to_find = CoreModule::BROKER_INVOICE.model_fields.values.select {|mf| mf.can_view?(@master_user)}
      expect(fields).to eq(to_find)
    end
    
    it "should not show column fields that user doesn't have permission to see" do
      importer_user = Factory(:importer_user)
      fields = CustomReportEntryBillingBreakdownByPo.column_fields_available importer_user
      expect(fields.index {|mf| mf.uid==:bi_duty_due_date}).to be_nil
    end

    it "should not return Cotton Fee, HMF or MPF column fields" do
      fields = CustomReportEntryBillingBreakdownByPo.column_fields_available @master_user
      expect(fields.index {|mf| mf.uid==:bi_ent_cotton_fee}).to be_nil
      expect(fields.index {|mf| mf.uid==:bi_ent_hmf}).to be_nil
      expect(fields.index {|mf| mf.uid==:bi_ent_mpf}).to be_nil
      total_fields = CoreModule::BROKER_INVOICE.model_fields.values.select {|mf| mf.can_view?(@master_user) && mf.label =~ /^total/i}
      total_fields.each do |mf|
        expect(fields.index {|f| f.uid==mf.uid}).to be_nil
      end
    end

    it "should restrict access to the report to users that can view broker invoices" do
      user = double("user")
      expect(user).to receive(:view_broker_invoices?).and_return true
      expect(CustomReportEntryBillingBreakdownByPo.can_view?(user)).to be_truthy

      expect(user).to receive(:view_broker_invoices?).and_return false
      expect(CustomReportEntryBillingBreakdownByPo.can_view?(user)).to be_falsey      
    end
  end

  context "run" do
    before :each do
      @user = Factory(:master_user)
      allow(@user).to receive(:view_broker_invoices?).and_return(true)
      @invoice_line_1 = Factory(:broker_invoice_line,:charge_description=>"CD1",:charge_amount=>100.00, :broker_invoice=>Factory(:broker_invoice, invoice_number: "ABCD", invoice_date: "2014-01-01"))
      @invoice_line_2 = Factory(:broker_invoice_line,:broker_invoice=>@invoice_line_1.broker_invoice,:charge_description=>"CD2",:charge_amount=>99.99)
      @invoice = @invoice_line_1.broker_invoice
      @entry = @invoice.entry
      @entry.update_attributes :broker_reference=>"Entry", :po_numbers=>"1\n 2\r\n 3", :carrier_code => 'SCAC'

      @report = CustomReportEntryBillingBreakdownByPo.create!
      @report.search_columns.create!(:model_field_uid=>:bi_carrier_code, :rank=>1)
      @report.search_criterions.create!(:model_field_uid=>:bi_carrier_code, :operator=>"eq", :value=>@entry.carrier_code)
    end

    it "should prorate charges across all POs and display each charge column" do
      r = @report.to_arrays @user

      #4 rows..1 header, 3 PO lines
      expect(r.length).to eq(4)
      row = r[0]
      expect(row).to eq(["Broker Reference", "Invoice Number", "PO Number", "PO Total", "CD1", "CD2", ModelField.find_by_uid(:bi_carrier_code).label])

      row = r[1]
      expect(row).to eq([@entry.broker_reference, @invoice.invoice_number.to_s, "1", 66.66, BigDecimal.new("33.33"), BigDecimal.new("33.33"), "SCAC"])

      row = r[2]
      expect(row).to eq([@entry.broker_reference, @invoice.invoice_number.to_s, "2", 66.66, BigDecimal.new("33.33"), BigDecimal.new("33.33"), "SCAC"])

      row = r[3]
      expect(row).to eq([@entry.broker_reference, @invoice.invoice_number.to_s, "3", 66.67, BigDecimal.new("33.34"), BigDecimal.new("33.33"), "SCAC"])
    end

    it "should handle different charge codes across multiple different invoices" do
      # Re-use one of the charge descriptions and then add a new one
      invoice_2_line_1 = Factory(:broker_invoice_line,:charge_description=>"CD2",:charge_amount=>100.00)
      invoice_2_line_2 = Factory(:broker_invoice_line,:broker_invoice=>invoice_2_line_1.broker_invoice,:charge_description=>"CD3",:charge_amount=>99.99)

      invoice2 = invoice_2_line_1.broker_invoice
      entry2 = invoice2.entry
      entry2.update_attributes :broker_reference=>"Entry2", :po_numbers=>"1\n 2", :carrier_code => 'SCAC'

      r = @report.to_arrays @user

      #6 rows..1 header, 5 PO lines
      expect(r.length).to eq(6)
      row = r[0]
      expect(row).to eq(["Broker Reference", "Invoice Number", "PO Number", "PO Total", "CD1", "CD2", "CD3", ModelField.find_by_uid(:bi_carrier_code).label])

      row = r[1]
      expect(row).to eq([@entry.broker_reference, @invoice.invoice_number.to_s, "1", BigDecimal("66.66"), BigDecimal.new("33.33"), BigDecimal.new("33.33"), 0.0, "SCAC"])

      row = r[2]
      expect(row).to eq([@entry.broker_reference, @invoice.invoice_number.to_s, "2", BigDecimal("66.66"), BigDecimal.new("33.33"), BigDecimal.new("33.33"), 0.0, "SCAC"])

      row = r[3]
      expect(row).to eq([@entry.broker_reference, @invoice.invoice_number.to_s, "3", BigDecimal("66.67"), BigDecimal.new("33.34"), BigDecimal.new("33.33"), 0.0, "SCAC"])

      row = r[4]
      expect(row).to eq([entry2.broker_reference, invoice2.invoice_number.to_s, "1", BigDecimal("99.99"), 0.0, BigDecimal.new("50.00"), BigDecimal.new("49.99"), "SCAC"])

      row = r[5]
      expect(row).to eq([entry2.broker_reference, invoice2.invoice_number.to_s, "2", BigDecimal("100.00"), 0.0, BigDecimal.new("50.00"), BigDecimal.new("50.00"), "SCAC"])
    end

    it "should add web links" do
      MasterSetup.get.update_attributes(:request_host=>"http://host.xxx")
      @report.include_links = true
      @report.include_rule_links = true
      r = @report.to_arrays @user

      #4 rows..1 header, 3 PO lines
      expect(r.length).to eq(4)
      row = r[0]
      expect(row).to eq(["Web Links", "Business Rule Links", "Broker Reference", "Invoice Number", "PO Number", "PO Total", "CD1", "CD2", ModelField.find_by_uid(:bi_carrier_code).label])

      row = r[1]
      expect(row).to eq([@entry.view_url, "http://localhost:3000/entries/#{@entry.id}/validation_results", @entry.broker_reference, @invoice.invoice_number.to_s, "1", 66.66, BigDecimal.new("33.33"), BigDecimal.new("33.33"), "SCAC"]) 
    end

    it "should show a message if no results are returned" do
      @report.search_criterions.create!(:model_field_uid=>:bi_brok_ref, :operator=>"eq", :value=>"FAIL")

      r = @report.to_arrays @user
      
      expect(r.length).to eq(2)
      row = r[0]
      expect(row).to eq(["Broker Reference", "Invoice Number", "PO Number", "PO Total", ModelField.find_by_uid(:bi_carrier_code).label])

      row = r[1]
      expect(row).to eq(["No data was returned for this report."])
    end

    it "should show invoices with no po numbers as 1 line" do
      @entry.update_attributes(:po_numbers => "")

      r = @report.to_arrays @user
      expect(r.length).to eq(2)

      expect(r[1]).to eq([@entry.broker_reference, @invoice.invoice_number.to_s, "", 199.99, BigDecimal.new("100.00"), BigDecimal.new("99.99"), "SCAC"])
    end

    it "should raise an error if the user cannot view broker invoices" do
      unpriv_user = Factory(:user)
      allow(unpriv_user).to receive(:view_broker_invoices?).and_return(false)

      expect{@report.to_arrays unpriv_user}.to raise_error {|e|
        expect(e.message).to eq("User #{unpriv_user.email} does not have permission to view invoices and cannot run the #{CustomReportEntryBillingBreakdownByPo.template_name} report.")
      }
    end

    it "orders by entry number and invoice date" do
      # add a second invoice to the @entry
      @entry.broker_invoices << Factory(:broker_invoice_line, :charge_description=>"CD5",:charge_amount=>100.00, 
                                          :broker_invoice => Factory(:broker_invoice, invoice_date: "2014-02-01", invoice_number: "EFGH", entry: @entry)).broker_invoice
      @entry.save!

      # create a second invoice / entry
      entry2 = Factory(:broker_invoice_line,:charge_description=>"CD1",:charge_amount=>100.00, 
                          :broker_invoice=>Factory(:broker_invoice, invoice_date: '2014-01-01', invoice_number: "987654",
                            entry: Factory(:entry, broker_reference: "AAAA", :carrier_code => 'SCAC')
                          )
                        ).broker_invoice.entry

      r = @report.to_arrays @user
      expect(r.length).to eq 8
      expect(r[1][0]).to eq "AAAA"
      expect(r[2][0]).to eq @entry.broker_reference
      expect(r[2][1]).to eq "ABCD"
      expect(r[5][1]).to eq "EFGH"
    end
  end
end
