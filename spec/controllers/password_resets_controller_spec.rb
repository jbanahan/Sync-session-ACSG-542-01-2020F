describe PasswordResetsController do
  let (:user) { Factory(:user) }
  before :each do
    sign_in_as user
  end
  
  describe "create" do
    it "sends password reset message" do
      u = Factory(:user, disallow_password:false, email:"this_is_a_test@email.com")

      expect_any_instance_of(User).to receive(:delay).and_return(u)
      expect(u).to receive(:deliver_password_reset_instructions!)

      post :create, { "email"=>"this_is_a_test@email.com" }
      expect(flash[:notices].first).to eq "If a valid account is found for this_is_a_test@email.com, instructions for resetting the password will be emailed to that address."
      expect(response).to redirect_to new_user_session_path
    end

    it "notifies if user has password disallowed" do
      u = Factory(:user, disallow_password:true, email:"this_is_a_test2@email.com")

      expect_any_instance_of(User).to_not receive(:delay)

      post :create, { "email"=>"this_is_a_test2@email.com" }
      expect(flash[:notices].first).to eq "If a valid account is found for this_is_a_test2@email.com, instructions for resetting the password will be emailed to that address."
      expect(response).to redirect_to new_user_session_path
    end

    it "handles user not found" do
      expect_any_instance_of(User).to_not receive(:delay)

      post :create, { "email"=>"this_is_a_test3@email.com" }
      expect(flash[:notices].first).to eq "If a valid account is found for this_is_a_test3@email.com, instructions for resetting the password will be emailed to that address."
      expect(response).to redirect_to new_user_session_path
    end
  end

  describe "update" do
    it "updates password" do
      u = Factory(:user, password_reset:true, email:"this_is_a_test@email.com", confirmation_token:"555666")

      expect_any_instance_of(User).to receive(:update_user_password).with('pw12345', 'pw12345').and_return true
      expect_any_instance_of(User).to receive(:on_successful_login).with(request)

      put :update, { "user"=>{'password'=>'pw12345','current_password'=>'old_pass','password_confirmation'=>'pw12345' }, "id"=>"555666" }
      expect(flash[:notices].first).to eq "Password successfully updated"
      expect(response).to redirect_to root_url

      u.reload
      expect(u.password_reset).to eq false
    end

    it "errors when user can't be found by confirmation token" do
      u = Factory(:user, password_reset:true, email:"this_is_a_test@email.com", confirmation_token:"555666")

      expect(subject).to receive(:sign_out)
      expect_any_instance_of(User).to_not receive(:update_user_password)

      put :update, { "user"=>{'password'=>'pw12345','current_password'=>'old_pass','password_confirmation'=>'pw12345' }, "id"=>"555667" }
      expect(flash[:notices]).to be_nil
      expect(flash[:errors].first).to eq "We're sorry, but we could not locate your account.  Please retry resetting your password from the login page."
      expect(response).to redirect_to new_user_session_path

      u.reload
      expect(u.password_reset).to eq true
    end

    it "handles unsuccessful password update" do
      u = Factory(:user, password_reset:true, email:"this_is_a_test@email.com", confirmation_token:"555666")

      expect_any_instance_of(User).to receive(:update_user_password).with('pw12345', 'pw12345').and_return false
      expect_any_instance_of(User).to_not receive(:on_successful_login)

      expect(subject).to receive(:errors_to_flash).with(be_a(User), now: true)

      put :update, { "user"=>{'password'=>'pw12345','current_password'=>'old_pass','password_confirmation'=>'pw12345' }, "id"=>"555666" }
      expect(flash[:notices]).to be_nil
      expect(flash[:errors]).to be_nil
      expect(response).to render_template :edit

      u.reload
      expect(u.password_reset).to eq true
    end

    it "handles expired password (with no current password)" do
      u = Factory(:user, password_reset:true, password_expired:true, email:"this_is_a_test@email.com", confirmation_token:"555666")

      expect_any_instance_of(User).to_not receive(:update_user_password)
      expect_any_instance_of(User).to_not receive(:on_successful_login)

      put :update, { "user"=>{'password'=>'pw12345','current_password'=>'','password_confirmation'=>'pw12345' }, "id"=>"555666" }
      expect(flash[:notices]).to be_nil
      expect(flash[:errors].first).to eq "Current password is required to change password"
      expect(response).to render_template :edit

      u.reload
      expect(u.password_reset).to eq true
    end

    it "handles expired password (with invalid current password)" do
      u = Factory(:user, password_reset:true, password_expired:true, email:"this_is_a_test@email.com", confirmation_token:"555666", password_salt:"ZBX678")

      expect_any_instance_of(User).to_not receive(:update_user_password)
      expect_any_instance_of(User).to_not receive(:on_successful_login)

      expect_any_instance_of(User).to receive(:authenticated?).with("ZBX678", "invalid").and_return false

      put :update, { "user"=>{'password'=>'pw12345','current_password'=>'invalid','password_confirmation'=>'pw12345' }, "id"=>"555666" }
      expect(flash[:notices]).to be_nil
      expect(flash[:errors].first).to eq "Current password is invalid"
      expect(response).to render_template :edit

      u.reload
      expect(u.password_reset).to eq true
    end

    it "allows forgotten password to reset password" do
      u = Factory(:user, forgot_password:true, password_reset:true, email:"this_is_a_test@email.com", confirmation_token:"555666")

      expect_any_instance_of(User).to receive(:update_user_password).with('pw12345', 'pw12345').and_return true
      expect_any_instance_of(User).to receive(:on_successful_login).with(request)

      put :update, { "user"=>{'password'=>'pw12345','current_password'=>'','password_confirmation'=>'pw12345' }, "id"=>"555666" }
      expect(flash[:notices].first).to eq "Password successfully updated"
      expect(response).to redirect_to root_url

      u.reload
      expect(u.password_reset).to eq false
    end

    # Password reset is updated, but the user is not actually signed in.  ("Success" value for sign in is false.)
    it "allows password locked user to reset password" do
      u = Factory(:user, password_locked:true, password_reset:true, email:"this_is_a_test@email.com", confirmation_token:"555666")

      expect_any_instance_of(User).to receive(:update_user_password).with('pw12345', 'pw12345').and_return true
      expect_any_instance_of(User).to_not receive(:on_successful_login)

      put :update, { "user"=>{'password'=>'pw12345','current_password'=>'','password_confirmation'=>'pw12345' }, "id"=>"555666" }
      expect(flash[:notices]).to be_nil
      expect(flash[:errors]).to be_nil
      expect(response).to render_template :edit

      u.reload
      expect(u.password_reset).to eq false
    end
  end

end
