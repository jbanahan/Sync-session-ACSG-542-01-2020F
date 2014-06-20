require 'spec_helper'

describe Shipment do
  describe "can_view?" do
    it "should not allow view if user not master and linked to importer (even if the company is one of the other parties" do
      imp = Factory(:company)
      c = Factory(:company,vendor:true)
      s = Factory(:shipment,vendor:c,importer:imp)
      u = Factory(:user,shipment_view:true,company:c)
      expect(s.can_view?(u)).to be_false
   end
  end
  describe "commercial_invoices" do
    it "should find linked invoices" do
      sl_1 = Factory(:shipment_line,:quantity=>10)
      ol_1 = Factory(:order_line,:product=>sl_1.product,:order=>Factory(:order,:vendor=>sl_1.shipment.vendor),:quantity=>10,:price_per_unit=>3)
      cl_1 = Factory(:commercial_invoice_line,:commercial_invoice=>Factory(:commercial_invoice,:invoice_number=>"IN1"),:quantity=>10)
      sl_2 = Factory(:shipment_line,:quantity=>11,:shipment=>sl_1.shipment,:product=>sl_1.product)
      ol_2 = Factory(:order_line,:product=>sl_2.product,:order=>Factory(:order,:vendor=>sl_2.shipment.vendor),:quantity=>11,:price_per_unit=>2)
      cl_2 = Factory(:commercial_invoice_line,:commercial_invoice=>Factory(:commercial_invoice,:invoice_number=>"IN2"),:quantity=>11)
      PieceSet.create!(:shipment_line_id=>sl_1.id,:order_line_id=>ol_1.id,:commercial_invoice_line_id=>cl_1.id,:quantity=>10)
      PieceSet.create!(:shipment_line_id=>sl_2.id,:order_line_id=>ol_2.id,:commercial_invoice_line_id=>cl_2.id,:quantity=>11)

      s = Shipment.find(sl_1.shipment.id)

      s.commercial_invoices.collect {|ci| ci.invoice_number}.should == ["IN1","IN2"]
    end
    it "should only return unique invoices" do
      sl_1 = Factory(:shipment_line,:quantity=>10)
      ol_1 = Factory(:order_line,:product=>sl_1.product,:order=>Factory(:order,:vendor=>sl_1.shipment.vendor),:quantity=>10,:price_per_unit=>3)
      cl_1 = Factory(:commercial_invoice_line,:commercial_invoice=>Factory(:commercial_invoice,:invoice_number=>"IN1"),:quantity=>10)
      sl_2 = Factory(:shipment_line,:quantity=>11,:shipment=>sl_1.shipment,:product=>sl_1.product)
      ol_2 = Factory(:order_line,:product=>sl_2.product,:order=>Factory(:order,:vendor=>sl_2.shipment.vendor),:quantity=>11,:price_per_unit=>2)
      cl_2 = Factory(:commercial_invoice_line,:commercial_invoice=>cl_1.commercial_invoice,:quantity=>11)
      PieceSet.create!(:shipment_line_id=>sl_1.id,:order_line_id=>ol_1.id,:commercial_invoice_line_id=>cl_1.id,:quantity=>10)
      PieceSet.create!(:shipment_line_id=>sl_2.id,:order_line_id=>ol_2.id,:commercial_invoice_line_id=>cl_2.id,:quantity=>11)

      sl_1.reload
      ci = sl_1.shipment.commercial_invoices
      # need to to_a call below because of bug: https://github.com/rails/rails/issues/5554
      ci.to_a.should have(1).invoice
      ci.first.invoice_number == "IN1"
    end
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
