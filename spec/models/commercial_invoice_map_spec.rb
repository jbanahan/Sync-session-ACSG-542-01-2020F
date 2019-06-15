describe CommercialInvoiceMap do
  describe "generate_invoice!" do
    before :each do
      allow_any_instance_of(ModelField).to receive(:can_view?).and_return(true) #not worrying about field permissions for this test
      allow_any_instance_of(ModelField).to receive(:can_edit?).and_return(true) #not worrying about field permissions for this test

      @shp_date = CustomDefinition.create!(:label=>"shpdt",:data_type=>"date",:module_type=>"Shipment")
      @shp_coo = CustomDefinition.create!(:label=>"coo",:data_type=>"string",:module_type=>"ShipmentLine")
      ModelField.reload
      @s_line = Factory(:shipment_line,:quantity=>20,
        :shipment=>Factory(:shipment,:reference=>"SHR"))
      @s_line.shipment.update_custom_value! @shp_date.id, Date.new(2012,01,01)
      @s_line.update_custom_value! @shp_coo.id, "CA"
      @o_line = Factory(:order_line,:product=>@s_line.product,:quantity=>80,
        :price_per_unit=>3,
        :order=>Factory(:order,:vendor=>@s_line.shipment.vendor,:order_date=>Date.new(2010,3,6))
        )
      @piece_set = PieceSet.create!(:shipment_line_id=>@s_line.id,:order_line_id=>@o_line.id,:quantity=>20)
    end
    it "should create invoice just based on shipment fields" do
      {:shp_ref=>:ci_invoice_number,
        @shp_date.model_field_uid => :ci_invoice_date,
        @shp_coo.model_field_uid => :cil_country_origin_code
      }.each do |src,dest|
        CommercialInvoiceMap.create!(:source_mfid=>src, :destination_mfid=>dest)
      end
      ci = CommercialInvoiceMap.generate_invoice! Factory(:user), [@s_line]
      expect(ci.invoice_number).to eq("SHR")
      expect(ci.invoice_date).to eq(Date.new(2012,01,01))
      expect(ci.commercial_invoice_lines.size).to eq(1)
      c_line = ci.commercial_invoice_lines.first
      expect(c_line.country_origin_code).to eq("CA")
      expect(c_line.shipment_lines.first).to eq(@s_line)
    end
    it "should set header values from passed in hash" do
      {:shp_ref=>:ci_invoice_number}.each do |src,dest|
        CommercialInvoiceMap.create!(:source_mfid=>src, :destination_mfid=>dest)
      end
      hdr_hash = {:ci_invoice_date=>"2006-04-01"}
      ci = CommercialInvoiceMap.generate_invoice! Factory(:user), [@s_line], hdr_hash
      expect(ci.invoice_date).to eq(Date.new(2006,4,1))
    end
    it "should set line values from passed in hash" do
      {:shp_ref=>:ci_invoice_number}.each do |src,dest|
        CommercialInvoiceMap.create!(:source_mfid=>src, :destination_mfid=>dest)
      end
      val_hash = {:ci_invoice_date=>"2006-04-01",:lines=>{@s_line.id.to_s=>{:cil_units=>"10",:cit_hts_code=>"1234567890"}}}
      ci = CommercialInvoiceMap.generate_invoice! Factory(:user), [@s_line], val_hash
      expect(ci.invoice_date).to eq(Date.new(2006,4,1))
      line = ci.commercial_invoice_lines.first
      expect(line.quantity).to eq(10)
      expect(line.commercial_invoice_tariffs.first.hts_code).to eq("1234567890")
    end
    it "should create invoice based on shipment & order fields" do
      {:shp_ref=>:ci_invoice_number,
        :ord_ord_date => :ci_invoice_date,
        :ord_ven_name => :ci_vendor_name,
        :ordln_ppu => :ent_unit_price,
        :shpln_shipped_qty => :cil_units,
        :prod_uid => :cil_part_number
      }.each do |src,dest|
        CommercialInvoiceMap.create!(:source_mfid=>src, :destination_mfid=>dest)
      end
      ci = CommercialInvoiceMap.generate_invoice! Factory(:user), [@s_line]
      expect(ci.invoice_number).to eq(@s_line.shipment.reference)
      expect(ci.invoice_date).to eq(@o_line.order.order_date)
      expect(ci.vendor_name).to eq(@o_line.order.vendor.name)
      lines = ci.commercial_invoice_lines
      expect(lines.size).to eq(1)
      line = lines.first
      expect(line.unit_price).to eq(@o_line.price_per_unit)
      expect(line.quantity).to eq(@s_line.quantity)
      expect(line.part_number).to eq(@o_line.product.unique_identifier)
      expect(line.order_lines.first).to eq(@o_line)
      expect(line.shipment_lines.first).to eq(@s_line)
    end
    it "should set value based on unit price & units if set" do
      {:shp_ref=>:ci_invoice_number,
        :ord_ord_date => :ci_invoice_date,
        :ord_ven_name => :ci_vendor_name,
        :ordln_ppu => :ent_unit_price,
        :shpln_shipped_qty => :cil_units,
        :prod_uid => :cil_part_number
      }.each do |src,dest|
        CommercialInvoiceMap.create!(:source_mfid=>src, :destination_mfid=>dest)
      end
      ci = CommercialInvoiceMap.generate_invoice! Factory(:user), [@s_line]
      expect(ci.commercial_invoice_lines.first.value).to eq(@s_line.quantity * @o_line.price_per_unit)
    end
    it "should set tariff based on ship to country" do
      {:shp_ref=>:ci_invoice_number,
        :ord_ord_date => :ci_invoice_date,
        :ord_ven_name => :ci_vendor_name,
        :ordln_ppu => :ent_unit_price,
        :shpln_shipped_qty => :cil_units,
        :prod_uid => :cil_part_number
      }.each do |src,dest|
        CommercialInvoiceMap.create!(:source_mfid=>src, :destination_mfid=>dest)
      end
      shipment = @s_line.shipment
      vendor = shipment.vendor
      c = Factory(:country)
      address = Factory(:address,:country=>c,:shipping=>true,:company=>vendor)
      shipment.update_attributes(:ship_to_id=>address.id)
      product = @s_line.product
      tar = Factory(:tariff_record,:hts_1=>"123456789",:classification=>Factory(:classification,:country=>c,:product=>product))
      ci = CommercialInvoiceMap.generate_invoice! User.new, [@s_line]
      expect(ci.commercial_invoice_lines.first.commercial_invoice_tariffs.first.hts_code).to eq("123456789")
    end
    it "should raise exception if all lines aren't from the same shipment" do
      s_line = Factory(:shipment_line)
      s_line2 = Factory(:shipment_line)
      expect {CommercialInvoiceMap.generate_invoice! double('user'), [s_line,s_line2]}.to raise_error(/multiple shipments/)
    end
  end
end
