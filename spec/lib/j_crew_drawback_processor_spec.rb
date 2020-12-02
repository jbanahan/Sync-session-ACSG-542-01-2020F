describe OpenChain::JCrewDrawbackProcessor do

  describe "process_entries" do

    let (:cdefs) { subject.send(:cdefs) }

    before :each do
      @cd_po = cdefs[:shpln_po]
      @cd_del = cdefs[:shp_delivery_date]
      @cd_size = cdefs[:shpln_size]
      @cd_color = cdefs[:shpln_color]
      @product = create(:product, unique_identifier:'JCREW-12345', name:'12345')
      @importer = with_customs_management_id(create(:company, :importer=>true), "JCREW")
      @c_line = create(:commercial_invoice_line, :quantity=>10, :part_number=>'12345', :po_number=>'12345', :country_origin_code=>'CN')
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
      @s_line = create(:shipment_line, :quantity=>10, :product=>@product)
      @shipment = @s_line.shipment
      @shipment.update_custom_value! @cd_del, 1.days.from_now
      @shipment.update_attributes(:importer_id=>@importer.id, :reference=>@entry.entry_number)
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
      expect(d.entry_number).to eq @entry.entry_number
      expect(d.import_date).to eq @entry.arrival_date.to_date
      expect(d.received_date).to eq @shipment.get_custom_value(@cd_del).value
      expect(d.port_code).to eq @entry.entry_port_code
      expect(d.box_37_duty).to eq @entry.total_duty
      expect(d.box_40_duty).to eq @entry.total_duty_direct
      expect(d.country_of_origin_code).to eq @c_line.country_origin_code
      expect(d.part_number).to eq "#{@product.name}#{@s_line.get_custom_value(@cd_color).value}#{@s_line.get_custom_value(@cd_size).value}"
      expect(d.hts_code).to eq @c_tar.hts_code
      expect(d.description).to eq @entry.merchandise_description
      expect(d.unit_of_measure).to eq "EA" # hard code to eaches
      expect(d.quantity).to eq @s_line.quantity
      expect(d.unit_price).to eq BigDecimal("14.40") # entered value / total units
      expect(d.rate).to eq BigDecimal("0.1") # duty amount / entered value
      expect(d.duty_per_unit).to eq BigDecimal("1.44") # unit price * rate
      expect(d.compute_code).to eq "7" # hard code
      expect(d.ocean).to eq true # mode 10 or 11
      expect(d.importer_id).to eq @entry.importer_id
      expect(d.total_mpf).to eq @entry.mpf
      expect(PieceSet.where(:commercial_invoice_line_id=>@c_line.id).where(:shipment_line_id=>@s_line.id).where(:drawback_import_line_id=>d.id).size).to eq(1)
    end
    it "should only match shipments received after import" do
      @shipment.update_custom_value! @cd_del, 1.day.ago
      OpenChain::JCrewDrawbackProcessor.process_entries [@entry]
      expect(DrawbackImportLine.first).to be_nil
    end
  end
end
