require 'test_helper'

class PieceSetTest < ActiveSupport::TestCase

  test "can change milestone plan" do
    #must be able to edit all associated objects
    ven_id = companies(:vendor).id
    o = Order.create!(:order_number=>'ordnum123',:vendor_id=>ven_id)
    o_line = o.order_lines.create!(:line_number=>1,:product_id=>Product.where(:vendor_id=>o.vendor_id).first.id, :quantity=>10)
    s = Shipment.create!(:reference=>"sref123",:vendor_id=>ven_id)
    s_line = s.shipment_lines.create!(:line_number=>1,:product_id=>o_line.product_id,:quantity=>10)
    so = SalesOrder.create!(:order_number=>"sonum123",:customer_id=>companies(:customer).id)
    so_line = so.sales_order_lines.create!(:line_number=>1,:product_id=>o_line.product_id,:quantity=>10)
    d = Delivery.create!(:reference=>"dref123",:customer_id=>so.customer_id)
    d_line = d.delivery_lines.create!(:line_number=>1,:product_id=>o_line.product_id,:quantity=>10)

    ps = PieceSet.create!(:order_line_id=>o_line.id,:shipment_line_id=>s_line.id,:sales_order_line_id=>so_line.id,:delivery_line_id=>d_line.id,:quantity=>10)
    

    u = users(:masteruser)
    Order.any_instance.stubs(:can_edit?).returns(true,false,true,true,true)
    Shipment.any_instance.stubs(:can_edit?).returns(true,false,true,true)
    SalesOrder.any_instance.stubs(:can_edit?).returns(true,false,true)
    Delivery.any_instance.stubs(:can_edit?).returns(true,false)

    assert ps.change_milestone_plan?(u)
    

    4.times { |i| assert !ps.change_milestone_plan?(u), "Failed on pass #{i}" }
  end

  test "identifiers" do
    ven_id = companies(:vendor).id
    o = Order.create!(:order_number=>'ordnum123',:vendor_id=>ven_id)
    o_line = o.order_lines.create!(:line_number=>1,:product_id=>Product.where(:vendor_id=>o.vendor_id).first.id, :quantity=>10)
    s = Shipment.create!(:reference=>"sref123",:vendor_id=>ven_id)
    s_line = s.shipment_lines.create!(:line_number=>1,:product_id=>o_line.product_id,:quantity=>10)
    so = SalesOrder.create!(:order_number=>"sonum123",:customer_id=>companies(:customer).id)
    so_line = so.sales_order_lines.create!(:line_number=>1,:product_id=>o_line.product_id,:quantity=>10)
    d = Delivery.create!(:reference=>"dref123",:customer_id=>so.customer_id)
    d_line = d.delivery_lines.create!(:line_number=>1,:product_id=>o_line.product_id,:quantity=>10)

    ps = PieceSet.create!(:order_line_id=>o_line.id,:shipment_line_id=>s_line.id,:sales_order_line_id=>so_line.id,:delivery_line_id=>d_line.id,:quantity=>10)
    
    r = ps.identifiers

    assert_equal ModelField.find_by_uid(:ord_ord_num).label, r[:order][:label]
    assert_equal o.order_number, r[:order][:value]
    assert_equal ModelField.find_by_uid(:shp_ref).label, r[:shipment][:label]
    assert_equal s.reference, r[:shipment][:value]
    assert_equal ModelField.find_by_uid(:sale_order_number).label, r[:sales_order][:label]
    assert_equal so.order_number, r[:sales_order][:value]
    assert_equal ModelField.find_by_uid(:del_ref).label, r[:delivery][:label]
    assert_equal d.reference, r[:delivery][:value]
  end

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
    assert ps.milestone_forecast_set.blank?
    ps.milestone_plan = mp
    ps.build_forecasts

    assert_equal 1, ps.milestone_forecast_set.milestone_forecasts.size
    f = ps.milestone_forecast_set.milestone_forecasts.first
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
