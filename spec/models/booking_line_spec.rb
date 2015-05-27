require 'spec_helper'

describe BookingLine do
  describe 'when validating' do
    it 'order_line takes priority over order and product' do
      line = BookingLine.create! order_id:1, order_line_id:1, product_id:1
      expect(line.order_id).to be_nil
      expect(line.order_line_id).to eq 1
      expect(line.product_id).to be_nil
    end
  end
end
