require 'test_helper'

class MasterSetupsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

  test "should get eedit" do
    get :eedit
    assert_response :success
  end

  test "should get update" do
    get :update
    assert_response :success
  end

end
