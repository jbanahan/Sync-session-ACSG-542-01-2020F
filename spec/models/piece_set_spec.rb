describe PieceSet do
  describe 'validations' do
    before :each do
      @product = create(:product)
      @ps = PieceSet.new(:quantity=>1,
        :order_line=>create(:order_line, :product=>@product),
        :shipment_line=>create(:shipment_line, :product=>@product),
        :sales_order_line=>create(:sales_order_line, :product=>@product),
        :delivery_line=>create(:delivery_line, :product=>@product),
        :drawback_import_line=>create(:drawback_import_line, :product=>@product)
      )
    end
    it 'should pass with all products the same' do
      expect(@ps.save).to be_truthy
    end
    it 'should fail with a different product on an associated line' do
      order_line = @ps.order_line
      order_line.product = create(:product)
      order_line.save!
      expect(@ps.save).to be_falsey
      expect(@ps.errors.full_messages).to include "Data Integrity Error: Piece Set cannot be saved with multiple linked products."
    end
    it 'should fail with different product on DrawbackImportLine' do
      d = @ps.drawback_import_line
      d.product = create(:product)
      expect(@ps.save).to be_falsey
      expect(@ps.errors.full_messages).to include "Data Integrity Error: Piece Set cannot be saved with multiple linked products."
    end
  end

  describe "destroy_if_one_key!" do
    it "should destroy if only has one foreign key" do
      product = create(:product)
      ps = PieceSet.create!(:quantity=>1,
        :order_line=>create(:order_line, :product=>product)
      )
      expect(ps.destroy_if_one_key).to be_truthy
      expect(PieceSet.count).to eq 0
    end
    it "should not destroy if has multiple foreign_keys" do
      product = create(:product)
      ps = PieceSet.create!(:quantity=>1,
        :order_line=>create(:order_line, :product=>product),
        :shipment_line=>create(:shipment_line, :product=>product)
      )
      expect(ps.destroy_if_one_key).to be_falsey
      expect(PieceSet.count).to eq 1
    end
  end

  describe 'merge_duplicates' do
    before :each do
      @product = create(:product)
      @ps = PieceSet.create!(:quantity=>1,
        :order_line=>create(:order_line, :product=>@product),
        :shipment_line=>create(:shipment_line, :product=>@product),
        :sales_order_line=>create(:sales_order_line, :product=>@product),
        :delivery_line=>create(:delivery_line, :product=>@product),
        :drawback_import_line=>create(:drawback_import_line, :product=>@product)
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
      expect {PieceSet.merge_duplicates!(ps2)}.to change(PieceSet, :count).from(2).to(1)
      expect(PieceSet.first.quantity).to eql(2)
    end
    it "should not merge piece sets with different keys" do
      ps2 = PieceSet.create!(:quantity=>1,
        :order_line=>@ps.order_line,
        :shipment_line=>@ps.shipment_line,
        :delivery_line=>@ps.delivery_line,
        :drawback_import_line=>@ps.drawback_import_line
        # this one doesn't have a sales_order_line
      )
      expect {PieceSet.merge_duplicates!(ps2)}.to_not change(PieceSet, :count)
      expect(PieceSet.all.collect {|p| p.quantity}).to eql([1, 1])
    end

    it "no-ops if the piece set is not linked to anything" do
      expect(PieceSet).not_to receive(:where)
      expect(PieceSet.merge_duplicates! PieceSet.new).to be_nil
    end
  end

  describe "identifiers" do
    before :each do
      @product = create(:product)
      @ps = PieceSet.create!(:quantity=>1,
        :order_line=>create(:order_line, :product=>@product),
        :shipment_line=>create(:shipment_line, :product=>@product),
        :sales_order_line=>create(:sales_order_line, :product=>@product),
        :delivery_line=>create(:delivery_line, :product=>@product),
        :drawback_import_line=>create(:drawback_import_line, :product=>@product)
      )
      @user = create(:user)
    end

    it "returns identifier list for piece set" do
      # Make sure user can vew them all
      allow_any_instance_of(ModelField).to receive(:can_view?).with(@user).and_return true
      ids = @ps.identifiers @user
      expect(ids[:order]).to eq({label: "Order Number", value: @ps.order_line.order.order_number})
      expect(ids[:shipment]).to eq({label: "Reference Number", value: @ps.shipment_line.shipment.reference})
      expect(ids[:sales_order]).to eq({label: "Sale Number", value: @ps.sales_order_line.sales_order.order_number})
      expect(ids[:delivery]).to eq({label: "Reference", value: @ps.delivery_line.delivery.reference})
    end

    it "removes fields user does not have access to" do
      allow_any_instance_of(ModelField).to receive(:can_view?).with(@user).and_return false
      ids = @ps.identifiers @user
      expect(ids).to be_blank
    end
  end

  describe "foreign_key_values" do
    subject {
      ps = PieceSet.new
      ps.order_line_id = 1
      ps.sales_order_line_id = 1
      ps.shipment_line_id = 1
      ps.delivery_line_id = 1
      ps.commercial_invoice_line_id = 1
      ps.drawback_import_line_id = 1
      ps.security_filing_line_id = 1
      ps.booking_line_id = 1

      ps
    }

    it "returns values of all foreign key columns used for piece set linkages" do
      expect(subject.foreign_key_values).to eq({
        order_line_id: 1, sales_order_line_id: 1, shipment_line_id: 1, delivery_line_id: 1, commercial_invoice_line_id: 1,
        drawback_import_line_id: 1, security_filing_line_id: 1, booking_line_id: 1
      })
    end
  end

  describe "foreign_key_count" do

    subject {
      ps = PieceSet.new
      ps.order_line_id = 1
      ps.sales_order_line_id = 1
      ps.shipment_line_id = 1
      ps.delivery_line_id = 1
      ps.commercial_invoice_line_id = 1
      ps.drawback_import_line_id = 1
      ps.security_filing_line_id = 1
      ps.booking_line_id = 1
      ps.milestone_plan_id = 1

      ps
    }

    it "returns the number of foreign keys associated with the piece set" do
      expect(subject.foreign_key_count).to eq 8
    end

    it "returns zero if no foreign keys" do
      expect(PieceSet.new.foreign_key_count).to eq 0
    end
  end

  describe "linked_to_anything?" do
    it "returns true if there are any foreign keys" do
      p = PieceSet.new
      p.order_line_id = 1
      expect(p.linked_to_anything?).to eq true
    end

    it "returns false if there aren't any foreign keys" do
      expect(PieceSet.new.linked_to_anything?).to eq false
    end
  end

end
