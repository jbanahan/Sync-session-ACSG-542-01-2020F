require 'spec_helper'

describe OpenChain::JCrewDrawbackProcessor do
  
  describe :process_entries do
    before :each do 
      @cd_po = Factory(:custom_definition,:label=>"PO Number",:module_type=>"ShipmentLine",:data_type=>"string")
      @cd_del = Factory(:custom_definition,:label=>"Delivery Date",:module_type=>"Shipment",:data_type=>"date")
      @cd_size = Factory(:custom_definition,:label=>"Size",:module_type=>"ShipmentLine",:data_type=>"string")
      @cd_color = Factory(:custom_definition,:label=>"Color",:module_type=>"ShipmentLine",:data_type=>"string")
      @product = Factory(:product)
      @importer = Factory(:company,:importer=>true,:alliance_customer_number=>"JCREW")
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
      @c_tar = @c_line.commercial_invoice_tariffs.create!(
        :hts_code=>'6602454545',
        :entered_value=>BigDecimal("144.00"),
        :duty_amount => BigDecimal("14.40"),
        :duty_rate => BigDecimal("0.1"),
        :classification_qty_1 => 10,
        :classification_uom_1 => "PCS"
      )
      @s_line = Factory(:shipment_line,:quantity=>10,:product=>@product)
      @shipment = @s_line.shipment
      @shipment.update_custom_value! @cd_del, 1.days.from_now
      @shipment.update_attributes(:importer_id=>@importer.id,:reference=>@entry.entry_number)
      @s_line.update_custom_value! @cd_po, @c_line.po_number
      @s_line.update_custom_value! @cd_size, "XXL"
      @s_line.update_custom_value! @cd_color, 'RED'
      @cr = ChangeRecord.new
    end
    it "should match to shipment by po / style / entry_number" do
      OpenChain::JCrewDrawbackProcessor.process_entries [@entry]
      d = DrawbackImportLine.first
      @shipment = Shipment.find @shipment.id
      @entry = Entry.find @entry.id
      d.entry_number.should == @entry.entry_number
      d.import_date.should == @entry.arrival_date.to_date
      d.received_date.should == @shipment.get_custom_value(@cd_del).value
      d.port_code.should == @entry.entry_port_code
      d.box_37_duty.should == @entry.total_duty
      d.box_40_duty.should == @entry.total_duty_direct
      d.country_of_origin_code.should == @c_line.country_origin_code
      d.part_number.should == "#{@product.unique_identifier}#{@s_line.get_custom_value(@cd_color).value}#{@s_line.get_custom_value(@cd_size).value}"
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
      PieceSet.where(:commercial_invoice_line_id=>@c_line.id).where(:shipment_line_id=>@s_line.id).where(:drawback_import_line_id=>d.id).should have(1).result
    end
    it "should only match shipments received after import" do
      @shipment.update_custom_value! @cd_del, 1.day.ago
      OpenChain::JCrewDrawbackProcessor.process_entries [@entry]
      DrawbackImportLine.first.should be_nil
    end
  end
end
