require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UnderArmourDrawbackProcessor do
  before :each do
    @cd_po = Factory(:custom_definition,:label=>"PO Number",:module_type=>"ShipmentLine",:data_type=>"string")
    @cd_del = Factory(:custom_definition,:label=>"Delivery Date",:module_type=>"Shipment",:data_type=>"date")
    @cd_coo = Factory(:custom_definition,:label=>"Country of Origin",:module_type=>"ShipmentLine",:data_type=>"string")
    @cd_size = Factory(:custom_definition,:label=>"Size",:module_type=>"ShipmentLine",:data_type=>"string")
    @product = Factory(:product)
  end
  describe "process_entries" do
    before :each do
      @importer = Factory(:company,:importer=>true)
      @c_line = Factory(:commercial_invoice_line,:quantity=>10,:part_number=>@product.unique_identifier,:po_number=>'12345',:quantity=>10)
      @entry = @c_line.commercial_invoice.entry
      @entry.update_attributes(:arrival_date=>0.days.ago,:importer_id=>@importer.id)
      @c_tar = @c_line.commercial_invoice_tariffs.create!(
        :hts_code=>'6602454545',
        :entered_value=>BigDecimal("144.00"),
        :duty_amount => BigDecimal("14.40"),
        :classification_qty_1 => 10,
        :classification_uom_1 => "PCS"
      )
      @s_line = Factory(:shipment_line,:quantity=>10,:product=>@product)
      @s_line.shipment.update_custom_value! @cd_del, 0.days.ago
      @s_line.update_custom_value! @cd_po, @c_line.po_number
      @s_line.shipment.update_attributes(:importer_id=>@importer.id)
    end
    it 'should match and generate import line for a good link' do
      described_class.process_entries [@entry]
      PieceSet.should have(1).record
      ps = PieceSet.first
      ps.shipment_line.should == @s_line
      ps.commercial_invoice_line.should == @c_line
      ps.drawback_import_line.should_not be_nil
      ps.quantity.should == @s_line.quantity
    end
    it 'should write change recod for good link' do
      described_class.process_entries [@entry]
      cr = ChangeRecord.first
      cr.should_not be_failed
      cr.should have(2).change_record_messages
      cr.recordable.should == @c_line
    end
    it 'should not call drawback if line was not matched' do
      # testing this because calling the method will be a performance hit
      described_class.any_instance.should_not_receive(:make_drawback_import_lines)
      @s_line.product = Factory(:product)
      @s_line.save!
      described_class.process_entries [@entry]
    end
    it "should write failure message if no match" do
      @s_line.product = Factory(:product)
      @s_line.save!
      described_class.process_entries [@entry]
      cr = ChangeRecord.first
      cr.should be_failed
      cr.messages.should include("Line wasn't matched to any shipments.")
    end
  end
  describe "link_commercial_invoice_line" do
    before :each do
      @cr = ChangeRecord.new
      @importer = Factory(:company,:importer=>true)
      @c_line = Factory(:commercial_invoice_line,:quantity=>10,:part_number=>@product.unique_identifier,:po_number=>'12345')
      @c_line.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago,:importer_id=>@importer.id)
      @s_line = Factory(:shipment_line,:quantity=>10,:product=>@product)
      @s_line.shipment.update_attributes(:importer_id=>@importer.id)
      @s_line.shipment.update_custom_value! @cd_del, 0.days.ago
      @s_line.update_custom_value! @cd_po, @c_line.po_number
    end
    it 'should match one entry to one shipment line by po / style' do
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line.id).where(:shipment_line_id=>@s_line.id)
      found.should have(1).piece_set
      found.first.quantity.should == @s_line.quantity
      @cr.should_not be_failed
      @cr.change_record_messages.collect {|r| r.message}.should == ["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 10.0"]
      r.should have(1).shipment_line
      r.first.should == @s_line
    end
    it 'should not match if shipment was for a different importer' do
      other_company = Factory(:company,:importer=>true)
      @s_line.shipment.update_attributes(:importer_id=>other_company.id)
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      PieceSet.all.should be_empty
    end
    it "should match if the shipment's importer is linked to the entry's importer" do
      other_company = Factory(:company,:importer=>true)
      other_company.linked_company_ids = [@importer.id]
      @s_line.shipment.update_attributes(:importer_id=>other_company.id)
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      PieceSet.should have(1).record
    end
    it 'should match one entry to two shipment lines by po / style' do
      @c_line.update_attributes(:quantity=>30)
      @s_line2 = Factory(:shipment_line,:quantity=>20,:product=>@product)
      @s_line2.shipment.update_attributes(:importer_id=>@importer.id)
      @s_line2.shipment.update_custom_value! @cd_del, 0.days.ago
      @s_line2.update_custom_value! @cd_po, @c_line.po_number
      described_class.new.link_commercial_invoice_line @c_line, @cr
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line.id)
      found.should have(2).piece_sets
      found.where(:shipment_line_id=>@s_line.id).first.quantity.should == 10
      found.where(:shipment_line_id=>@s_line2.id).first.quantity.should == 20
      @cr.should_not be_failed
      @cr.change_record_messages.collect {|r| r.message}.should == ["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 10.0","Matched to Shipment: #{@s_line2.shipment.reference}, Line: #{@s_line2.line_number}, Quantity: 20.0"]
    end
    it 'should not match to a shipment that is already on another piece set matched to a ci_line' do
      @c_line.update_attributes(:quantity=>30)
      @c_line_used = Factory(:commercial_invoice_line,:quantity=>10,:part_number=>@product.unique_identifier,:po_number=>'12345')
      @c_line_used.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago)
      @s_line_used = Factory(:shipment_line,:quantity=>20,:product=>@product)
      [@s_line,@s_line_used].each do |s|
        s.shipment.update_custom_value! @cd_del, 0.days.ago
        s.update_custom_value! @cd_po, @c_line.po_number
      end
      PieceSet.create!(:commercial_invoice_line_id=>@c_line_used.id,:shipment_line_id=>@s_line_used.id,:quantity=>20)
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      r.should have(1).shipment_line
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line.id)
      found.size.should == 1
      found.first.shipment_line.should == @s_line
      found.first.quantity.should == 10
      @cr.should_not be_failed
      @cr.change_record_messages.collect {|r| r.message}.should == ["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 10.0"]
    end
    it "should create partial piece sets if quantities are not aligned" do
      @c_line.update_attributes(:quantity=>8)
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      r.should have(1).shipment_line
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line.id)
      found.size.should == 1
      found.first.shipment_line.should == @s_line
      found.first.quantity.should == 8
      @cr.should_not be_failed
      @cr.change_record_messages.collect {|r| r.message}.should == ["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 8.0"]
    end
    it "should allocate shipment remainders to another invoice line if left over" do
      @c_line.update_attributes(:quantity=>8)
      @c_line_2 = Factory(:commercial_invoice_line,:quantity=>8,:part_number=>@product.unique_identifier,:po_number=>'12345')
      @c_line_2.entry.update_attributes(:arrival_date=>0.days.ago,:importer_id=>@importer.id)
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      r.should have(1).shipment_line
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line.id)
      found.size.should == 1
      found.first.shipment_line.should == @s_line
      found.first.quantity.should == 8
      @cr.should_not be_failed
      @cr.change_record_messages.collect {|r| r.message}.should == ["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 8.0"]
      @cr = ChangeRecord.new
      r = described_class.new.link_commercial_invoice_line @c_line_2, @cr
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line_2.id)
      found.size.should == 1
      found.first.shipment_line.should == @s_line
      found.first.quantity.should == 2
      @cr.should_not be_failed
      @cr.change_record_messages.collect {|r| r.message}.should == ["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 2.0"]
    end
    it "should consider previous matches to determine how much invoice quantity is available to match" do
      @c_line.update_attributes(:quantity=>8)
      @s_line_used = Factory(:shipment_line,:quantity=>6,:product=>@product)
      @s_line_used.shipment.update_custom_value! @cd_del, 0.days.ago
      @s_line_used.update_custom_value! @cd_po, @c_line.po_number
      PieceSet.create!(:commercial_invoice_line_id=>@c_line.id,:shipment_line_id=>@s_line_used.id,:quantity=>6)
      r = described_class.new.link_commercial_invoice_line @c_line, @cr
      r.should have(1).shipment_line
      found = PieceSet.where(:commercial_invoice_line_id=>@c_line.id,:shipment_line_id=>@s_line)
      found.size.should == 1
      found.first.shipment_line.should == @s_line
      found.first.quantity.should == 2
      @cr.should_not be_failed
      @cr.change_record_messages.collect {|r| r.message}.should == ["Matched to Shipment: #{@s_line.shipment.reference}, Line: #{@s_line.line_number}, Quantity: 2.0"]
    end
    context 'timing' do
      it 'should not match to a shipment received in the past' do
        @c_line.update_attributes(:quantity=>10)
        @c_line.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago)
        @s_line.shipment.update_custom_value! @cd_del, 10.days.ago
        described_class.new.link_commercial_invoice_line @c_line
        PieceSet.where(:commercial_invoice_line_id=>@c_line.id).where(:shipment_line_id=>@s_line.id).should be_empty
      end
    end
  end
  describe "make_drawback_import_lines" do
    before :each do
      @importer = Factory(:company,:importer=>true)
      @c_line = Factory(:commercial_invoice_line,:quantity=>10,:part_number=>@product.unique_identifier,:po_number=>'12345',:country_origin_code=>'CN')
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
      @entry.update_attributes(:entry_number=>'1234567890',:arrival_date=>Date.new(2011,1,2),:entry_port_code=>'4701',:total_duty=>500,:total_duty_direct=>501,:mpf=>26,
      :total_invoiced_value=>10001)
      @c_tar = @c_line.commercial_invoice_tariffs.create!(
        :hts_code=>'6602454545',
        :entered_value=>BigDecimal("144.00"),
        :duty_amount => BigDecimal("14.40"),
        :classification_qty_1 => 10,
        :classification_uom_1 => "PCS"
      )
      @s_line = Factory(:shipment_line,:quantity=>10,:product=>@product)
      @shipment = @s_line.shipment
      @shipment.update_custom_value! @cd_del, 1.days.from_now
      @shipment.update_attributes(:importer_id=>@importer.id)
      @s_line.update_custom_value! @cd_coo, 'TW'
      @s_line.update_custom_value! @cd_po, @c_line.po_number
      @s_line.update_custom_value! @cd_size, "XXL"
    end

    it "should make line with combined data for one shipment line" do
      
      described_class.new.link_commercial_invoice_line @c_line
      cr = ChangeRecord.new
      r = described_class.new.make_drawback_import_lines @c_line, cr
      r.should have(1).line
      @shipment = Shipment.find @shipment.id
      @entry = Entry.find @entry.id
      d = r.first
      d.entry_number.should == @entry.entry_number
      d.import_date.should == @entry.arrival_date
      d.received_date.should == @shipment.get_custom_value(@cd_del).value
      d.port_code.should == @entry.entry_port_code
      d.box_37_duty.should == @entry.total_duty
      d.box_40_duty.should == @entry.total_duty_direct
      d.country_of_origin_code.should == @c_line.country_origin_code
      d.part_number.should == "#{@product.unique_identifier}-#{@s_line.get_custom_value(@cd_size).value}+#{@c_line.country_origin_code}"
      d.hts_code.should == @c_tar.hts_code
      d.description.should == @entry.merchandise_description 
      d.unit_of_measure.should == "EA" #hard code to eaches
      d.quantity.should == @s_line.quantity
      d.unit_price.should == BigDecimal("14.40") #entered value / total units
      d.rate.should == BigDecimal("0.1") # duty amount / entered value
      d.duty_per_unit.should == BigDecimal("1.44") #unit price * rate
      d.compute_code.should == "7" #hard code
      d.ocean.should == true #mode 10 or 11
      d.importer_id.should == @entry.importer_id
      d.total_mpf.should == @entry.mpf
      d.total_invoice_value.should == @entry.total_invoiced_value
      PieceSet.where(:commercial_invoice_line_id=>@c_line.id).where(:shipment_line_id=>@s_line.id).where(:drawback_import_line_id=>d.id).should have(1).result
    end
    it "should set importer_id based on entry.importer_id when companies are linked" do
      other_company = Factory(:company,:importer=>true)
      other_company.linked_company_ids = [@importer.id]
      @s_line.shipment.update_attributes(:importer_id=>other_company.id)
      described_class.new.link_commercial_invoice_line @c_line
      cr = ChangeRecord.new
      r = described_class.new.make_drawback_import_lines @c_line, cr
      r.should have(1).line
      d = r.first
      d.importer_id.should == @entry.importer_id
    end
    it "should make multiple links for multiple shipment lines" do

      s_line2 = Factory(:shipment_line,:quantity=>2,:product=>@product)
      s2 = s_line2.shipment
      s2.update_attributes(:importer_id=>@importer.id)
      s2.update_custom_value! @cd_del, 1.days.from_now
      s_line2.update_custom_value! @cd_coo, 'CA'
      s_line2.update_custom_value! @cd_po, @c_line.po_number
      s_line2.update_custom_value! @cd_size, "SM"

      @c_line.update_attributes(:quantity=>12)
      
      described_class.new.link_commercial_invoice_line @c_line
      cr = ChangeRecord.new
      r = described_class.new.make_drawback_import_lines @c_line, cr
      r.should have(2).drawback_lines
      d1 = r.first
      d1.unit_price.should == BigDecimal("12.00")
      d1.rate.should == BigDecimal("0.1")
      d1.duty_per_unit.should == BigDecimal("1.20")
      d1.quantity.should == @s_line.quantity

      d2 = r.last
      d2.unit_price.should == BigDecimal("12.00")
      d2.rate.should == BigDecimal("0.1")
      d2.duty_per_unit.should == BigDecimal("1.20")
      d2.quantity.should == s_line2.quantity
    end
    it 'should use shipment country of origin if entry country of origin is blank' do
      @c_line.update_attributes(:country_origin_code=>'')
      described_class.new.link_commercial_invoice_line @c_line
      cr = ChangeRecord.new
      d = described_class.new.make_drawback_import_lines(@c_line, cr).first
      d.part_number.should == "#{@product.unique_identifier}-#{@s_line.get_custom_value(@cd_size).value}+#{@s_line.get_custom_value(@cd_coo).value}"
    end
    it "should not make line where line has already been made" do
      described_class.new.link_commercial_invoice_line @c_line
      r = described_class.new.make_drawback_import_lines @c_line
      r.should have(1).line
      #process again
      cr = ChangeRecord.new
      described_class.
        new.make_drawback_import_lines(@c_line, cr).should be_empty
      cr.should be_failed
      cr.messages.first.should == "Line does not have any unallocated shipment matches."
    end
    it "should set ocean indicator to false when mode is not 10 or 11" do
      @entry.update_attributes(:transport_mode_code=>"40")
      described_class.new.link_commercial_invoice_line @c_line
      r = described_class.new.make_drawback_import_lines @c_line
      r.first.should_not be_ocean
    end
    it "should write error if no matches found" do
      @c_line = Factory(:commercial_invoice_line,:quantity=>10,:part_number=>@product.unique_identifier,:po_number=>'12345')
      cr = ChangeRecord.new
      r = described_class.new.make_drawback_import_lines @c_line, cr
      r.should be_blank
      cr.should be_failed
      cr.messages.first.should == "Line does not have any unallocated shipment matches."
    end
    context "quantity validation" do
      it "should not make line if entered value is 0" do
        @c_tar.update_attributes(:entered_value=>0)
        cr = ChangeRecord.new
        described_class.new.link_commercial_invoice_line @c_line
        r = described_class.new.make_drawback_import_lines @c_line, cr
        r.should be_blank
        cr.should be_failed
        cr.messages.first.should == "Cannot make line because entered value is 0."
      end
      it "should not make line if entered value is nil" do
        @c_tar.update_attributes(:entered_value=>nil)
        cr = ChangeRecord.new
        described_class.new.link_commercial_invoice_line @c_line
        r = described_class.new.make_drawback_import_lines @c_line, cr
        r.should be_blank
        cr.should be_failed
        cr.messages.first.should == "Cannot make line because entered value is empty."
      end
      it "should not make line if duty amount is nil, 0 is fine" do
        @c_tar.update_attributes(:duty_amount=>nil)
        cr = ChangeRecord.new
        described_class.new.link_commercial_invoice_line @c_line
        r = described_class.new.make_drawback_import_lines @c_line, cr
        r.should be_blank
        cr.should be_failed
        cr.messages.first.should == "Cannot make line because duty amount is empty."
      end
    end
  end
end
