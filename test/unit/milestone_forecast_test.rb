require 'test_helper'

class MilestoneForecastTest < ActiveSupport::TestCase
  
  test "actual" do
    od = CustomDefinition.create!(:label=>"od", :module_type=>"Order", :data_type=>:date)
    mp = MilestonePlan.create!(:name=>"MFT")
    md = mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{od.id}")

    o = Order.create!(:order_number=>"mfta",:vendor_id=>companies(:vendor).id)
    cv = o.get_custom_value od
    cv.value = 3.days.ago.to_date
    cv.save!
    o_line = o.order_lines.create!(:product_id=>Product.where(:vendor_id=>o.vendor_id).first.id,:quantity=>10)
    ps = o_line.piece_sets.create!(:quantity=>o_line.quantity,:milestone_plan_id=>mp.id)

    ps.create_forecasts

    mf = ps.milestone_forecasts.first
    assert_equal cv.value, mf.actual
  end

end
