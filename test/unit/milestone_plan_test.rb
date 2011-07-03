require 'test_helper'

class MilestonePlanTest < ActiveSupport::TestCase

  def setup
    @order_date = CustomDefinition.create!(:label=>"Order Date", :module_type=>"Order", :data_type=>:date)
    @ship_date = CustomDefinition.create!(:label=>"Ship Date", :module_type=>"Shipment", :data_type=>:date)
    @mp = MilestonePlan.create!(:name=>"testmp")
    @order_md = @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{@order_date.id}")
    @shipment_md = @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{@ship_date.id}",:previous_milestone_definition_id=>@order_md.id,:days_after_previous=>30,:final_milestone=>true)
  end

  test "build plan after events happened" do
    o = Order.create!(:order_number=>"mptbf",:vendor_id=>companies(:vendor).id)
    o_line = o.order_lines.create!(:line_number=>1, :product_id=>Product.where(:vendor_id=>o.vendor_id).first.id, :quantity=>50)
    cv = o.get_custom_value @order_date
    cv.value = 2.days.ago.to_date
    cv.save!

    s = Shipment.create!(:reference=>"shrp",:vendor_id=>companies(:vendor).id)
    s_line = s.shipment_lines.create(:line_number=>1, :product_id=>o_line.product_id, :quantity=>o_line.quantity)
    cv = s.get_custom_value @ship_date
    cv.value = 1.day.ago.to_date
    cv.save!

    ps = PieceSet.create!(:order_line_id=>o_line.id,:shipment_line_id=>s_line.id,:quantity=>o_line.quantity)

    @mp.build_forecasts ps
    expected_defs = [@order_md,@shipment_md]
    forecasts = ps.milestone_forecast_set.milestone_forecasts
    forecasts.each {|f| expected_defs.delete f.milestone_definition}
    assert expected_defs.empty?

    forecasts.each do |f|
      case f.milestone_definition
      when @order_md
        assert_equal 2.days.ago.to_date, f.planned
        assert_equal 2.days.ago.to_date, f.forecast
      when @shipment_md
        assert_equal 28.days.from_now.to_date, f.planned
        assert_equal 1.days.ago.to_date, f.forecast
      else
        flunk "Unexpected milestone definition found: #{f.milestone_definition}"
      end
    end
  end

  test "build forecast" do
    o = Order.create!(:order_number=>"mptbf",:vendor_id=>companies(:vendor).id)
    o_line = o.order_lines.create!(:line_number=>1, :product_id=>Product.where(:vendor_id=>o.vendor_id).first.id, :quantity=>50)
    ps = o_line.piece_sets.create!(:quantity=>50)
    cv = o.get_custom_value @order_date
    cv.value = 2.days.ago.to_date
    cv.save!

    @mp.build_forecasts ps
    
    assert_not_nil ps.milestone_forecast_set
    forecasts = ps.milestone_forecast_set.milestone_forecasts
    assert_equal 2, forecasts.size
    expected_defs = [@order_md,@shipment_md]
    forecasts.each {|f| expected_defs.delete f.milestone_definition}
    assert_equal 0, expected_defs.size

    forecasts.each do |f|
      case f.milestone_definition
      when @order_md
        assert_equal 2.days.ago.to_date, f.planned
        assert_equal 2.days.ago.to_date, f.forecast
      when @shipment_md
        assert_equal 28.days.from_now.to_date, f.planned
        assert_equal 28.days.from_now.to_date, f.forecast
      else
        flunk "Unexpected milestone definition found: #{f.milestone_definition}"
      end
    end

    #change date and reforecast
    cv.value = 1.day.ago.to_date
    cv.save!

    @mp.build_forecasts ps

    forecasts = ps.milestone_forecast_set.milestone_forecasts
    assert_equal 2, forecasts.size
    forecasts.each do |f|
      case f.milestone_definition
      when @order_md
        assert_equal 2.days.ago.to_date, f.planned
        assert_equal 1.days.ago.to_date, f.forecast
      when @shipment_md
        assert_equal 28.days.from_now.to_date, f.planned
        assert_equal 29.days.from_now.to_date, f.forecast
      else
        flunk "Unexpected milestone definition found: #{f.milestone_definition}"
      end
    end
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
