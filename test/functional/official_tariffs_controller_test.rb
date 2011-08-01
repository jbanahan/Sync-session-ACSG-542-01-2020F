require 'test_helper'
require 'authlogic/test_case'

class OfficialTariffsControllerTest < ActionController::TestCase
  setup :activate_authlogic

  test "find schedule b" do 
    UserSession.create(users(:masteruser))
    s = OfficialScheduleBCode.create!(:hts_code=>"1234567890",:short_description=>"my short d")

    get :find_schedule_b, {:format=>"json",:hts=>s.hts_code}
    assert_response :success

    r = ActiveSupport::JSON.decode @response.body
    assert_equal s.hts_code, r["official_schedule_b_code"]["hts_code"]
    assert_equal s.short_description, r["official_schedule_b_code"]["short_description"]
    
  end

  test "schedule b matches" do
    UserSession.create(users(:masteruser))

    ot = OfficialTariff.create!(:country_id=>countries(:us).id,:hts_code=>"1234560000",:full_description=>"FD")
    sched_b_to_find = ["1234569999","1234568888"]
    sched_b_to_find.each do |h|
      OfficialScheduleBCode.create!(:hts_code=>h,:short_description=>"my short d")
    end

    get :schedule_b_matches, {:format=>"json",:hts=>ot.hts_code}
    assert_response :success

    response_array = ActiveSupport::JSON.decode @response.body

    assert_equal 2, response_array.size
    response_array.each do |r_outer|
      r = r_outer["official_schedule_b_code"]
      assert sched_b_to_find.include?(r["hts_code"])
      assert_equal "my short d", r["short_description"]
    end

  end

end
