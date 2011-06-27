require 'test_helper'

class PieceSetTest < ActiveSupport::TestCase

  test "build forecasts" do
    o = Order.create!(:order_number=>'pstbf',:vendor_id=>companies(:vendor).id)
    o_line = o.order_lines.create!(:line_number=>1,:product_id=>Product.where(:vendor_id=>o.vendor_id).first.id, :quantity=>10)
    ps = o_line.piece_sets.create!(:quantity=>o_line.quantity)
    cv = o.get_custom_value(CustomDefinition.create!(:label=>"cd1",:module_type=>"Order",:data_type=>:date))
    cv.value=1.day.ago
    cv.save!

    mp = MilestonePlan.create!(:name=>"mp")
    md = mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{cv.custom_definition_id}")

    ps.build_forecasts #shouldn't do anything because milestone plan isn't set
    assert ps.milestone_forecasts.blank?
    ps.milestone_plan = mp
    ps.build_forecasts

    assert_equal 1, ps.milestone_forecasts.size
    f = ps.milestone_forecasts.first
    assert_equal md, f.milestone_definition
    assert_equal 1.day.ago.to_date, f.planned
    assert_equal 1.day.ago.to_date, f.forecast
  end

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
