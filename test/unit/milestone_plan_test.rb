require 'test_helper'

class MilestonePlanTest < ActiveSupport::TestCase

  def setup
    @order_date = CustomDefinition.create!(:label=>"Order Date", :module_type=>"Order", :data_type=>:date)
    @ship_date = CustomDefinition.create!(:label=>"Ship Date", :module_type=>"Shipment", :data_type=>:date)
    @mp = MilestonePlan.create!(:name=>"testmp")
    @order_md = @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{@order_date.id}")
    @shipment_md = @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{@ship_date.id}",:previous_milestone_definition_id=>@order_md.id,:days_after_previous=>30,:final_milestone=>true)
  end

  test "forecast" do
    #add 3rd item to chain before testing
    @shipment_md.update_attributes!(:final_milestone=>false)
    @s2_date = CustomDefinition.create!(:label=>"S2",:module_type=>"Shipment", :data_type=>:date)
    @s2_md = @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{@s2_date.id}",:previous_milestone_definition_id=>@shipment_md.id,:days_after_previous=>15,:final_milestone=>true)


    p = Product.where(:vendor_id=>companies(:vendor).id).first
    ord = Order.create!(:order_number=>"ordnum",:vendor_id=>companies(:vendor).id)
    o_line = ord.order_lines.create!(:product_id=>p,:quantity=>100,:line_number=>1)
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
    s_line = shp.shipment_lines.create!(:product_id=>p,:quantity=>100,:line_number=>1)
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
  test "only one starting definition" do
    mp = MilestonePlan.create!(:name=>"oosd")
    md1 = mp.milestone_definitions.build(:model_field_uid=>"*cf_#{@order_date.id}")
    assert mp.save
    assert !md1.id.nil?
    md2 = mp.milestone_definitions.build(:model_field_uid=>"*cf_#{@ship_date.id}")
    assert !mp.save
    assert_equal "You can only have one starting milestone.", mp.errors.full_messages.first
  end

  test "only one finish definition" do
    mp = MilestonePlan.create!(:name=>"oofd")
    md1 = mp.milestone_definitions.build(:model_field_uid=>"*cf_#{@order_date.id}",:final_milestone=>true)
    assert mp.save
    assert !md1.id.nil?
    mp.milestone_definitions.build(:model_field_uid=>"*cf_#{@ship_date.id}",:final_milestone=>true,:previous_milestone_definition_id=>md1.id)
    assert !mp.save
    assert_equal "You can only have one final milestone.", mp.errors.full_messages.first
  end
end
