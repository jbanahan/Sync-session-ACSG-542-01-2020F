require 'spec_helper'

describe CommercialInvoiceMap do
  describe "generate_invoice!" do
    before :each do
      ModelField.any_instance.stub(:can_view?).and_return(true) #not worrying about field permissions for this test
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
      PieceSet.create!(:shipment_line_id=>@s_line.id,:order_line_id=>@o_line.id,:quantity=>20)
    end
    it "should create invoice just based on shipment fields" do
      {:shp_ref=>:ci_invoice_number,
        @shp_date.model_field_uid => :ci_invoice_date,
        @shp_coo.model_field_uid => :cil_country_origin_code
      }.each do |src,dest|
        CommercialInvoiceMap.create!(:source_mfid=>src, :destination_mfid=>dest)
      end
      ci = CommercialInvoiceMap.generate_invoice! Factory(:user), [@s_line]
      ci.invoice_number.should == "SHR"
      ci.invoice_date.should == Date.new(2012,01,01)
      ci.commercial_invoice_lines.should have(1).item
      c_line = ci.commercial_invoice_lines.first
      c_line.country_origin_code.should == "CA"
    end
    it "should set header values from passed in hash" do
      {:shp_ref=>:ci_invoice_number}.each do |src,dest|
        CommercialInvoiceMap.create!(:source_mfid=>src, :destination_mfid=>dest)
      end
      hdr_hash = {:ci_invoice_date=>"2006-04-01"}
      ci = CommercialInvoiceMap.generate_invoice! Factory(:user), [@s_line], hdr_hash
      ci.invoice_date.should == Date.new(2006,4,1)
    end
    it "should set line values from passed in hash" do
      {:shp_ref=>:ci_invoice_number}.each do |src,dest|
        CommercialInvoiceMap.create!(:source_mfid=>src, :destination_mfid=>dest)
      end
      val_hash = {:ci_invoice_date=>"2006-04-01",:lines=>{@s_line.id.to_s=>{:cil_units=>"10",:cit_hts_code=>"1234567890"}}}
      ci = CommercialInvoiceMap.generate_invoice! Factory(:user), [@s_line], val_hash
      ci.invoice_date.should == Date.new(2006,4,1)
      line = ci.commercial_invoice_lines.first
      line.quantity.should == 10
      line.commercial_invoice_tariffs.first.hts_code.should == "1234567890" 
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
      ci.invoice_number.should == @s_line.shipment.reference
      ci.invoice_date.should == @o_line.order.order_date
      ci.vendor_name.should == @o_line.order.vendor.name
      lines = ci.commercial_invoice_lines
      lines.should have(1).item
      line = lines.first
      line.unit_price.should == @o_line.price_per_unit
      line.quantity.should == @s_line.quantity
      line.part_number.should == @o_line.product.unique_identifier
    end
    it "should set tariff based on ship to country"
    it "should raise exception if all lines aren't from the same shipment" do
      s_line = Factory(:shipment_line)
      s_line2 = Factory(:shipment_line)
      lambda {CommercialInvoiceMap.generate_invoice! [s_line,s_line2]}.should raise_error
    end
  end
end
