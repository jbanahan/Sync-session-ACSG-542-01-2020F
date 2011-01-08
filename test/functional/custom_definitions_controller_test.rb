require 'test_helper'

class CustomDefinitionsControllerTest < ActionController::TestCase
  setup do
    @custom_definition = custom_definitions(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:custom_definitions)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create custom_definition" do
    assert_difference('CustomDefinition.count') do
      post :create, :custom_definition => @custom_definition.attributes
    end

    assert_redirected_to custom_definition_path(assigns(:custom_definition))
  end

  test "should show custom_definition" do
    get :show, :id => @custom_definition.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @custom_definition.to_param
    assert_response :success
  end

  test "should update custom_definition" do
    put :update, :id => @custom_definition.to_param, :custom_definition => @custom_definition.attributes
    assert_redirected_to custom_definition_path(assigns(:custom_definition))
  end

  test "should destroy custom_definition" do
    assert_difference('CustomDefinition.count', -1) do
      delete :destroy, :id => @custom_definition.to_param
    end

    assert_redirected_to custom_definitions_path
  end
end
