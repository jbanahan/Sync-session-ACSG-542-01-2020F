require 'test_helper'

class ImportConfigsControllerTest < ActionController::TestCase
  setup do
    @import_config = import_configs(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:import_configs)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create import_config" do
    assert_difference('ImportConfig.count') do
      post :create, :import_config => @import_config.attributes
    end

    assert_redirected_to import_config_path(assigns(:import_config))
  end

  test "should show import_config" do
    get :show, :id => @import_config.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @import_config.to_param
    assert_response :success
  end

  test "should update import_config" do
    put :update, :id => @import_config.to_param, :import_config => @import_config.attributes
    assert_redirected_to import_config_path(assigns(:import_config))
  end

  test "should destroy import_config" do
    assert_difference('ImportConfig.count', -1) do
      delete :destroy, :id => @import_config.to_param
    end

    assert_redirected_to import_configs_path
  end
end
