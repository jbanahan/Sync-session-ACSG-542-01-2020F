require 'spec_helper'

describe LinesSupport do
  context 'piece sent linking' do
    it 'should link shipment to order' do
      s_line = Factory(:shipment_line)
      o_line = Factory(:order_line,:product=>s_line.product)
      s_line.linked_order_line_id = o_line.id
      s_line.save.should be_true
      PieceSet.count.should == 1
      PieceSet.where(:shipment_line_id=>s_line.id).where(:order_line_id=>o_line.id).count.should == 1
    end
    it 'should link shipment to order and delivery' do #testing multiple links
      s_line = Factory(:shipment_line)
      d_line = Factory(:delivery_line,:product=>s_line.product)
      o_line = Factory(:order_line,:product=>s_line.product)
      s_line.linked_order_line_id = o_line.id
      s_line.linked_delivery_line_id = d_line.id
      s_line.save.should be_true

      PieceSet.count.should == 2

      PieceSet.where(:shipment_line_id=>s_line.id).where(:order_line_id=>o_line.id).count.should == 1
      PieceSet.where(:shipment_line_id=>s_line.id).where(:delivery_line_id=>d_line.id).count.should == 1
    end
    it 'should link commercial invoice line to drawback import line' do
      c_line = Factory(:commercial_invoice_line,:quantity=>1)
      d_line = Factory(:drawback_import_line)
      c_line.linked_drawback_line_id = d_line.id
      c_line.save.should be_true

      PieceSet.count.should == 1
      PieceSet.find_by_drawback_import_line_id_and_commercial_invoice_line_id(d_line.id,c_line.id).should_not be_nil
    end
    it 'should link drawback import line to commercial invoice line' do
      c_line = Factory(:commercial_invoice_line)
      d_line = Factory(:drawback_import_line,:quantity=>1)
      d_line.linked_commercial_invoice_line_id = c_line.id
      d_line.save.should be_true

      PieceSet.count.should == 1
      PieceSet.find_by_drawback_import_line_id_and_commercial_invoice_line_id(d_line.id,c_line.id).should_not be_nil
    end
  end
end
