require 'test_helper'

class OrderLineTest < ActiveSupport::TestCase

  test "set_line_number - no existing line number" do
    line = OrderLine.new
    line.order_id = 999
    line.set_line_number
    assert line.line_number == 1, "Line number should have been set to 1, was #{line.line_number}"
  end
  
  test "set_line_number - manually set number" do
    o = Order.find(1)
    line = o.order_lines.build
    line.line_number = 1000
    line.set_line_number
    assert line.line_number == 1000, "Line number should have stayed 1000, was #{line.line_number}"
  end
  
  test "set_line_number - generate next number" do
    o = Order.find(1)
    current_max = 0
    o.order_lines.each do |n|
      current_max = n.line_number if n.line_number > current_max
    end
    line = o.order_lines.build
    line.set_line_number
    assert line.line_number == current_max+1, "Line number should have been set to #{current_max+1}, was #{line.line_number}"
  end

  test "make unpacked piece set" do
    line = OrderLine.find(1)
    #yml should have an existing piece_set w/ qty 10 & line w/ qty 14
    set = line.make_unpacked_piece_set
    assert set.quantity == 4, "quantity check"
    assert set.order_line_id == 1, "order line check"
    assert set.shipment_id.nil?, "shipment should be nil"
    assert set.product_id == 1, "product should be 1"
  end
  
  test "make unpacked piece set - empty" do
    line = OrderLine.find(1)
    line.ordered_qty = 5 #less than existing piece set
    set = line.make_unpacked_piece_set
    assert set.quantity == 0, "quantity check"
    assert set.order_line_id == 1, "order line check"
    assert set.shipment_id.nil?, "shipment should be nil"
    assert set.product_id == 1, "product should be 1"
  end
  
  test "related shipments" do
    line = OrderLine.find(3)
    r = line.related_shipments
    assert r.length ==2, "should be two related shipments"
    found_1 = false
    found_2 = false
    r.each do |s|
      if s.id == 1
        found_1 = true
      elsif s.id == 2
        found_2 = true
      end
    end
    assert found_1, "did not find shipment 1"
    assert found_2, "did not find shipment 2"
  end
  
  test "find same" do
    to_find = OrderLine.first
    base = OrderLine.new
    base.order_id = to_find.order_id
    base.line_number = to_find.line_number
    assert to_find == base.find_same, "did not find matching order line"
    base.order_id = -1
    assert base.find_same.nil?, "should not have found matching line with order_id = -1"
    base.order_id = to_find.order_id
    base.line_number = -1
    assert base.find_same.nil?, "should not have found matching line with line_number = -1"
  end
end
