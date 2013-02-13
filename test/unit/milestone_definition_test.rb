require 'test_helper'

class MilestoneDefinitionTest < ActiveSupport::TestCase

  def setup
    @order_date = CustomDefinition.create!(:label=>"Order Date", :module_type=>"Order", :data_type=>:date)
    @ship_date = CustomDefinition.create!(:label=>"Ship Date", :module_type=>"Shipment", :data_type=>:date)
    @mp = MilestonePlan.create!(:name=>"testmp")
    @order_md = @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{@order_date.id}")
    @shipment_md = @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{@ship_date.id}",:previous_milestone_definition_id=>@order_md.id,:days_after_previous=>30,:final_milestone=>true)
  end
  
  test "plan" do
    p = Product.where(:vendor_id=>companies(:vendor).id).first
    ord = Order.create!(:order_number=>"ordnum",:vendor_id=>companies(:vendor).id)
    o_line = ord.order_lines.create!(:product_id=>p.id,:quantity=>100,:line_number=>1)
    ps = o_line.piece_sets.create!(:quantity=>100)

    assert_nil @order_md.plan(ps)
    assert_nil @shipment_md.plan(ps)

    order_cv = ord.get_custom_value @order_date
    order_cv.value = Time.now
    order_cv.save!
    order_cv.reload #to ensure correct data type for equality match

    assert_equal 0.days.ago.to_date, @order_md.plan(ps)
    assert_equal 30.days.from_now.to_date, @shipment_md.plan(ps)

    shp = Shipment.create!(:reference=>"shprf",:vendor_id=>ord.vendor_id)
    s_line = shp.shipment_lines.create!(:product_id=>p.id,:quantity=>100,:line_number=>1)
    ps.update_attributes!(:shipment_line_id=>s_line.id)
    shp_cv = shp.get_custom_value @ship_date
    shp_cv.value = 2.days.from_now.to_date
    shp_cv.save!
    shp_cv.reload

    #putting an actual value in the second milestone date shouldn't change the plan that's generated
    assert_equal 0.days.ago.to_date, @order_md.plan(ps)
    assert_equal 30.days.from_now.to_date, @shipment_md.plan(ps)
  end

  test "relationship traversal" do
=begin
 Chain of definitions looks like
     base
      /  \
   d2a  d3
    /
  d2b
=end
    defs = []
    4.times do |i|
      defs << CustomDefinition.create!(:label=>"cd#{i}",:module_type=>"Order",:data_type=>:date)
    end
    mplan = MilestonePlan.create!(:name=>"rtmp")
    base = mplan.milestone_definitions.create!(:model_field_uid=>"*cf_#{defs[0].id}")
    d2a = mplan.milestone_definitions.create!(:model_field_uid=>"*cf_#{defs[1].id}",:previous_milestone_definition_id=>base.id,:days_after_previous=>1)
    d2b = mplan.milestone_definitions.create!(:model_field_uid=>"*cf_#{defs[2].id}",:previous_milestone_definition_id=>d2a.id,:days_after_previous=>3,:final_milestone=>true)
    d3 =  mplan.milestone_definitions.create!(:model_field_uid=>"*cf_#{defs[3].id}",:previous_milestone_definition_id=>base.id,:days_after_previous=>2)

    #done setup
    base_next = base.next_milestone_definitions
    assert_equal 2, base_next.size
    bn_ids = base_next.collect{|m| m.id}.sort!
    assert_equal [d2a.id,d3.id].sort!, bn_ids
    assert_equal 1, d2a.next_milestone_definitions.size
    assert_equal d2b, d2a.next_milestone_definitions.first

    assert_equal d2a, d2b.previous_milestone_definition
    assert_equal base, d2a.previous_milestone_definition
    assert_equal base, d3.previous_milestone_definition
    assert_nil base.previous_milestone_definition
  end

  test "forecast" do
    #add 3rd item to chain before testing
    @shipment_md.update_attributes!(:final_milestone=>false)
    @s2_date = CustomDefinition.create!(:label=>"S2",:module_type=>"Shipment", :data_type=>:date)
    @s2_md = @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{@s2_date.id}",:previous_milestone_definition_id=>@shipment_md.id,:days_after_previous=>15,:final_milestone=>true)


    p = Product.where(:vendor_id=>companies(:vendor).id).first
    ord = Order.create!(:order_number=>"ordnum",:vendor_id=>companies(:vendor).id)
    o_line = ord.order_lines.create!(:product_id=>p.id,:quantity=>100,:line_number=>1)
    ps = o_line.piece_sets.create!(:quantity=>100)

    assert_nil @order_md.forecast(ps)
    assert_nil @shipment_md.forecast(ps)
    assert_nil @s2_md.forecast(ps)

    order_cv = ord.get_custom_value @order_date
    order_cv.value = Time.now
    order_cv.save!
    order_cv.reload #to ensure correct data type for equality match

    assert_equal 0.days.ago.to_date, @order_md.forecast(ps)
    assert_equal 30.days.from_now.to_date, @shipment_md.forecast(ps)
    assert_equal 45.days.from_now.to_date, @s2_md.forecast(ps)

    shp = Shipment.create!(:reference=>"shprf",:vendor_id=>ord.vendor_id)
    s_line = shp.shipment_lines.create!(:product_id=>p.id,:quantity=>100,:line_number=>1)
    ps.update_attributes!(:shipment_line_id=>s_line.id)

    assert_equal 30.days.from_now.to_date, @shipment_md.forecast(ps)
    assert_equal 45.days.from_now.to_date, @s2_md.forecast(ps)

    shp_cv = shp.get_custom_value @ship_date
    shp_cv.value = 2.days.from_now.to_date
    shp_cv.save!
    shp_cv.reload

    assert_equal 2.days.from_now.to_date, @shipment_md.forecast(ps)
    assert_equal 17.days.from_now.to_date, @s2_md.forecast(ps)

    s2_cv = shp.get_custom_value @s2_date
    s2_cv.value = 13.days.from_now.to_date
    s2_cv.save!
    s2_cv.reload

    assert_equal 13.days.from_now.to_date, @s2_md.forecast(ps)

  end
end
