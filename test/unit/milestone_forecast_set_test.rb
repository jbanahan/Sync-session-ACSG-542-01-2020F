require 'test_helper'

class MilestoneForecastSetTest < ActiveSupport::TestCase 

  def setup
    generic_forecast_setup #test_helper method
  end

  test "find forecast by definition" do
    md1 = @mp.milestone_definitions.create!(:model_field_uid=>:ord_ord_date,:previous_milestone_definition_id=>@md.id,:days_after_previous=>1)

    @ps.create_forecasts
    @ps.reload

    forecast_set = @ps.milestone_forecast_set

    f = forecast_set.find_forecast_by_definition @md
    assert_equal @md, f.milestone_definition
    f = forecast_set.find_forecast_by_definition md1
    assert_equal md1, f.milestone_definition
  end

=begin
  test "clear bad forecasts" do
    cd1 = CustomDefinition.create!(:label=>"cd",:module_type=>"Shipment",:data_type=>:date)
    cd2 = CustomDefinition.create!(:label=>"cd2",:module_type=>"Shipment",:data_type=>:date)
    md0 = @mp.milestone_definitions.create!(:model_field_uid=>"ord_ord_date",:previous_milestone_definition_id=>@md.id,:days_after_previous=>1)
    md1 = @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{cd1.id}",:previous_milestone_definition_id=>md0.id,:days_after_previous=>1)
    md2 = @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{cd2.id}",:previous_milestone_definition_id=>md1.id,:days_after_previous=>1)

    ms = MilestoneForecastSet.create!(:piece_set_id=>@ps.id) 
    mfo = ms.milestone_forecasts.create!(:forecast=>@md.forecast(@ps),:milestone_definition_id=>@md.id)
    mf0 = ms.milestone_forecasts.create!(:forecast=>md0.forecast(@ps),:milestone_definition_id=>md0.id)
    mf1 = ms.milestone_forecasts.create!(:forecast=>md1.forecast(@ps),:milestone_definition_id=>md1.id)
    mf2 = ms.milestone_forecasts.create!(:forecast=>md2.forecast(@ps),:milestone_definition_id=>md2.id)

    [mf0,mf1,mf2].each {|mf| assert !mf.forecast.nil?}
    assert_equal 2.days.ago.to_date, mf0.forecast

    ms.clear_bad_forecasts
    forecasts  = ms.milestone_forecasts
    assert_equal 4, forecasts.size
    expected = [@md,md0,md1,md2]
    forecasts.each {|f| expected.delete f.milestone_definition}
    assert expected.empty?

    forecasts.each do |f|
      case f.milestone_definition
      when @md
        assert_equal 3.days.ago.to_date, f.forecast
      when md0
        assert_equal 2.days.ago.to_date, f.forecast
      when md1
        assert_nil f.forecast
      when md2
        assert_nil f.forecast
      end
    end
  end
=end
  test "auto set state" do
=begin
  ultimately, the test builds the following strucuture based on order dates

         @od (starting date)
         /                 \
 ord_ord_date(50 days)   c_def (1 day, final)

=end

    #reset starting value to nothing
    @cv.value = nil
    @cv.save!
    @ps.create_forecasts
    ms = @ps.milestone_forecast_set
    assert_equal "Unplanned", ms.state

    @cv.value = 3.days.ago
    @cv.save!
    @ps.create_forecasts
    ms = @ps.milestone_forecast_set
    assert_equal "Achieved", ms.state

    #add a milestone that isn't achieved or overdue
    @mp.milestone_definitions.create!(:model_field_uid=>"ord_ord_date",:previous_milestone_definition_id=>@md.id,:days_after_previous=>50)
    @ps.reload
    @ps.create_forecasts
    ms = @ps.milestone_forecast_set
    assert_equal "Pending", ms.state

    #add another milestone that is overdue, is less then the other pending and is marked as final
    c_def = CustomDefinition.create(:label=>"astate", :module_type=>"Order", :data_type=>:date)
    #don't create a value 
    @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{c_def.id}",:previous_milestone_definition_id=>@md.id,:days_after_previous=>1,:final_milestone=>true)
    
    @ps.reload
    @ps.create_forecasts
    ms = @ps.milestone_forecast_set
    assert_equal "Overdue", ms.state

    #complete "final" milestone, leaving 50 day milestone incomplete should mark the set as Missed
    cv = @ps.order_line.order.get_custom_value c_def
    cv.value = 1.day.from_now.to_date
    cv.save!

    @ps.reload
    @ps.create_forecasts
    ms = @ps.milestone_forecast_set
    assert_equal "Missed", ms.state
  end

end
