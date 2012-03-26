require 'spec_helper'

describe Shipment do
  describe 'generate_commercial_invoice!' do
    it 'should create commercial_invoice for given shipment lines' do
      vendor = Factory(:company,:vendor=>true)
      s_line = Factory(:shipment_line,:quantity=>3,:shipment=>Factory(:shipment,:vendor=>vendor))
      shipment = s_line.shipment
      o_line = Factory(:order_line,:order=>Factory(:order,:vendor=>vendor),:product=>s_line.product,:quantity=>5,:price_per_unit=>10.4)
      PieceSet.create!(:shipment_line_id=>s_line.id,
        :order_line_id=>o_line.id,:quantity=>3)
      s_line_2 = Factory(:shipment_line,:shipment=>shipment,:quantity=>15)
      o_line_2 = Factory(:order_line,:product=>s_line_2.product,:quantity=>30,:price_per_unit=>3)
      PieceSet.create!(:shipment_line_id=>s_line_2.id,
        :order_line_id=>o_line_2.id,:quantity=>15)
      inv_date = Time.now
      inv_headers = {:invoice_number=>"INVN",:invoice_date=>inv_date}
      invoice = Shipment.find(shipment.id).generate_commercial_invoice! inv_headers, [s_line,s_line_2]
      invoice.id.should_not be_blank #saved in database
      invoice.invoice_number.should == "INVN"
      invoice.invoice_date.should == inv_date
      invoice.should have(2).commercial_invoice_lines
      c_line = invoice.commercial_invoice_lines.first
      c_line.should have(1).piece_sets
      ps = c_line.piece_sets.first
      ps.shipment_line.should == s_line
      c_line.part_number.should == s_line.product.unique_identifier
      c_line.unit_price.should == o_line.price_per_unit
      c_line.po_number.should == o_line.order.order_number.to_s
      c_line.quantity.should == s_line.quantity
      c_line.value.should == c_line.unit_price * c_line.quantity
      c_line.vendor_name.should == o_line.order.vendor.name
      ps.order_line.should == o_line
      c_line.line_number.should == 1
      invoice.commercial_invoice_lines.last.shipment_lines.first.should == s_line_2

    end
    it "should create errors in invoice if lines aren't all from this shipment"
    it "should create errors in if lines aren't all linked to order lines"
    it "should create error if shipment doesn't have ship from"
    it "should create error if shipment doesn't have ship to"
    it "should use reference number as invoice number if invoice number is empty"
  end
  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      s = Factory(:shipment,:reference=>'ordn')
      linkable = Factory(:linkable_attachment,:model_field_uid=>'shp_ref',:value=>'ordn')
      linked = LinkedAttachment.create(:linkable_attachment_id=>linkable.id,:attachable=>s)
      s.reload
      s.linkable_attachments.first.should == linkable
    end
  end
end
