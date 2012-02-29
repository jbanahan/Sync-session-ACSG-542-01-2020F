require 'spec_helper'

describe OpenChain::UnderArmourDrawbackProcessor do
  before :each do
    @cd_po = Factory(:custom_definition,:label=>"PO Number",:module_type=>"ShipmentLine",:data_type=>"string")
    @cd_del = Factory(:custom_definition,:label=>"Delivery Date",:module_type=>"Shipment",:data_type=>"date")
    @cd_coo = Factory(:custom_definition,:label=>"Country of Origin",:module_type=>"ShipmentLine",:data_type=>"string")
    @cd_size = Factory(:custom_definition,:label=>"Size",:module_type=>"ShipmentLine",:data_type=>"string")
    @product = Factory(:product)
  end
  describe "link_commercial_invoice_line" do
    it 'should match one entry to one shipment line by po / style' do
      c_line = Factory(:commercial_invoice_line,:quantity=>nil,:part_number=>@product.unique_identifier,:po_number=>'12345')
      c_line.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago)
      s_line = Factory(:shipment_line,:quantity=>10,:product=>@product)
      s_line.shipment.update_custom_value! @cd_del, 0.days.ago
      s_line.update_custom_value! @cd_po, c_line.po_number
      cr = ChangeRecord.new
      OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line c_line, cr
      found = PieceSet.where(:commercial_invoice_line_id=>c_line.id).where(:shipment_line_id=>s_line.id)
      found.should have(1).piece_set
      found.first.quantity.should == s_line.quantity
      cr.should_not be_failed
      cr.change_record_messages.collect {|r| r.message}.should == ["Matched to Shipment: #{s_line.shipment.reference}, Line: #{s_line.line_number}"]
    end
    it 'should match one entry to two shipment lines by po / style' do
      c_line = Factory(:commercial_invoice_line,:quantity=>nil,:part_number=>@product.unique_identifier,:po_number=>'12345')
      c_line.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago)
      s_line = Factory(:shipment_line,:quantity=>10,:product=>@product)
      s_line2 = Factory(:shipment_line,:quantity=>20,:product=>@product)

      [s_line,s_line2].each do |s|
        s.shipment.update_custom_value! @cd_del, 0.days.ago
        s.update_custom_value! @cd_po, c_line.po_number
      end
      cr = ChangeRecord.new
      OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line c_line, cr
      found = PieceSet.where(:commercial_invoice_line_id=>c_line.id)
      found.should have(2).piece_sets
      found.where(:shipment_line_id=>s_line.id).first.quantity.should == 10
      found.where(:shipment_line_id=>s_line2.id).first.quantity.should == 20
      cr.should_not be_failed
      cr.change_record_messages.collect {|r| r.message}.should == ["Matched to Shipment: #{s_line.shipment.reference}, Line: #{s_line.line_number}","Matched to Shipment: #{s_line2.shipment.reference}, Line: #{s_line2.line_number}"]
    end
    it 'should not match to a shipment that is already on another piece set matched to a ci_line' do
      c_line = Factory(:commercial_invoice_line,:quantity=>nil,:part_number=>@product.unique_identifier,:po_number=>'12345')
      c_line.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago)
      c_line_used = Factory(:commercial_invoice_line,:quantity=>nil,:part_number=>@product.unique_identifier,:po_number=>'12345')
      c_line_used.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago)
      s_line = Factory(:shipment_line,:quantity=>10,:product=>@product)
      s_line_used = Factory(:shipment_line,:quantity=>20,:product=>@product)
      [s_line,s_line_used].each do |s|
        s.shipment.update_custom_value! @cd_del, 0.days.ago
        s.update_custom_value! @cd_po, c_line.po_number
      end
      PieceSet.create!(:commercial_invoice_line_id=>c_line_used.id,:shipment_line_id=>s_line_used.id,:quantity=>20)
      cr = ChangeRecord.new
      OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line c_line, cr
      found = PieceSet.where(:commercial_invoice_line_id=>c_line.id)
      found.size.should == 1
      found.first.shipment_line.should == s_line
      found.first.quantity.should == 10
      cr.should_not be_failed
      cr.change_record_messages.collect {|r| r.message}.should == ["Matched to Shipment: #{s_line.shipment.reference}, Line: #{s_line.line_number}"]
    end
    it 'should not make additional matches for commercial invoice lines that are already matched to at least one shipment' do
      c_line = Factory(:commercial_invoice_line,:quantity=>nil,:part_number=>@product.unique_identifier,:po_number=>'12345')
      c_line.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago)
      s_line = Factory(:shipment_line,:quantity=>10,:product=>@product)
      s_line_used = Factory(:shipment_line,:quantity=>20,:product=>@product)
      [s_line,s_line_used].each do |s|
        s.shipment.update_custom_value! @cd_del, 0.days.ago
        s.update_custom_value! @cd_po, c_line.po_number
      end
      PieceSet.create!(:commercial_invoice_line_id=>c_line.id,:shipment_line_id=>s_line_used.id,:quantity=>20)
      cr = ChangeRecord.new
      OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line c_line, cr
      PieceSet.count.should == 1
      cr.should be_failed
      cr.change_record_messages.collect {|r| r.message}.should == ["Line is already linked to shipments, skipped."]
    end
    context 'timing' do
      it 'should not match to a shipment received in the past' do
        c_line = Factory(:commercial_invoice_line,:quantity=>nil,:part_number=>@product.unique_identifier,:po_number=>'12345')
        c_line.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago)
        s_line = Factory(:shipment_line,:quantity=>10,:product=>@product)
        s_line.shipment.update_custom_value! @cd_del, 10.days.ago
        s_line.update_custom_value! @cd_po, c_line.po_number
        OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line c_line
        PieceSet.where(:commercial_invoice_line_id=>c_line.id).where(:shipment_line_id=>s_line.id).should be_empty
      end
      it 'should not match to a shipment received more than 30 days in the future' do
        c_line = Factory(:commercial_invoice_line,:quantity=>nil,:part_number=>@product.unique_identifier,:po_number=>'12345')
        c_line.commercial_invoice.entry.update_attributes(:arrival_date=>0.days.ago)
        s_line = Factory(:shipment_line,:quantity=>10,:product=>@product)
        s_line.shipment.update_custom_value! @cd_del, 31.days.from_now
        s_line.update_custom_value! @cd_po, c_line.po_number
        OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line c_line
        PieceSet.where(:commercial_invoice_line_id=>c_line.id).where(:shipment_line_id=>s_line.id).should be_empty
      end
    end
  end
  describe "make_drawback_import_lines" do
    before :each do
      @c_line = Factory(:commercial_invoice_line,:quantity=>nil,:part_number=>@product.unique_identifier,:po_number=>'12345')
      @c_line.commercial_invoice.entry.update_attributes(
        :entry_number=>"12345678901",
        :arrival_date=>0.days.ago,
        :entry_port_code=>'1234',
        :total_duty=>BigDecimal('123.45'),
        :total_duty_direct=>BigDecimal('234.56'),
        :mpf=>BigDecimal("485.00"),
        :merchandise_description=>'md',
        :transport_mode_code => "11"
      )
      @entry = @c_line.commercial_invoice.entry
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
      @s_line.update_custom_value! @cd_coo, 'CN'
      @s_line.update_custom_value! @cd_po, @c_line.po_number
      @s_line.update_custom_value! @cd_size, "XXL"
    end

    it "should make line with combined data for one shipment line" do
      
      OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line @c_line
      cr = ChangeRecord.new
      r = OpenChain::UnderArmourDrawbackProcessor.new.make_drawback_import_lines @c_line, cr
      r.should have(1).line
      d = r.first
      d.entry_number.should == @entry.entry_number
      d.import_date.should == @entry.arrival_date
      d.received_date.should == @shipment.get_custom_value(@cd_del).value
      d.port_code.should == @entry.entry_port_code
      d.box_37_duty.should == @entry.total_duty
      d.box_40_duty.should == @entry.total_duty_direct
      d.country_of_origin_code.should == @s_line.get_custom_value(@cd_coo).value
      d.part_number.should == "#{@product.unique_identifier}-#{@s_line.get_custom_value(@cd_size).value}"
      d.hts_code.should == @c_tar.hts_code
      d.description.should == @entry.merchandise_description 
      d.unit_of_measure.should == "EA" #hard code to eaches
      d.quantity.should == @s_line.quantity
      d.unit_price.should == BigDecimal("14.40") #entered value / total units
      d.rate.should == BigDecimal("0.1") # duty amount / entered value
      d.duty_per_unit.should == BigDecimal("1.44") #unit price * rate
      d.compute_code.should == "7" #hard code
      d.ocean.should == true #mode 10 or 11
      PieceSet.where(:commercial_invoice_line_id=>@c_line.id).where(:shipment_line_id=>@s_line.id).where(:drawback_import_line_id=>d.id).should have(1).result
    end
    it "should make multiple lines for multiple shipment links" do

      s_line2 = Factory(:shipment_line,:quantity=>2,:product=>@product)
      s2 = s_line2.shipment
      s2.update_custom_value! @cd_del, 1.days.from_now
      s_line2.update_custom_value! @cd_coo, 'CA'
      s_line2.update_custom_value! @cd_po, @c_line.po_number
      s_line2.update_custom_value! @cd_size, "SM"

      @c_tar.update_attributes(:classification_qty_1=>12)
      
      OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line @c_line
      cr = ChangeRecord.new
      r = OpenChain::UnderArmourDrawbackProcessor.new.make_drawback_import_lines @c_line, cr
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
    it "should not make line where line has already been made" do
      OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line @c_line
      r = OpenChain::UnderArmourDrawbackProcessor.new.make_drawback_import_lines @c_line
      r.should have(1).line
      #process again
      cr = ChangeRecord.new
      OpenChain::UnderArmourDrawbackProcessor.
        new.make_drawback_import_lines(@c_line, cr).should be_empty
      cr.should be_failed
      cr.messages.first.should == "Line does not have any unallocated shipment matches."
    end
    it "should set ocean indicator to false when mode is not 10 or 11" do
      @entry.update_attributes(:transport_mode_code=>"40")
      OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line @c_line
      r = OpenChain::UnderArmourDrawbackProcessor.new.make_drawback_import_lines @c_line
      r.first.should_not be_ocean
    end
    it "should write error if no matches found" do
      @c_line = Factory(:commercial_invoice_line,:quantity=>nil,:part_number=>@product.unique_identifier,:po_number=>'12345')
      cr = ChangeRecord.new
      r = OpenChain::UnderArmourDrawbackProcessor.new.make_drawback_import_lines @c_line, cr
      r.should be_blank
      cr.should be_failed
      cr.messages.first.should == "Line does not have any unallocated shipment matches."
    end
    context "quantity validation" do
      it "should not make line if shp qty is not equal to tariff qty and tariff uom is not DOZ" do
        @c_tar.update_attributes(:classification_qty_1=>20)
        cr = ChangeRecord.new
        OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line @c_line
        r = OpenChain::UnderArmourDrawbackProcessor.new.make_drawback_import_lines @c_line, cr
        r.should be_blank
        cr.should be_failed
        cr.messages.first.should == "Entry quantity (20.0 #{@c_tar.classification_uom_1}) does not match receipt quantity (10.0)."
      end
      it "should make line if shp qty is 12x tariff quty and tariff uom is DOZ" do
        @c_tar.update_attributes(:classification_qty_1=>12,:classification_uom_1=>"DOZ")
        @s_line.update_attributes(:quantity=>144)
        cr = ChangeRecord.new
        OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line @c_line
        r = OpenChain::UnderArmourDrawbackProcessor.new.make_drawback_import_lines @c_line, cr
        r.should have(1).result
        cr.should_not be_failed
      end
      it "should not make line if shp qty is equal to tariff qty and tariff uom is DOZ" do
        @c_tar.update_attributes(:classification_uom_1=>"DOZ")
        cr = ChangeRecord.new
        OpenChain::UnderArmourDrawbackProcessor.new.link_commercial_invoice_line @c_line
        r = OpenChain::UnderArmourDrawbackProcessor.new.make_drawback_import_lines @c_line, cr
        r.should be_blank
        cr.should be_failed
        cr.messages.first.should == "Entry quantity (10.0 #{@c_tar.classification_uom_1}) does not match receipt quantity (10.0)."
      end
    end
  end
end
