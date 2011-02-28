require 'test_helper'

class DebugRecordsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

  test "should get show" do
    get :show
    assert_response :success
  end

  test "should get destroy_all" do
    get :destroy_all
    assert_response :success
  end

end
