require 'test_helper'

class ShipmentLineTest < ActiveSupport::TestCase

  test "related orders" do
    shp = Shipment.create!(:reference=>"relor",:vendor=>companies(:vendor))
    sline = shp.shipment_lines.create!(:product=>companies(:vendor).vendor_products.first,:quantity=>10)
    oline = Order.create!(:order_number=>'srelor',:vendor=>shp.vendor).order_lines.create!(:product=>sline.product,:quantity=>20)
    oline2 = Order.create!(:order_number=>'srelor2',:vendor=>shp.vendor).order_lines.create!(:product=>sline.product,:quantity=>1999)
    ps = PieceSet.create!(:order_line=>oline,:shipment_line=>sline,:quantity=>2)
    ps2 = PieceSet.create!(:order_line=>oline2,:shipment_line=>sline,:quantity=>8)
    
    r = sline.related_orders
    assert r.size==2, "Should have found 2 orders, found #{r.size}"
    [oline.order,oline2.order].each {|o| assert r.include?(o), "Should have found order #{o.order_number}, didn't."}

  end
end
