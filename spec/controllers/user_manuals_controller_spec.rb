describe UserManualsController do

  def check_admin_secured
    sign_in_as Factory(:user)
    yield
    expect(response).to be_redirect
    expect(flash[:errors].size).to eq(1)
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
      expect(assigns(:user_manuals).to_a).to eq [um1, um2]
    end
  end

  describe '#update' do
    let (:user_manual) { Factory(:user_manual, name:'X') }

    it "should admin secure" do
      check_admin_secured do
        put :update, id: user_manual.id, user_manual: {name: 'Y'}
        user_manual.reload
        expect(user_manual.name).to eq 'X'
      end
    end

    it "should update manual attributes" do
      sign_in_as Factory(:admin_user)
      put :update, id: user_manual.id, user_manual: {name: 'Y'}
      expect(response).to redirect_to user_manuals_path
      user_manual.reload
      expect(user_manual.name).to eq 'Y'
    end
  end

  describe '#create' do
    let! (:file) { fixture_file_upload('/files/test.txt', 'text/plain') }

    it "should admin secure" do
      check_admin_secured do
        expect { post :create, user_manual: {name:'X'}, user_manual_file: file}.to_not change(UserManual, :count)
      end
    end

    it "should create with attachment" do
      sign_in_as Factory(:admin_user)
      expect { post :create, user_manual: {name:'X'}, user_manual_file: file}.to change(UserManual, :count).from(0).to(1)
      expect(response).to redirect_to user_manuals_path
      um = UserManual.first
      expect(um.name).to eq 'X'
      expect(um.attachment.attached_file_name).to eq 'test.txt'
    end
  end

  describe '#destroy' do
    let! (:user_manual) { Factory(:user_manual) }

    it "should admin secure" do
      check_admin_secured do
        expect { delete :destroy, id: user_manual.id}.to_not change(UserManual, :count)
      end
    end

    it "should delete" do
      sign_in_as Factory(:admin_user)
      expect { delete :destroy, id: user_manual.id }.to change(UserManual, :count).from(1).to(0)
      expect(response).to redirect_to user_manuals_path
    end
  end

  describe '#edit' do
    let (:user_manual) { Factory(:user_manual) }

    it "should admin secure" do
      check_admin_secured do
        get :edit, id: user_manual.id
      end
    end

    it "should load manual" do
      sign_in_as Factory(:admin_user)
      get :edit, id: user_manual.id
      expect(response).to be_success
      expect(assigns(:user_manual)).to eq user_manual
    end
  end

  describe '#for_referer' do
    it "should return page" do
      u = Factory(:user)
      sign_in_as u
      # setup dummy data
      m1 = double('manual1')
      m2 = double('manual2')
      [m1, m2].each_with_index do |m, i|
        allow(m).to receive(:name).and_return "manual#{i+1}"
        allow(m).to receive(:id).and_return(i+1)
      end

      request.env['HTTP_REFERER'] = 'http://example.com/my_page'

      expect(UserManual).to receive(:for_user_and_page).
        with(u, 'http://example.com/my_page').
        and_return [m2, m1] # returning in reverse order to confirm that sorting works

      get :for_referer

      expect(response).to be_success
      expect(assigns(:manuals)).to eq [m1, m2]
    end
  end

  describe '#download' do
    let! (:master_setup) { stub_master_setup }
    let (:user_manual) do
      m = Factory(:user_manual)
      allow_any_instance_of(UserManual).to receive(:attachment).and_return attachment
      m
    end

    let (:attachment) do
      a = instance_double(Attachment)
      allow(a).to receive(:attached_file_name).and_return "file.txt"
      allow(a).to receive(:attached_content_type).and_return "text/plain"
      allow(a).to receive(:secure_url).and_return "http://secure.url"
      a
    end

    context "with user that can view manual" do
      before :each do
        allow_any_instance_of(UserManual).to receive(:can_view?).and_return true
      end

      it "should allow user who can view" do
        sign_in_as Factory(:user)
        get :download, id: user_manual.id
        expect(response).to redirect_to "http://secure.url"
      end
    end

    # before :each do
    #   @um = Factory(:user_manual)
    #   @secure_url = 'abc'
    #   @att = double(:attachment, secure_url: @secure_url)
    #   allow_any_instance_of(UserManual).to receive(:attachment).and_return(@att)
    # end
    it "should allow admins" do
      sign_in_as Factory(:admin_user)
      get :download, id: user_manual.id
      expect(response).to redirect_to "http://secure.url"
    end

    it "should not allow if user cannot view" do
      allow_any_instance_of(UserManual).to receive(:can_view?).and_return false
      check_admin_secured do
        get :download, id: user_manual.id
      end
    end

    it "should allow if user has portal_redirect" do
      sign_in_as Factory(:user)
      allow_any_instance_of(User).to receive(:portal_redirect_path).and_return '/abc'

      allow(master_setup).to receive(:custom_feature?).with("Attachment Mask").and_return true

      tf = instance_double("Tempfile")
      expect(tf).to receive(:read).and_return "123"
      allow(attachment).to receive(:download_to_tempfile).and_yield tf

      get :download, id: user_manual.id
      expect(response).to be_success
      expect(response.body).to eq "123"
    end

    it "uses alternate download approach" do
      sign_in_as Factory(:user)
      allow(master_setup).to receive(:custom_feature?).with("Attachment Mask").and_return true

      tf = instance_double("Tempfile")
      expect(tf).to receive(:read).and_return "123"
      allow(attachment).to receive(:download_to_tempfile).and_yield tf

      get :download, id: user_manual.id
      expect(response).to be_success
      expect(response.body).to eq "123"
    end
  end
end
