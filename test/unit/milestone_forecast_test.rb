require 'test_helper'
require 'ruby-debug' 
class MilestoneForecastTest < ActiveSupport::TestCase
  
  def setup
    Debugger.start
    generic_forecast_setup
  end

  test "label" do 
    @ps.create_forecasts
    @ps.reload
    assert_equal @od.label, @ps.milestone_forecast_set.milestone_forecasts.first.label  
  end

  test "trouble downstream from overdue" do
    md2 = @mp.milestone_definitions.create!(:model_field_uid=>:ord_ord_date,:previous_milestone_definition_id=>@md.id,:days_after_previous=>1)
    cd = CustomDefinition.create!(:label=>"cd",:module_type=>"Order", :data_type=>:date)
    md3 = @mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{cd.id}",:previous_milestone_definition_id=>md2.id,:days_after_previous=>10)

    #md2 will be overdue, md3 will be in trouble
    @ps.create_forecasts
    @ps.reload

    forecasts = @ps.milestone_forecast_set
    mf2 = forecasts.find_forecast_by_definition md2
    assert_equal "Overdue", mf2.state
    mf3 = forecasts.find_forecast_by_definition md3
    assert_equal "Trouble", mf3.state

  end

  test "previous milestone forecast" do
    @md2 = @mp.milestone_definitions.create!(:model_field_uid=>:ord_ord_date,:previous_milestone_definition_id=>@md.id,:days_after_previous=>5)
    
    @ps.create_forecasts
    @ps.reload

    mf1 = nil
    forecasts = @ps.milestone_forecast_set.milestone_forecasts
  end

  test "actual" do

    @ps.create_forecasts

    @ps.reload
    mf = @ps.milestone_forecast_set.milestone_forecasts.first
    assert_equal @cv.value, mf.actual
  end

  test "overdue?" do
    mf = MilestoneForecast.new
    mf.stubs(:actual).returns(nil)
    mf.planned = 1.day.ago.to_date
    assert mf.overdue?
    mf.planned = 0.days.ago.to_date
    assert !mf.overdue?
    mf.planned = 1.day.from_now.to_date
    assert !mf.overdue?
  end

  test "set state except trouble" do
    mf = MilestoneForecast.new(:milestone_definition=>@md)
    mf.expects(:actual).times(5).returns(nil,nil,nil,2.days.ago.to_date,2.days.ago.to_date) #pending calls .actual twice

    mf.planned = 1.day.from_now.to_date
    
    #actual = nil, planned in the future, forecast < planned
    mf.set_state
    assert_equal "Pending", mf.state 

    #actual = nil, planned in the past
    mf.planned = 1.day.ago.to_date
    mf.set_state
    assert_equal "Overdue", mf.state

    #actual prior to planned
    mf.set_state
    assert_equal "Achieved", mf.state

    #actual after planned
    mf.planned = 3.days.ago.to_date
    mf.set_state
    assert_equal "Missed", mf.state

    mf.planned = nil
    mf.set_state
    assert_equal "Unplanned", mf.state
  end

  test "auto set state" do
    @ps.create_forecasts
    mf = @ps.milestone_forecast_set.milestone_forecasts.first
    assert_equal "Achieved", mf.state
  end
end
