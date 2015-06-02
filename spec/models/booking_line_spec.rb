require 'spec_helper'

describe BookingLine do
  describe 'when validating' do
    describe 'when order line id is present' do
      it 'the line is invalid if product id is present' do
        line = BookingLine.new product_id:1, order_line_id:1
        expect(line).to be_invalid
      end

      it 'the line is invalid if order id is present' do
        line = BookingLine.new order_id:1, order_line_id:1
        expect(line).to be_invalid
      end

      it 'the line is valid if order and product are not present' do
        line = BookingLine.new order_line_id:1
        expect(line).to be_valid
      end
    end
  end
end
