describe CustomViewTemplate do
  describe '#for_object' do
    before do
      cvt = described_class.create!(template_identifier: 'sample', template_path: '/x', module_type: "Order")
      cvt.search_criterions.create!(model_field_uid: 'ord_ord_num', operator: 'eq', value: 'ABC')
    end

    it 'returns nil for no template identifier match' do
      o = Order.new(order_number: 'ABC')
      expect(described_class.for_object('other', o)).to be_nil
    end

    it 'returns nil for no search criterion match' do
      o = Order.new(order_number: 'BAD')
      expect(described_class.for_object('sample', o)).to be_nil
    end

    it 'returns template for match' do
      o = Order.new(order_number: 'ABC')
      expect(described_class.for_object('sample', o)).to eq '/x'
    end

    it "returns default for no match" do
      expect(described_class.for_object('other', Order.new, '/y')).to eq '/y'
    end
  end
end
