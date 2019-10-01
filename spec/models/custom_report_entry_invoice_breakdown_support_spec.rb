describe CustomReportEntryInvoiceBreakdownSupport do

  class Cr < CustomReport
    include CustomReportEntryInvoiceBreakdownSupport
    def self.column_fields_available user; CoreModule::BROKER_INVOICE.model_fields(user).values end
    def self.criterion_fields_available user; column_fields_available user end
    def self.can_view? user; user.view_broker_invoices? end
    def run run_by, row_limit = nil; process run_by, row_limit, true end
  end

  context "report" do
    before :each do
      @master_user = Factory(:master_user)
      allow(@master_user).to receive(:view_broker_invoices?).and_return(true)
      @invoice_line_1 = Factory(:broker_invoice_line,:charge_description=>"CD1",:charge_amount=>100.12)
      @invoice_line_2 = Factory(:broker_invoice_line,:broker_invoice=>@invoice_line_1.broker_invoice,:charge_description=>"CD2",:charge_amount=>55)
    end

    it "should break down a single entry by charge description" do
      r = Cr.new.to_arrays @master_user
      row = r[1]
      expect(row[0]).to eq(100.12)
      expect(row[1]).to eq(55)
    end
    it "should write charge description headings" do
      r = Cr.new.to_arrays @master_user
      row = r[0]
      expect(row[0]).to eq("CD1")
      expect(row[1]).to eq("CD2")
    end
    it "should group the same charge for multiple entries into the same column" do
      second_cd1 = Factory(:broker_invoice_line,:charge_description=>"CD1",:charge_amount=>22)
      r = Cr.new.to_arrays @master_user
      expect([r[1][0], r[2][0]]).to eq([100.12,22]) #ordering isn't guaranteed
    end
    it "should add 2 charges with the same charge code on the same entry" do
      @invoice_line_2.update_attributes(:charge_description=>"CD1")
      r = Cr.new.to_arrays(@master_user)[1]
      expect(r[0]).to eq(155.12)
      expect(r[1]).to be_nil
    end
    it "should limit rows" do
      second_cd1 = Factory(:broker_invoice_line,:charge_description=>"CD1",:charge_amount=>22)
      expect(Cr.new.to_arrays(@master_user).size).to eq(3)
      r = Cr.new.to_arrays(@master_user,1)
      expect(r.size).to eq(2)
    end
    context "entry_fields" do
      before :each do
        rpt = Cr.create!
        rpt.search_columns.create!(:model_field_uid=>:bi_entry_num,:rank=>1)
        rpt.search_columns.create!(:model_field_uid=>:bi_brok_ref,:rank=>1)
        @invoice_line_1.broker_invoice.entry.update_attributes(:entry_number=>"31612345678",:broker_reference=>"1234567")
        @sheet = rpt.to_arrays @master_user
      end
      it "should write entry field headings" do
        r = @sheet[0]
        expect(r[0]).to eq(ModelField.find_by_uid(:bi_entry_num).label)
        expect(r[1]).to eq(ModelField.find_by_uid(:bi_brok_ref).label)
        expect(r[2]).to eq("CD1")
        expect(r[3]).to eq("CD2")
      end
      it "should include search_columns before charges" do
        r = @sheet[1]
        expect(r[0]).to eq("31612345678")
        expect(r[1]).to eq("1234567")
        expect(r[2]).to eq(100.12)
        expect(r[3]).to eq(55)
      end
      it "doesn't repeat entry headers, when configured" do
        class Cr
          def run run_by, row_limit = nil; process run_by, row_limit, true end
        end
        broker_invoice_2 = Factory(:broker_invoice, entry: @invoice_line_1.broker_invoice.entry)
        Factory(:broker_invoice_line, :broker_invoice => broker_invoice_2, :charge_description=>"CD3",:charge_amount=>50.02)
        Factory(:broker_invoice_line,:broker_invoice=> broker_invoice_2, :charge_description=>"CD4",:charge_amount=>26.40)
        rpt = Cr.create!
        rpt.search_columns.create!(:model_field_uid=>:bi_entry_num,:rank=>1)
        rpt.search_columns.create!(:model_field_uid=>:bi_brok_ref,:rank=>1)
        rows = rpt.to_arrays @master_user

        expect(rows[1][0]).to eq "31612345678"
        expect(rows[2][0]).to be_blank
        expect(rows[2][4]).to eq 50.02
      end
    end
    it "should include web links as first column" do
      MasterSetup.get.update_attributes(:request_host=>"http://xxxx")
      rpt = Cr.create!(:include_links=>true, :include_rule_links=>true)
      rows = rpt.to_arrays(@master_user)
      expect(rows[0][0]).to eq "Web Links"
      expect(rows[0][1]).to eq "Business Rule Links"
      expect(rows[0][2]).to eq "CD1"
      expect(rows[1][0]).to eq(@invoice_line_1.broker_invoice.entry.view_url)
      expect(rows[1][1]).to eq "http://localhost:3000/entries/#{@invoice_line_1.broker_invoice.entry.id }/validation_results"
    end
    it "should trim by search criteria" do
      bi2_line = Factory(:broker_invoice_line,:charge_description=>"CD1",:charge_amount=>222)
      bi2_line.broker_invoice.entry.update_attributes(:broker_reference=>"abc")
      @invoice_line_1.broker_invoice.entry.update_attributes(:broker_reference=>"def")
      rpt = Cr.create!(:name=>"SC")
      rpt.search_criterions.create!(:model_field_uid=>:bi_brok_ref,:operator=>"eq",:value=>"def")
      sheet = rpt.to_arrays @master_user
      expect(sheet[1][0]).to eq(100.12)
      expect(sheet.size).to eq(2)
    end


    context "isf" do
      it "should truncate ISF charges" do
        @invoice_line_1.update_attributes(:charge_description=>"ISF FILI SF#123455677755",:charge_amount=>6)
        @invoice_line_2.destroy
        bi = Factory(:broker_invoice_line,:charge_description=>"ISF FILING",:charge_amount=>8)
        r = Cr.new.to_arrays @master_user
        expect([r[1][0],r[2][0]]).to eq([6,8])
      end
      it "should truncate ISF heading" do
        @invoice_line_1.update_attributes(:charge_description=>"ISF FILI SF#123455677755",:charge_amount=>6)
        @invoice_line_2.destroy
        r = Cr.new.to_arrays @master_user
        expect(r[0][0]).to eq("ISF")
      end
    end

    it "should write headings even if no rows returned" do
      Entry.destroy_all
      rpt = Cr.create!
      rpt.search_columns.create!(:model_field_uid => :bi_brok_ref)
      r = rpt.to_arrays @master_user
      expect(r[0][0]).to eq(ModelField.find_by_uid(:bi_brok_ref).label)
    end
    it "should write no data message if no rows returned" do
      Entry.destroy_all
      rpt = Cr.create!
      rpt.search_columns.create!(:model_field_uid => :bi_brok_ref)
      r = rpt.to_arrays @master_user
      expect(r[1][0]).to eq("No data was returned for this report.")
    end

    context "security" do
      before :each do
        @importer_user = Factory(:importer_user)
      end
      it "should secure entries by linked companies for importers" do
        allow(@importer_user).to receive(:view_broker_invoices?).and_return(true)
        @invoice_line_1.broker_invoice.entry.update_attributes(:importer_id=>@importer_user.company_id)
        dont_find = Factory(:broker_invoice_line)
        r = Cr.new.to_arrays @importer_user
        expect(r[1][0]).to eq(100.12)
        expect(r.size).to eq(2)
      end
      it "should raise exception if user does not have view_broker_invoices? permission" do
        allow(@importer_user).to receive(:view_broker_invoices?).and_return(false)
        expect {Cr.new.xls_file @importer_user}.to raise_error(/permission/)
      end
    end
  end

end
