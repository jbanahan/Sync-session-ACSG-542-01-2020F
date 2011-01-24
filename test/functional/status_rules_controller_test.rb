require 'test_helper'

class StatusRulesControllerTest < ActionController::TestCase
  setup do
    @status_rule = status_rules(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:status_rules)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create status_rule" do
    assert_difference('StatusRule.count') do
      post :create, :status_rule => @status_rule.attributes
    end

    assert_redirected_to status_rule_path(assigns(:status_rule))
  end

  test "should show status_rule" do
    get :show, :id => @status_rule.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @status_rule.to_param
    assert_response :success
  end

  test "should update status_rule" do
    put :update, :id => @status_rule.to_param, :status_rule => @status_rule.attributes
    assert_redirected_to status_rule_path(assigns(:status_rule))
  end

  test "should destroy status_rule" do
    assert_difference('StatusRule.count', -1) do
      delete :destroy, :id => @status_rule.to_param
    end

    assert_redirected_to status_rules_path
  end
end
