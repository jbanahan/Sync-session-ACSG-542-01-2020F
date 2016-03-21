require 'spec_helper'

describe UserManualsController do
  def check_admin_secured
    sign_in_as Factory(:user)
    yield
    expect(response).to be_redirect
    expect(flash[:errors]).to have(1).message
  end
  describe '#index' do
    it "should admin secure" do
      check_admin_secured do
        get :index
      end
    end
    it "should list all manuals" do
      um1 = Factory(:user_manual, name:'X')
      um2 = Factory(:user_manual, name:'A')
      sign_in_as Factory(:admin_user)
      get :index
      expect(response).to be_success
      expect(assigns(:user_manuals).to_a).to eq [um2,um1]
    end
  end
  describe '#update' do
    before :each do
      @um = Factory(:user_manual,name:'X')
    end
    it "should admin secure" do
      check_admin_secured do
        put :update, id: @um.id, user_manual: {name: 'Y'}
        @um.reload
        expect(@um.name).to eq 'X'
      end
    end
    it "should update manual attributes" do
      sign_in_as Factory(:admin_user)
      put :update, id: @um.id, user_manual: {name: 'Y'}
      expect(response).to redirect_to user_manuals_path
      @um.reload
      expect(@um.name).to eq 'Y'
    end
  end
  describe '#create' do
    before :each do
      stub_paperclip
      @file = fixture_file_upload('/files/test.txt', 'text/plain')
    end
    it "should admin secure" do
      check_admin_secured do
        expect { post :create, user_manual: {name:'X'}, user_manual_file: @file}.to_not change(UserManual,:count)
      end
    end
    it "should create with attachment" do
      sign_in_as Factory(:admin_user)
      expect { post :create, user_manual: {name:'X'}, user_manual_file: @file}.to change(UserManual,:count).from(0).to(1)
      expect(response).to redirect_to user_manuals_path
      um = UserManual.first
      expect(um.name).to eq 'X'
      expect(um.attachment.attached_file_name).to eq 'test.txt'
    end
    it "should fail without attachment" do
      sign_in_as Factory(:admin_user)
      expect { post :create, user_manual: {name:'X'}}.to_not change(UserManual,:count)
      expect(flash[:errors].first).to eq "You must attach a file."
    end
  end
  describe '#destroy' do
    before :each do
      @um = Factory(:user_manual)
    end
    it "should admin secure" do
      check_admin_secured do
        expect { delete :destroy, id: @um.id}.to_not change(UserManual,:count)
      end
    end
    it "should delete" do
      sign_in_as Factory(:admin_user)
      expect { delete :destroy, id: @um.id }.to change(UserManual,:count).from(1).to(0)
      expect(response).to redirect_to user_manuals_path
    end
  end
  describe '#edit' do
    before :each do
      @um = Factory(:user_manual)
    end
    it "should admin secure" do
      check_admin_secured do
        get :edit, id: @um.id
      end
    end
    it "should load manual" do
      sign_in_as Factory(:admin_user)
      get :edit, id: @um.id
      expect(response).to be_success
      expect(assigns(:user_manual)).to eq @um
    end
  end
  describe '#download' do
    before :each do
      @um = Factory(:user_manual)
      @secure_url = 'abc'
      @att = double(:attachment, secure_url: @secure_url)
      UserManual.any_instance.stub(:attachment).and_return(@att)
    end
    it "should allow admins" do
      sign_in_as Factory(:admin_user)
      get :download, id: @um.id
      expect(response).to redirect_to @secure_url
    end
    it "should allow user who can view" do
      sign_in_as Factory(:user)
      UserManual.any_instance.stub(:can_view?).and_return true
      get :download, id: @um.id
      expect(response).to redirect_to @secure_url
    end
    it "should not allow if user cannot view" do
      UserManual.any_instance.stub(:can_view?).and_return false
      check_admin_secured do
        get :download, id: @um.id
      end
    end
    it "should allow if user has portal_redirect" do
      sign_in_as Factory(:user)
      User.any_instance.stub(:portal_redirect_path).and_return '/abc'

      ms = double("MasterSetup")
      ms.stub(:custom_feature?).with("Attachment Mask").and_return true
      MasterSetup.stub(:get).and_return ms

      @att.stub(:attached_file_name).and_return "file.txt"
      @att.stub(:attached_content_type).and_return "text/plain"
      tf = double("Tempfile")
      tf.should_receive(:read).and_return "123"
      @att.stub(:download_to_tempfile).and_yield tf

      get :download, id: @um.id
      expect(response).to be_success
      expect(response.body).to eq "123"
    end

    it "uses alternate download approach" do
      sign_in_as Factory(:user)
      ms = double("MasterSetup")
      ms.stub(:custom_feature?).with("Attachment Mask").and_return true
      MasterSetup.stub(:get).and_return ms

      @att.stub(:attached_file_name).and_return "file.txt"
      @att.stub(:attached_content_type).and_return "text/plain"
      tf = double("Tempfile")
      tf.should_receive(:read).and_return "123"
      @att.stub(:download_to_tempfile).and_yield tf

      get :download, id: @um.id
      expect(response).to be_success
      expect(response.body).to eq "123"
    end
  end
end
