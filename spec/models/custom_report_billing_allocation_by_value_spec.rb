describe CustomReportBillingAllocationByValue do

  let! (:ms) { stub_master_setup }

  let (:user) {
    u = Factory(:master_user)
    u.company.update! broker: true
    allow(u).to receive(:view_broker_invoices?).and_return(true)
    u
  }

  describe "static_methods" do
    subject { CustomReportBillingAllocationByValue }

    it "should allow users who can view broker invoices" do
      expect(subject.can_view?(user)).to be_truthy
    end
    it "should not allow users who cannot view broker invoices" do
      allow(user).to receive(:view_broker_invoices?).and_return(false)
      expect(subject.can_view?(user)).to be_falsey
    end
    it "should show all entry, commercial invoice, commercial invoice line, commercial invoice tariff fields" do
      cfa = subject.column_fields_available(user)
      expect(cfa.size).to eq(CoreModule::ENTRY.model_fields_including_children(user).values.size)
      expect(cfa).to include(ModelField.find_by_uid(:ent_entry_num))
      expect(cfa).to include(ModelField.find_by_uid(:ci_invoice_number))
      expect(cfa).to include(ModelField.find_by_uid(:cil_line_number))
      expect(cfa).to include(ModelField.find_by_uid(:cit_hts_code))
    end
    it "should allow parameters for only Broker Invoice header fields" do
      cfa = subject.criterion_fields_available(user)
      expect(cfa.size).to eq(CoreModule::BROKER_INVOICE.model_fields.values.size)
      expect(cfa).to eq(CoreModule::BROKER_INVOICE.model_fields.values)
      expect(cfa).to include(ModelField.find_by_uid(:bi_entry_num))
      expect(cfa).not_to include(ModelField.find_by_uid(:bi_line_charge_code))
    end
  end

  describe "run" do
    before :each do
      @ent = Entry.create!(:entry_number=>"12345678901", :broker_reference=>"4567890", :importer_id=>Factory(:company).id)
      @ci_1 = @ent.commercial_invoices.create!(:invoice_number=>"ci_1")
      @cil_1_1 = @ci_1.commercial_invoice_lines.create!(:line_number=>"1", :value=>50)
      @cil_1_2 = @ci_1.commercial_invoice_lines.create!(:line_number=>"2", :value=>200)
      @bi = @ent.broker_invoices.create!(:invoice_date=>0.seconds.ago, :invoice_total=>250, :invoice_number=>"INV#")
      @bil_1 = @bi.broker_invoice_lines.create!(:charge_description=>"C1", :charge_amount=>"50", :charge_code=>'CC1')
    end
    context "charge categories" do
      before :each do
        @imp = @ent.importer
        @imp.charge_categories.create!(:charge_code=>'CC1', :category=>'X')
      end
      it "should use charge categories if they exist" do
        arrays = subject.to_arrays user
        heading_row = arrays.first
        expect(heading_row.size).to eq(5)
        expect(heading_row[4]).to eq("X")
        [10, 40].each_with_index do |val, i|
          expect(arrays[i+1][4]).to eq(val)
        end
      end
      it "should total amounts into categories across multiple codes" do
        @imp.charge_categories.create!(:charge_code=>'CC2', :category=>'X')
        @bi.broker_invoice_lines.create!(:charge_description=>"something", :charge_amount=>250, :charge_code=>'CC2')
        arrays = subject.to_arrays user
        heading_row = arrays.first
        expect(heading_row.size).to eq(5)
        expect(heading_row[4]).to eq("X")
        [60, 240].each_with_index do |val, i|
          expect(arrays[i+1][4]).to eq(val)
        end
      end
      it "should put uncategoriezed amounts into Other Charges category" do
        @bi.broker_invoice_lines.create!(:charge_description=>"something", :charge_amount=>250, :charge_code=>'CC2')
        arrays = subject.to_arrays user
        heading_row = arrays.first
        expect(heading_row.size).to eq(6)
        expect(heading_row[4]).to eq("X")
        expect(heading_row[5]).to eq("Other Charges")
        [[10, 50], [40, 200]].each_with_index do |val, i|
          expect(arrays[i+1][4]).to eq(val[0])
          expect(arrays[i+1][5]).to eq(val[1])
        end
      end
    end
    it "should include base headings" do
      arrays = subject.to_arrays user
      heading_row = arrays.first
      expect(heading_row.size).to eq(5)
      expect(heading_row[0]).to eq(ModelField.find_by_uid(:bi_invoice_number).label)
      expect(heading_row[1]).to eq(ModelField.find_by_uid(:bi_invoice_date).label)
      expect(heading_row[2]).to eq("#{ModelField.find_by_uid(:bi_invoice_total).label} (not prorated)")
      expect(heading_row[3]).to eq("Broker Invoice - Prorated Line Total")
      expect(heading_row[4]).to eq("C1")
    end
    it "should include custom column headings" do
      subject.search_columns.build(:rank=>0, :model_field_uid=>:ent_entry_num)
      subject.search_columns.build(:rank=>1, :model_field_uid=>:cil_line_number)
      arrays = subject.to_arrays user
      heading_row = arrays.first
      expect(heading_row.size).to eq(7)
      expect(heading_row[0]).to eq(ModelField.find_by_uid(:ent_entry_num).label)
      expect(heading_row[1]).to eq(ModelField.find_by_uid(:cil_line_number).label)
      expect(heading_row[2]).to eq(ModelField.find_by_uid(:bi_invoice_number).label)
    end
    it "should include prorated charges" do
      arrays = subject.to_arrays user
      expect(arrays.size).to eq(3) # heading and row for each commercial invoice line
      expect(arrays[1][3]).to eq(10)
      expect(arrays[2][3]).to eq(40)
    end
    it "should include base broker invoice fields" do
      arrays = subject.to_arrays user
      expect(arrays[1][0]).to eq(@bi.invoice_number)
      expect(arrays[1][1]).to eq(@bi.invoice_date.to_date)
      expect(arrays[1][2]).to eq(250)
      expect(arrays[2][0]).to eq(@bi.invoice_number)
      expect(arrays[2][1]).to eq(@bi.invoice_date.to_date)
      expect(arrays[2][2]).to eq(250)
    end
    it "should include entry header fields" do
      subject.search_columns.build(:rank=>0, :model_field_uid=>:ent_entry_num)
      arrays = subject.to_arrays user
      (1..2).each do |row|
        expect(arrays[row][0]).to eq(@ent.entry_number)
        expect(arrays[row][1]).to eq(@bi.invoice_number)
      end
    end
    it "should include commercial invoice fields" do
      subject.search_columns.build(:rank=>0, :model_field_uid=>:ci_invoice_number)
      arrays = subject.to_arrays user
      (1..2).each do |row|
        expect(arrays[row][0]).to eq(@ci_1.invoice_number)
        expect(arrays[row][1]).to eq(@bi.invoice_number)
      end
    end
    it "should filter by broker invoice header information" do
      @ent_2 = Entry.create!(:entry_number=>"9999", :broker_reference=>"5555")
      @ci_2 = @ent_2.commercial_invoices.create!(:invoice_number=>"ci_2")
      @cil_2_1 = @ci_2.commercial_invoice_lines.create!(:line_number=>"1", :value=>100)
      @cil_2_2 = @ci_2.commercial_invoice_lines.create!(:line_number=>"2", :value=>100)
      @bi_2 = @ent_2.broker_invoices.create!(:invoice_date=>0.seconds.ago, :invoice_total=>100, :invoice_number=>'bi_2')
      @bi_2.broker_invoice_lines.create!(:charge_description=>"C1", :charge_amount=>"1000")
      # Adding multiple broker invoice lines resulted in a bug causing duplicate output lines (adding a second here to make
      # sure we're preventing that)
      @bi_2.broker_invoice_lines.create!(:charge_description=>"something", :charge_amount=>250, :charge_code=>'CC2')
      subject.search_criterions.build(:model_field_uid=>:bi_entry_num, :operator=>"eq", :value=>"9999")
      arrays = subject.to_arrays user
      expect(arrays.size).to eq(3)
      expect(arrays[1][0]).to eq(@bi_2.invoice_number)
      expect(arrays[1][3]).to eq(BigDecimal.new(625))
      expect(arrays[1][4]).to eq(500)
      expect(arrays[1][5]).to eq(125)
    end
    it "should include hyperlinks" do
      arrays = described_class.new(:include_links=>true, :include_rule_links=>true).to_arrays user
      expect(arrays.size).to eq(3)
      expect(arrays[0][0]).to eq "Web Links"
      expect(arrays[0][1]).to eq "Business Rule Links"
      # (1..2).each {|i| expect(arrays[i][0]).to eq(@ent.view_url)}
    end
    it "should subtract rounding allocation extra penny from last line" do
      @cil_1_1.update!(:value=>27)
      @cil_1_2.update!(:value=>198)
      @ci_1.commercial_invoice_lines.create!(:line_number=>"3", :value=>50)
      @ci_1.commercial_invoice_lines.create!(:line_number=>"4", :value=>56)
      @bil_1.update!(:charge_amount=>100)
      arrays = subject.to_arrays user
      expect(arrays[1][3]).to eq(8.16)
      expect(arrays[2][3]).to eq(59.82)
      expect(arrays[3][3]).to eq(15.11)
      expect(arrays[4][3]).to eq(16.91) # subtracted extra penny
    end
    it "should add rounding allocation extra penny to last line" do
      @cil_1_1.update!(:value=>100)
      @cil_1_2.update!(:value=>100)
      @ci_1.commercial_invoice_lines.create!(:line_number=>"3", :value=>50)
      @ci_1.commercial_invoice_lines.create!(:line_number=>"4", :value=>60)
      @ci_1.commercial_invoice_lines.create!(:line_number=>"5", :value=>48)
      @bil_1.update!(:charge_amount=>54.86)
      arrays = subject.to_arrays user
      expect(arrays[1][3]).to eq(15.32)
      expect(arrays[2][3]).to eq(15.32)
      expect(arrays[3][3]).to eq(7.66)
      expect(arrays[4][3]).to eq(9.19)
      expect(arrays[5][3]).to eq(7.37) # added extra penny
    end
    it "should not include charge type D" do
      @bi.broker_invoice_lines.create!(:charge_type=>"D", :charge_description=>"CD2", :charge_amount=>7)
      arrays = subject.to_arrays user
      expect(arrays.first.size).to eq(5)
      expect(arrays.first.last).to eq("C1")
      expect(arrays[1].size).to eq(5)
      expect(arrays[1].last).to eq(10)
    end
    it "should use tariff quantity if value is nil or 0" do
      @cil_1_1.update!(:value=>0)
      @cil_1_1.commercial_invoice_tariffs.create!(:entered_value=>60)
      @cil_1_2.update!(:value=>0)
      @cil_1_2.commercial_invoice_tariffs.create!(:entered_value=>40)
      @cil_1_2.commercial_invoice_tariffs.create!(:entered_value=>20)
      arrays = subject.to_arrays user
      expect(arrays.size).to eq(3)
      expect(arrays[1][3]).to eq(30)
      expect(arrays[2][3]).to eq(20) # use the first tariff row
    end
    it "should secure entries for importers" do
      imp_user = Factory(:importer_user)
      @e2 = Entry.create!(:broker_reference=>'8888', :importer_id=>imp_user.company_id)
      @e2.broker_invoices.
        create!(:invoice_date=>0.seconds.ago, :invoice_total=>20, :invoice_number=>'e2').
        broker_invoice_lines.create!(:charge_description=>"CDX", :charge_amount=>20)
      @e2.commercial_invoices.create!(:invoice_number=>"X").
        commercial_invoice_lines.create!(:value=>100)
      arrays = subject.to_arrays imp_user # should not include entry from before(:each)
      expect(arrays.size).to eq(2)
      expect(arrays[0][4]).to eq("CDX")
      expect(arrays[1][4]).to eq(20)
    end
    it "should accumulate multiple broker invoice lines with the same charge description" do
      @bi.broker_invoice_lines.create(:charge_description=>@bil_1.charge_description, :charge_amount=>10)
      arrays = subject.to_arrays user
      expect(arrays.size).to eq(3)
      expect(arrays[1][3]).to eq(12)
      expect(arrays[2][3]).to eq(48)
    end
    it "should truncate on row limit" do
      arrays = subject.to_arrays user, row_limit: 1
      expect(arrays.size).to eq(2)
      expect(arrays[1][3]).to eq(10)
    end
    it "should truncate ISF charges" do
      @bil_1.update!(:charge_description=>"ISF #12312391219")
      @bi.broker_invoice_lines.create(:charge_description=>"ISF #8855858", :charge_amount=>10)
      arrays = subject.to_arrays user
      expect(arrays.size).to eq(3)
      expect(arrays.first.size).to eq(5)
      expect(arrays.first.last).to eq("ISF")
      expect(arrays[1][3]).to eq(12)
      expect(arrays[2][3]).to eq(48)
    end
    it "should order by entry number" do
      @ent_2 = Entry.create!(:entry_number=>"11111", :broker_reference=>"11111")
      @ci_2 = @ent_2.commercial_invoices.create!(:invoice_number=>"ci_2")
      @cil_2_1 = @ci_2.commercial_invoice_lines.create!(:line_number=>"1", :value=>100)
      @bi_2 = @ent_2.broker_invoices.create!(:invoice_date=>0.seconds.ago, :invoice_total=>100, :invoice_number=>'bi_2')

      subject.search_criterions.build(:model_field_uid=>:bi_entry_num, :operator=>"in", :value=>"#{@ent.entry_number}\n#{@ent_2.entry_number}")
      arrays = subject.to_arrays user

      expect(arrays.size).to eq(4)
      expect(arrays[1][0]).to eq(@bi_2.invoice_number)
      expect(arrays[2][0]).to eq(@bi.invoice_number)
    end
    it "handles lines with zero value" do
      # This used to fail if value was nil, just make sure it runs
      @cil_1_1.update! value: nil
      subject.to_arrays user
    end
  end
end
