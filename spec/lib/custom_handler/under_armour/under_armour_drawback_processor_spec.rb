describe OpenChain::CustomHandler::UnderArmour::UnderArmourDrawbackProcessor do
  before :each do
    @cdefs = described_class.prep_custom_definitions [:po, :del_date, :coo, :size, :color]
    @product = FactoryBot(:product, unique_identifier:'1234567')
  end
  describe "process_entries" do
    before :each do
      @color = '888'
      @importer = FactoryBot(:company, :importer=>true)
      @c_line = FactoryBot(:commercial_invoice_line, :quantity=>10, :part_number=>"#{@product.unique_identifier}-#{@color}", :po_number=>'12345')
      @entry = @c_line.commercial_invoice.entry
      @entry.update_attributes(:arrival_date=>0.days.ago, :importer_id=>@importer.id)
      @c_tar = @c_line.commercial_invoice_tariffs.create!(
        :hts_code=>'6602454545',
        :entered_value=>BigDecimal("144.00"),
        :duty_amount => BigDecimal("14.40"),
        :duty_rate => BigDecimal("0.1"),
        :classification_qty_1 => 10,
        :classification_uom_1 => "PCS"
      )
      @s_line = FactoryBot(:shipment_line, :quantity=>10, :product=>@product)
      @s_line.shipment.update_custom_value! @cdefs[:del_date], 0.days.ago
      @s_line.update_custom_value! @cdefs[:po], @c_line.po_number
      @s_line.update_custom_value! @cdefs[:color], @color
      @s_line.shipment.update_attributes(:importer_id=>@importer.id)
    end
    it 'should match and generate import line for a good link' do
      described_class.process_entries [@entry]
      expect(PieceSet.count).to eq(1)
      ps = PieceSet.first
      expect(ps.shipment_line).to eq(@s_line)
      expect(ps.commercial_invoice_line).to eq(@c_line)
      expect(ps.drawback_import_line).not_to be_nil
      expect(ps.quantity).to eq(@s_line.quantity)
    end
    it 'should write change recod for good link' do
      described_class.process_entries [@entry]
      cr = ChangeRecord.first
      expect(cr).not_to be_failed
      expect(cr.change_record_messages.size).to eq(2)
      expect(cr.recordable).to eq(@c_line)
    end
    it 'should not call drawback if line was not matched' do
      # testing this because calling the method will be a performance hit
      expect_any_instance_of(described_class).not_to receive(:make_drawback_import_lines)
      @s_line.product = FactoryBot(:product)
      @s_line.save!
      described_class.process_entries [@entry]
    end
    it "should write failure message if no match" do
      @s_line.product = FactoryBot(:product)
      @s_line.save!
      described_class.process_entries [@entry]
      cr = ChangeRecord.first
      expect(cr).to be_failed
      expect(cr.messages).to include("Line wasn't matched to any shipments.")
    end
  end
  describe "link_commercial_invoice_line" do
    before :each do
      @cr = ChangeRecord.new
      @color = '777'
      @importer = FactoryBot(:company, :importer=>true)
      @c_line = FactoryBot(:commercial_invoice_line, :quantity=>10, :part_number=>"#{@product.unique_identifier}-#{@color}", :po_number=>'12345')
      @c_line.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago, :importer_id=>@importer.id)
      @s_line = FactoryBot(:shipment_line, :quantity=>10, :product=>@product)
      @s_line.shipment.update_attributes(:importer_id=>@importer.id)
      @s_line.shipment.update_custom_value! @cdefs[:del_date], 0.days.ago
      @s_line.update_custom_value! @cdefs[:color], @color
      @s_line.update_custom_value! @cdefs[:po], @c_line.po_number
    end
    it 'should match one entry to one shipment line by po / style' do
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line.id).where(:shipment_line_id=>@s_line.id)
      expect(found.size).to eq(1)
      expect(found.first.quantity).to eq(@s_line.quantity)
      expect(@cr).not_to be_failed
      expect(@cr.change_record_messages.collect {|r| r.message}).to eq(["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 10.0"])
      expect(r.size).to eq(1)
      expect(r.first).to eq(@s_line)
    end
    it 'should not match if shipment was for a different importer' do
      other_company = FactoryBot(:company, :importer=>true)
      @s_line.shipment.update_attributes(:importer_id=>other_company.id)
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      expect(PieceSet.all).to be_empty
    end
    it "should match if the shipment's importer is linked to the entry's importer" do
      other_company = FactoryBot(:company, :importer=>true)
      other_company.linked_company_ids = [@importer.id]
      @s_line.shipment.update_attributes(:importer_id=>other_company.id)
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      expect(PieceSet.count).to eq(1)
    end
    it 'should match one entry to two shipment lines by po / style' do
      @c_line.update_attributes(:quantity=>30)
      @s_line2 = FactoryBot(:shipment_line, :quantity=>20, :product=>@product)
      @s_line2.shipment.update_attributes(:importer_id=>@importer.id)
      @s_line2.shipment.update_custom_value! @cdefs[:del_date], 0.days.ago
      @s_line2.update_custom_value! @cdefs[:po], @c_line.po_number
      @s_line2.update_custom_value! @cdefs[:color], @color
      described_class.new.link_commercial_invoice_line @c_line, @cr
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line.id)
      expect(found.size).to eq(2)
      expect(found.where(:shipment_line_id=>@s_line.id).first.quantity).to eq(10)
      expect(found.where(:shipment_line_id=>@s_line2.id).first.quantity).to eq(20)
      expect(@cr).not_to be_failed
      expect(@cr.change_record_messages.collect {|r| r.message}).to eq(["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 10.0", "Matched to Shipment: #{@s_line2.shipment.reference}, Line: #{@s_line2.line_number}, Quantity: 20.0"])
    end
    it 'should not match to a shipment that is already on another piece set matched to a ci_line' do
      @c_line.update_attributes(:quantity=>30)
      @c_line_used = FactoryBot(:commercial_invoice_line, :quantity=>10, :part_number=>"#{@product.unique_identifier}-#{@color}", :po_number=>'12345')
      @c_line_used.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago)
      @s_line_used = FactoryBot(:shipment_line, :quantity=>20, :product=>@product)
      [@s_line, @s_line_used].each do |s|
        s.shipment.update_custom_value! @cdefs[:del_date], 0.days.ago
        s.update_custom_value! @cdefs[:po], @c_line.po_number
        s.update_custom_value! @cdefs[:color], @color
      end
      PieceSet.create!(:commercial_invoice_line_id=>@c_line_used.id, :shipment_line_id=>@s_line_used.id, :quantity=>20)
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      expect(r.size).to eq(1)
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line.id)
      expect(found.size).to eq(1)
      expect(found.first.shipment_line).to eq(@s_line)
      expect(found.first.quantity).to eq(10)
      expect(@cr).not_to be_failed
      expect(@cr.change_record_messages.collect {|r| r.message}).to eq(["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 10.0"])
    end
    it "should create partial piece sets if quantities are not aligned" do
      @c_line.update_attributes(:quantity=>8)
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      expect(r.size).to eq(1)
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line.id)
      expect(found.size).to eq(1)
      expect(found.first.shipment_line).to eq(@s_line)
      expect(found.first.quantity).to eq(8)
      expect(@cr).not_to be_failed
      expect(@cr.change_record_messages.collect {|r| r.message}).to eq(["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 8.0"])
    end
    it "should allocate shipment remainders to another invoice line if left over" do
      @c_line.update_attributes(:quantity=>8)
      @c_line_2 = FactoryBot(:commercial_invoice_line, :quantity=>8, :part_number=>"#{@product.unique_identifier}-#{@color}", :po_number=>'12345')
      @c_line_2.entry.update_attributes(:arrival_date=>0.days.ago, :importer_id=>@importer.id)
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      expect(r.size).to eq(1)
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line.id)
      expect(found.size).to eq(1)
      expect(found.first.shipment_line).to eq(@s_line)
      expect(found.first.quantity).to eq(8)
      expect(@cr).not_to be_failed
      expect(@cr.change_record_messages.collect {|r| r.message}).to eq(["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 8.0"])
      @cr = ChangeRecord.new
      r = described_class.new.link_commercial_invoice_line @c_line_2, @cr
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line_2.id)
      expect(found.size).to eq(1)
      expect(found.first.shipment_line).to eq(@s_line)
      expect(found.first.quantity).to eq(2)
      expect(@cr).not_to be_failed
      expect(@cr.change_record_messages.collect {|r| r.message}).to eq(["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 2.0"])
    end
    it "should consider previous matches to determine how much invoice quantity is available to match" do
      @c_line.update_attributes(:quantity=>8)
      @s_line_used = FactoryBot(:shipment_line, :quantity=>6, :product=>@product)
      @s_line_used.shipment.update_custom_value! @cdefs[:del_date], 0.days.ago
      @s_line_used.update_custom_value! @cdefs[:po], @c_line.po_number
      PieceSet.create!(:commercial_invoice_line_id=>@c_line.id, :shipment_line_id=>@s_line_used.id, :quantity=>6)
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      expect(r.size).to eq(1)
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line.id, :shipment_line_id=>@s_line)
      expect(found.size).to eq(1)
      expect(found.first.shipment_line).to eq(@s_line)
      expect(found.first.quantity).to eq(2)
      expect(@cr).not_to be_failed
      expect(@cr.change_record_messages.collect {|r| r.message}).to eq(["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 2.0"])
    end
    context 'timing' do
      it 'should not match to a shipment received in the past' do
        @c_line.update_attributes(:quantity=>10)
        @c_line.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago)
        @s_line.shipment.update_custom_value! @cdefs[:del_date], 10.days.ago
        described_class.new.link_commercial_invoice_line @c_line
        expect(PieceSet.where(:commercial_invoice_line_id=>@c_line.id).where(:shipment_line_id=>@s_line.id)).to be_empty
      end
    end
  end
  describe "make_drawback_import_lines" do
    before :each do
      @color = '777'
      @importer = FactoryBot(:company, :importer=>true)
      @c_line = FactoryBot(:commercial_invoice_line, :quantity=>10, :part_number=>"#{@product.unique_identifier}-#{@color}", :po_number=>'12345', :country_origin_code=>'CN')
      @c_line.entry.update_attributes(
        :entry_number=>"12345678901",
        :arrival_date=>0.days.ago,
        :entry_port_code=>'1234',
        :total_duty=>BigDecimal('123.45'),
        :total_duty_direct=>BigDecimal('234.56'),
        :mpf=>BigDecimal("485.00"),
        :merchandise_description=>'md',
        :transport_mode_code => "11",
        :importer_id=>@importer.id
      )
      @entry = @c_line.entry
      @entry.update_attributes(:entry_number=>'1234567890', :arrival_date=>Date.new(2011, 1, 2), :entry_port_code=>'4701', :total_duty=>500, :total_duty_direct=>501, :mpf=>26,
      :total_invoiced_value=>10001)
      @c_tar = @c_line.commercial_invoice_tariffs.create!(
        :hts_code=>'6602454545',
        :entered_value=>BigDecimal("144.00"),
        :duty_amount => BigDecimal("14.40"),
        :duty_rate => BigDecimal("0.1"),
        :classification_qty_1 => 10,
        :classification_uom_1 => "PCS"
      )
      @s_line = FactoryBot(:shipment_line, :quantity=>10, :product=>@product)
      @shipment = @s_line.shipment
      @shipment.update_custom_value! @cdefs[:del_date], 1.days.from_now
      @shipment.update_attributes(:importer_id=>@importer.id)
      @s_line.update_custom_value! @cdefs[:coo], 'TW'
      @s_line.update_custom_value! @cdefs[:po], @c_line.po_number
      @s_line.update_custom_value! @cdefs[:color], @color
      @s_line.update_custom_value! @cdefs[:size], "XXL"
    end

    it "should make line with combined data for one shipment line" do

      described_class.new.link_commercial_invoice_line @c_line
      cr = ChangeRecord.new
      r = described_class.new.make_drawback_import_lines @c_line, cr
      expect(r.size).to eq(1)
      @shipment = Shipment.find @shipment.id
      @entry = Entry.find @entry.id
      d = r.first
      expect(d.entry_number).to eq(@entry.entry_number)
      expect(d.import_date).to eq(@entry.arrival_date)
      expect(d.received_date).to eq(@shipment.get_custom_value(@cdefs[:del_date]).value)
      expect(d.port_code).to eq(@entry.entry_port_code)
      expect(d.box_37_duty).to eq(@entry.total_duty)
      expect(d.box_40_duty).to eq(@entry.total_duty_direct)
      expect(d.country_of_origin_code).to eq(@c_line.country_origin_code)
      expect(d.part_number).to eq("#{@product.unique_identifier}-#{@color}-#{@s_line.get_custom_value(@cdefs[:size]).value}+#{@c_line.country_origin_code}")
      expect(d.hts_code).to eq(@c_tar.hts_code)
      expect(d.description).to eq(@entry.merchandise_description)
      expect(d.unit_of_measure).to eq("EA") # hard code to eaches
      expect(d.quantity).to eq(@s_line.quantity)
      expect(d.unit_price).to eq(BigDecimal("14.40")) # entered value / total units
      expect(d.rate).to eq(BigDecimal("0.1")) # duty amount / entered value
      expect(d.duty_per_unit).to eq(BigDecimal("1.44")) # unit price * rate
      expect(d.compute_code).to eq("7") # hard code
      expect(d.ocean).to eq(true) # mode 10 or 11
      expect(d.importer_id).to eq(@entry.importer_id)
      expect(d.total_mpf).to eq(@entry.mpf)
      expect(d.total_invoice_value).to eq(@entry.total_invoiced_value)
      expect(PieceSet.where(:commercial_invoice_line_id=>@c_line.id).where(:shipment_line_id=>@s_line.id).where(:drawback_import_line_id=>d.id).size).to eq(1)
    end
    it "should set importer_id based on entry.importer_id when companies are linked" do
      other_company = FactoryBot(:company, :importer=>true)
      other_company.linked_company_ids = [@importer.id]
      @s_line.shipment.update_attributes(:importer_id=>other_company.id)
      described_class.new.link_commercial_invoice_line @c_line
      cr = ChangeRecord.new
      r = described_class.new.make_drawback_import_lines @c_line, cr
      expect(r.size).to eq(1)
      d = r.first
      expect(d.importer_id).to eq(@entry.importer_id)
    end
    it "should make multiple links for multiple shipment lines" do

      s_line2 = FactoryBot(:shipment_line, :quantity=>2, :product=>@product)
      s2 = s_line2.shipment
      s2.update_attributes(:importer_id=>@importer.id)
      s2.update_custom_value! @cdefs[:del_date], 1.days.from_now
      s_line2.update_custom_value! @cdefs[:coo], 'CA'
      s_line2.update_custom_value! @cdefs[:po], @c_line.po_number
      s_line2.update_custom_value! @cdefs[:color], @color
      s_line2.update_custom_value! @cdefs[:size], "SM"

      @c_line.update_attributes(:quantity=>12)

      described_class.new.link_commercial_invoice_line @c_line
      cr = ChangeRecord.new
      r = described_class.new.make_drawback_import_lines @c_line, cr
      expect(r.size).to eq(2)
      d1 = r.first
      expect(d1.unit_price).to eq(BigDecimal("12.00"))
      expect(d1.rate).to eq(BigDecimal("0.1"))
      expect(d1.duty_per_unit).to eq(BigDecimal("1.20"))
      expect(d1.quantity).to eq(@s_line.quantity)

      d2 = r.last
      expect(d2.unit_price).to eq(BigDecimal("12.00"))
      expect(d2.rate).to eq(BigDecimal("0.1"))
      expect(d2.duty_per_unit).to eq(BigDecimal("1.20"))
      expect(d2.quantity).to eq(s_line2.quantity)
    end
    it 'should use shipment country of origin if entry country of origin is blank' do
      @c_line.update_attributes(:country_origin_code=>'')
      described_class.new.link_commercial_invoice_line @c_line
      cr = ChangeRecord.new
      d = described_class.new.make_drawback_import_lines(@c_line, cr).first
      expect(d.part_number).to eq("#{@product.unique_identifier}-#{@color}-#{@s_line.get_custom_value(@cdefs[:size]).value}+#{@s_line.get_custom_value(@cdefs[:coo]).value}")
    end
    it "should not make line where line has already been made" do
      described_class.new.link_commercial_invoice_line @c_line
      r = described_class.new.make_drawback_import_lines @c_line
      expect(r.size).to eq(1)
      # process again
      cr = ChangeRecord.new
      expect(described_class.
        new.make_drawback_import_lines(@c_line, cr)).to be_empty
      expect(cr).to be_failed
      expect(cr.messages.first).to eq("Line does not have any unallocated shipment matches.")
    end
    it "should set ocean indicator to false when mode is not 10 or 11" do
      @entry.update_attributes(:transport_mode_code=>"40")
      described_class.new.link_commercial_invoice_line @c_line
      r = described_class.new.make_drawback_import_lines @c_line
      expect(r.first).not_to be_ocean
    end
    it "should write error if no matches found" do
      @c_line = FactoryBot(:commercial_invoice_line, :quantity=>10, :part_number=>"#{@product.unique_identifier}-#{@color}", :po_number=>'12345')
      cr = ChangeRecord.new
      r = described_class.new.make_drawback_import_lines @c_line, cr
      expect(r).to be_blank
      expect(cr).to be_failed
      expect(cr.messages.first).to eq("Line does not have any unallocated shipment matches.")
    end
    context "quantity validation" do
      it "should not make line if entered value is 0" do
        @c_tar.update_attributes(:entered_value=>0)
        cr = ChangeRecord.new
        described_class.new.link_commercial_invoice_line @c_line
        r = described_class.new.make_drawback_import_lines @c_line, cr
        expect(r).to be_blank
        expect(cr).to be_failed
        expect(cr.messages.first).to eq("Cannot make line because entered value is 0.")
      end
      it "should not make line if entered value is nil" do
        @c_tar.update_attributes(:entered_value=>nil)
        cr = ChangeRecord.new
        described_class.new.link_commercial_invoice_line @c_line
        r = described_class.new.make_drawback_import_lines @c_line, cr
        expect(r).to be_blank
        expect(cr).to be_failed
        expect(cr.messages.first).to eq("Cannot make line because entered value is empty.")
      end
      it "should not make line if duty amount is nil, 0 is fine" do
        @c_tar.update_attributes(:duty_amount=>nil)
        cr = ChangeRecord.new
        described_class.new.link_commercial_invoice_line @c_line
        r = described_class.new.make_drawback_import_lines @c_line, cr
        expect(r).to be_blank
        expect(cr).to be_failed
        expect(cr.messages.first).to eq("Cannot make line because duty amount is empty.")
      end
    end
  end
end
