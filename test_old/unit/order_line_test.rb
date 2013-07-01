require 'test_helper'

class OrderLineTest < ActiveSupport::TestCase

  test "set_line_number - no existing line number" do
    
    line = Order.create(:order_number=>"lnum",:vendor=>companies(:vendor)).order_lines.build(:quantity=>5,:product=>companies(:vendor).vendor_products.first)
    line.save!
    assert line.line_number == 1, "Line number should have been set to 1, was #{line.line_number}"
  end
  
  test "set_line_number - manually set number" do
    line = Order.create(:order_number=>"lnum",:vendor=>companies(:vendor)).order_lines.build(:quantity=>5,:product=>companies(:vendor).vendor_products.first)
    line.line_number = 1000
    line.save!
    assert line.line_number == 1000, "Line number should have stayed 1000, was #{line.line_number}"
  end
  
  test "set_line_number - generate next number" do
    line = Order.create(:order_number=>"lnum",:vendor=>companies(:vendor)).order_lines.build(:quantity=>5,:product=>companies(:vendor).vendor_products.first)
    line.line_number = 1000
    line.save!
    line2 = line.order.order_lines.create!(:quantity=>5,:product=>line.product)
    assert line2.line_number == 1001, "Line number should have been set to 1001, was #{line.line_number}"
  end

  test "related shipments" do
    ord = Order.create!(:order_number=>"related_shipments",:vendor => companies(:vendor))
    oline = ord.order_lines.create!(:product=>ord.vendor.vendor_products.first,:quantity=>100)
    ps = oline.piece_sets.create!(:quantity=>5)
    shp = Shipment.create!(:reference=>"related_shipments",:vendor_id => ord.vendor_id)
    sline = shp.shipment_lines.create!(:product=>oline.product)
    ps.shipment_line = sline
    ps.save!
    ps2 = oline.piece_sets.create!(:quantity=>3)
    shp2 = Shipment.create!(:reference=>"related_shipments2",:vendor_id=>ord.vendor_id)
    sline2 = shp2.shipment_lines.create!(:product=>oline.product)
    ps2.shipment_line = sline2
    ps2.save!
    line = OrderLine.find(3)
    r = oline.related_shipments.to_a
    assert r.length ==2, "should be two related shipments, there are "+r.length.to_s
    [shp,shp2].each do |s|
      assert r.include?(shp), "Did not find shipment with reference #{shp.reference}, #{r.to_s}"
    end
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
  
  test "locked" do
    base = OrderLine.first
    assert !base.locked?, "Should not be locked at begining."
    base.order.vendor.locked = true
    assert base.locked?, "Should be locked because order vendor is locked."
    base.order.vendor.locked = false
    assert !base.locked?, "Should not be locked after unlocking vendor."
  end
  
end
