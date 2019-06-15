describe OpenChain::ModelFieldDefinition::BookingLineFieldDefinition do
  before(:each) do
    @olq = ModelField.find_by_uid(:bkln_order_line_quantity)
    @qd = ModelField.find_by_uid(:bkln_quantity_diff)
  end

  describe "bkln_quantity_diff" do
    it 'should handle the booking_line quantity being nil' do
      ol = Factory(:order_line, quantity: 100)
      bl = Factory(:booking_line, order_line: ol)

      expect(@qd.process_export(bl,nil,true)).to eq(1.0)
    end

    it 'should handle the order_line quantity being nil' do
      ol = Factory(:order_line)
      bl = Factory(:booking_line, order_line: ol, quantity: 100)
      ol.update_attribute(:quantity, nil)

      expect(@qd.process_export(bl,nil,true)).to eq(nil)
    end

    it 'should handle both quantities when present' do
      ol = Factory(:order_line, quantity: 50)
      bl = Factory(:booking_line, order_line: ol, quantity: 100)

      expect(@qd.process_export(bl,nil,true)).to eq(200.0)
    end
  end

  describe "bkln_order_line_quantity" do
    it 'should return the booking line\'s quantity' do
      ol = Factory(:order_line, quantity: 100)
      bl = Factory(:booking_line, order_line: ol)

      # test query
      ss = SearchSetup.new(module_type:'Shipment', user_id: Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'bkln_order_line_quantity',operator:'eq',value:'100')
      expect(ss.result_keys).to eq [bl.shipment_id]

      expect(@olq.process_export(bl,nil,true)).to eq(100)
    end
  end
end
