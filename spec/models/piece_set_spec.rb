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

  describe :destroy_if_one_key! do
    it "should destroy if only has one foreign key" do
      product = Factory(:product)
      ps = PieceSet.create!(:quantity=>1,
        :order_line=>Factory(:order_line,:product=>product)
      )
      expect(ps.destroy_if_one_key).to be_true
      expect(PieceSet.count).to eq 0
    end
    it "should not destroy if has multiple foreign_keys" do
      product = Factory(:product)
      ps = PieceSet.create!(:quantity=>1,
        :order_line=>Factory(:order_line,:product=>product),
        :shipment_line=>Factory(:shipment_line,:product=>product)
      )
      expect(ps.destroy_if_one_key).to be_false
      expect(PieceSet.count).to eq 1
    end
  end

  describe 'merge_duplicates' do
    before :each do
      @product = Factory(:product)
      @ps = PieceSet.create!(:quantity=>1,
        :order_line=>Factory(:order_line,:product=>@product),
        :shipment_line=>Factory(:shipment_line,:product=>@product),
        :sales_order_line=>Factory(:sales_order_line,:product=>@product),
        :delivery_line=>Factory(:delivery_line,:product=>@product),
        :drawback_import_line=>Factory(:drawback_import_line,:product=>@product)
      )
    end
    it "should merge two piece sets with same keys" do
      ps2 = PieceSet.create!(:quantity=>1,
        :order_line=>@ps.order_line,
        :shipment_line=>@ps.shipment_line,
        :sales_order_line=>@ps.sales_order_line,
        :delivery_line=>@ps.delivery_line,
        :drawback_import_line=>@ps.drawback_import_line
      )
      expect {PieceSet.merge_duplicates!(ps2)}.to change(PieceSet,:count).from(2).to(1)
      expect(PieceSet.first.quantity).to eql(2)
    end
    it "should not merge piece sets with different keys" do
      ps2 = PieceSet.create!(:quantity=>1,
        :order_line=>@ps.order_line,
        :shipment_line=>@ps.shipment_line,
        :delivery_line=>@ps.delivery_line,
        :drawback_import_line=>@ps.drawback_import_line
        #this one doesn't have a sales_order_line
      )
      expect {PieceSet.merge_duplicates!(ps2)}.to_not change(PieceSet,:count)
      expect(PieceSet.all.collect {|p| p.quantity}).to eql([1,1])
    end
  end

  describe "identifiers" do
    before :each do
      @product = Factory(:product)
      @ps = PieceSet.create!(:quantity=>1,
        :order_line=>Factory(:order_line,:product=>@product),
        :shipment_line=>Factory(:shipment_line,:product=>@product),
        :sales_order_line=>Factory(:sales_order_line,:product=>@product),
        :delivery_line=>Factory(:delivery_line,:product=>@product),
        :drawback_import_line=>Factory(:drawback_import_line,:product=>@product)
      )
      @user = Factory(:user)
    end

    it "returns identifier list for piece set" do
      # Make sure user can vew them all
      ModelField.any_instance.stub(:can_view?).with(@user).and_return true
      ids = @ps.identifiers @user
      expect(ids[:order]).to eq({label: "Order Number", value: @ps.order_line.order.order_number})
      expect(ids[:shipment]).to eq({label: "Reference Number", value: @ps.shipment_line.shipment.reference})
      expect(ids[:sales_order]).to eq({label: "Sale Number", value: @ps.sales_order_line.sales_order.order_number})
      expect(ids[:delivery]).to eq({label: "Reference", value: @ps.delivery_line.delivery.reference})
    end

    it "removes fields user does not have access to" do
      ModelField.any_instance.stub(:can_view?).with(@user).and_return false
      ids = @ps.identifiers @user
      expect(ids).to be_blank
    end
  end

end
