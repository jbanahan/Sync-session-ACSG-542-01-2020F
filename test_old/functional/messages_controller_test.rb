require 'test_helper'

class MessagesControllerTest < ActionController::TestCase


  test "index redirects without login and stores location" do
    get :index
    assert_redirected_to login_path
    assert_equal '/messages', session[:return_to]
  end
end
