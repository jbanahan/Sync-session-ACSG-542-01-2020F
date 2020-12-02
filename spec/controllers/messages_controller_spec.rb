describe MessagesController do
  let(:base_user) { create(:user) }
  let(:sys_admin_user) { create(:user, sys_admin: true) }

  describe 'create' do
    it 'works for sys_admins' do
      sign_in_as sys_admin_user
      put :create, {message: {subject: 'test subject', body: 'test body', user_id: base_user.id.to_s}}
      expect(response).to redirect_to('/messages')
      expect(flash[:notices]).to include "Your message has been sent."
      expect(flash[:errors]).to be_blank
      base_user.reload
      expect(base_user.messages.size).to eq(1)
      msg = base_user.messages.first
      expect(msg.subject).to eq('test subject')
      expect(msg.body).to eq('test body')
    end

    it 'sanitizes html' do
      sign_in_as sys_admin_user
      put :create, {message: {subject: 'test <em>subject</em>', body: '<a href=\'http://www.google.com\'>test body</a>', user_id: base_user.id.to_s}}
      msg = base_user.messages.first
      expect(msg.subject).to eq('test subject')
      expect(msg.body).to eq('test body')
    end

    it 'does not allow basic users' do
      sign_in_as base_user
      put :create, {subject: 'test subject', body: 'test body', user_id: base_user.id.to_s}
      expect(response).to be_redirect
      expect(flash[:notices]).to be_blank
      expect(flash[:errors]).not_to be_blank
    end

    it 'does not allow normal admins' do
      u = create(:user)
      u.admin = true
      u.save!
      sign_in_as u
      put :create, {subject: 'test subject', body: 'test body', user_id: base_user.id.to_s}
      expect(response).to be_redirect
      expect(flash[:notices]).to be_blank
      expect(flash[:errors]).not_to be_blank
    end
  end

  describe 'new' do
    it 'allows sys_admins' do
      sign_in_as sys_admin_user
      get :new
      expect(response).to be_success
    end

    it 'does not allow basic users' do
      sign_in_as base_user
      get :new
      expect(response).to be_redirect
    end

    it 'does not allow normal admins' do
      u = create(:user)
      u.admin = true
      u.save!
      sign_in_as u
      get :new
      expect(response).to be_redirect
    end
  end

  context "send messages" do
    let(:company) do
      Company.destroy_all
      company = create(:company)
      company
    end

    describe "new_bulk" do
      it "only allows use by admins" do
        u = create(:user, company: company)
        sign_in_as u

        get :new_bulk
        expect(flash[:errors]).to include "Only administrators can do this."
        expect(response).to be_redirect
      end

      it "displays the selection screen" do
        u = create(:admin_user, company: company)
        sign_in_as u

        get :new_bulk
        expect(assigns(:companies)).to eq [company]
        expect(response).to be_success
      end
    end

    describe "send_to_users" do
      let(:receiver1) { create(:user, company: company) }
      let(:receiver2) { create(:user, company: company) }

      before do
        User.destroy_all
      end

      it "only allows use by admins" do
        u = create(:user)
        sign_in_as u
        post :send_to_users, {receivers: [receiver1.id, receiver2.id], message_subject: "Test Message", message_body: "This is a test."}

        expect(receiver1.messages).to be_empty
        expect(receiver2.messages).to be_empty
        expect(flash[:errors]).to include "Only administrators can do this."
        expect(response).to be_redirect
      end

      it 'sanitizes subject and formats body as markdown' do
        u = create(:admin_user)
        sign_in_as u

        d = instance_double("delayed_job")
        expect(Message).to receive(:delay).and_return d
        expect(d).to receive(:send_to_users).with([receiver1.id.to_s, receiver2.id.to_s], "Test Message", "<p>This <b>is</b> a test.</p>")

        post :send_to_users, {receivers: [receiver1.id, receiver2.id], message_subject: "Test <em>Message</em>", message_body: "This **is** a test."}
      end

      it "creates notifications for specified users" do
        u = create(:admin_user)
        sign_in_as u

        d = instance_double("delayed_job")
        expect(Message).to receive(:delay).and_return d
        expect(d).to receive(:send_to_users).with([receiver1.id.to_s, receiver2.id.to_s], instance_of(String), instance_of(String))

        post :send_to_users, {receivers: [receiver1.id, receiver2.id], message_subject: "Test Message", message_body: "This is a test."}
        expect(flash[:notices]).to include "Message sent."
        expect(response).to be_redirect
      end
    end
  end

end
