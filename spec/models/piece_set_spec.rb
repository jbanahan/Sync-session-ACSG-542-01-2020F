require 'spec_helper'

describe PieceSet do
  describe 'validations' do
    before :each do
      @product = Factory(:product)
      @ps = PieceSet.new(:quantity=>1,
        :order_line=>Factory(:order_line,:product=>@product),
        :shipment_line=>Factory(:shipment_line,:product=>@product),
        :sales_order_line=>Factory(:sales_order_line,:product=>@product),
        :delivery_line=>Factory(:delivery_line,:product=>@product),
        :drawback_import_line=>Factory(:drawback_import_line,:product=>@product)
      )
    end
    it 'should pass with all products the same' do
      @ps.save.should be_true
    end
    it 'should fail with a different product on an associated line' do
      order_line = @ps.order_line
      order_line.product = Factory(:product)
      order_line.save!
      @ps.save.should be_false
      @ps.errors.full_messages.should include "Data Integrity Error: Piece Set cannot be saved with multiple linked products."
    end
    it 'should fail with different product on DrawbackImportLine' do
      d = @ps.drawback_import_line
      d.product = Factory(:product)
      @ps.save.should be_false
      @ps.errors.full_messages.should include "Data Integrity Error: Piece Set cannot be saved with multiple linked products."
    end
  end
end
