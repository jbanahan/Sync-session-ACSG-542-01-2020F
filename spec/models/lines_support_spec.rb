describe LinesSupport do
  describe "default_line_number" do
    it "should create line numbers for in memory lines" do
      p = Factory(:product)
      s = Shipment.new(reference:'abc')
      sl1 = s.shipment_lines.build(quantity:1,product_id:p.id)
      sl2 = s.shipment_lines.build(quantity:2,product_id:p.id)
      s.save!
      s.reload
      expect(s.shipment_lines.collect {|sl| sl.line_number}).to eq [1,2]
    end
  end
  context 'piece sent linking' do
    it 'should link shipment to order' do
      s_line = Factory(:shipment_line)
      o_line = Factory(:order_line,:product=>s_line.product)
      s_line.linked_order_line_id = o_line.id
      expect(s_line.save).to be_truthy
      expect(PieceSet.count).to eq(1)
      expect(PieceSet.where(:shipment_line_id=>s_line.id).where(:order_line_id=>o_line.id).count).to eq(1)
    end
    it 'should link shipment to order and delivery' do #testing multiple links
      s_line = Factory(:shipment_line)
      d_line = Factory(:delivery_line,:product=>s_line.product)
      o_line = Factory(:order_line,:product=>s_line.product)
      s_line.linked_order_line_id = o_line.id
      s_line.linked_delivery_line_id = d_line.id
      expect(s_line.save).to be_truthy

      expect(PieceSet.count).to eq(2)

      expect(PieceSet.where(:shipment_line_id=>s_line.id).where(:order_line_id=>o_line.id).count).to eq(1)
      expect(PieceSet.where(:shipment_line_id=>s_line.id).where(:delivery_line_id=>d_line.id).count).to eq(1)
    end
    it 'should link commercial invoice line to drawback import line' do
      c_line = Factory(:commercial_invoice_line,:quantity=>1)
      d_line = Factory(:drawback_import_line)
      c_line.linked_drawback_import_line_id = d_line.id
      expect(c_line.save).to be_truthy

      expect(PieceSet.count).to eq(1)
      expect(PieceSet.find_by(drawback_import_line_id: d_line.id, commercial_invoice_line_id: c_line.id)).not_to be_nil
    end
    it 'should link drawback import line to commercial invoice line' do
      c_line = Factory(:commercial_invoice_line)
      d_line = Factory(:drawback_import_line,:quantity=>1)
      d_line.linked_commercial_invoice_line_id = c_line.id
      expect(d_line.save).to be_truthy

      expect(PieceSet.count).to eq(1)
      expect(PieceSet.find_by(drawback_import_line_id: d_line.id, commercial_invoice_line_id: c_line.id)).not_to be_nil
    end
  end

  describe "merge_piece_sets" do 
    it "merges two piece sets together that are associated with the same object being destroyed" do
      order_line = Factory(:order_line)
      shipment_line_1 = Factory(:shipment_line, product: order_line.product, linked_order_line_id: order_line.id)
      shipment_line_2 = Factory(:shipment_line, product: order_line.product, linked_order_line_id: order_line.id)
      order_line.reload

      expect(order_line.piece_sets.length).to eq 2
      expect(PieceSet).to receive(:merge_duplicates!).with(order_line.piece_sets.first)
      expect(PieceSet).to receive(:merge_duplicates!).with(order_line.piece_sets.second)

      order_line.merge_piece_sets

      shipment_line_1.reload
      expect(shipment_line_1.piece_sets.length).to eq 1
      expect(shipment_line_1.piece_sets.first.order_line_id).to be_nil
    end

    it "deletes piece sets that are no longer referenced to anything" do
      order_line = Factory(:order_line)
      order_line.linked_order_line_id = order_line.id
      order_line.save!
      expect(order_line.piece_sets.length).to eq 1

      expect(PieceSet).not_to receive(:merge_duplicates!)

      order_line.merge_piece_sets
      order_line.reload
      expect(order_line.piece_sets.length).to eq 0
    end
  end
end
