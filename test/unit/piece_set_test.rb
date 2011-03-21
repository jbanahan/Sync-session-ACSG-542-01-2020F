require 'test_helper'

class PieceSetTest < ActiveSupport::TestCase
  test "quantity greater than zero" do
    p = PieceSet.find(1)
    p.quantity = -1
    p.save
    err = p.errors[:quantity] 
    assert err.size==1, "Did not find quantity error."
  end
  
  test "validate product integrity" do
    v = companies(:vendor)
    c = Company.where(:customer=>true).first
    p1 = Product.create!(:vendor => v, :unique_identifier=>"puid1vpi")
    p2 = Product.create!(:vendor => v, :unique_identifier=>"puid2vpi")
    oline = Order.create!(:order_number=>"vpi",:vendor=>v).order_lines.create!(:product=>p1,:quantity=>10)
    sline = Shipment.create!(:reference=>"vpi",:vendor=>v).shipment_lines.create!(:product=>p1,:quantity=>20)
    soline = SalesOrder.create!(:order_number=>"vpi",:customer=>c).sales_order_lines.create!(:product=>p1,:quantity=>5)
    dline = Delivery.create!(:reference=>"vpi",:customer=>c).delivery_lines.create!(:product=>p1,:quantity=>15)
    ps = PieceSet.new(:order_line=>oline,:sales_order_line=>soline,:shipment_line=>sline,:delivery_line=>dline,:quantity=>8)
    assert ps.save, "Should save ok, didn't: #{ps.errors.full_messages}"
    oline2 = oline.order.order_lines.create!(:product=>p2,:quantity=>51)
    ps.order_line=oline2
    assert !ps.save, "Shouldn't save because order line has different product."
    assert ps.errors.full_messages.include?("Data Integrity Error: Piece Set cannot be saved with multiple linked products.")

  end

end
