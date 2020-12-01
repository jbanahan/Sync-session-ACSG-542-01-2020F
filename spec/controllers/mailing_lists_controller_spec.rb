describe MailingListsController do
  let (:company) { FactoryBot(:company) }
  let (:user) { FactoryBot(:user, company: company) }

  before do
    sign_in_as user
  end

  describe "update" do
    let(:mailing_list) { FactoryBot(:mailing_list, name: 'Mailing List', system_code: 'SYSTEM', user: user, company: user.company, email_addresses: 'test@domain.com') }

    it "updates a mailing list given all valid inputs" do
      allow_any_instance_of(User).to receive(:admin?).and_return(true)

      ml = {'name' => 'Mailing List', 'email_addresses' => 'test@domain.com, test2@domain.com'}

      post :update, {company_id: user.company_id, id: mailing_list.id, mailing_list: ml}
      expect(response).to be_redirect

      mailing_list.reload
      expect(mailing_list.split_emails).to include('test2@domain.com')
    end
  end

  describe "create" do
    before do
      allow_any_instance_of(User).to receive(:admin?).and_return(true)
    end

    let (:mailing_list) do
      {'user_id' => user.id, 'company_id' => user.company.id, 'system_code' => 'system', 'name' => 'mailing list', 'email_addresses' => 'test@domain.com'}
    end

    it "creates a mailing list given all valid inputs" do
      expect do
        post :create, {'company_id' => user.company_id, 'mailing_list' => mailing_list}
      end.to change(MailingList, :count).by(1)
      expect(response).to be_redirect
    end

    it 'does not create if there is an invalid email' do
      mailing_list["email_addresses"] = 'test@domain'
      expect do
        post :create, {'company_id' => user.company_id, 'mailing_list' => mailing_list }
      end.to change(MailingList, :count).by(0)

      expect(flash[:errors].size).to eq 1
      expect(flash[:errors]).to include(/invalid/)
    end

    it "autogenerates system code if it's blank" do
      mailing_list["system_code"] = ""
      expect do
        post :create, {'company_id' => user.company_id, 'mailing_list' => mailing_list}
      end.to change(MailingList, :count).by(1)

      l = MailingList.first
      expect(l.system_code).to eq "mailing_list_#{company.id}"
    end
  end
end
