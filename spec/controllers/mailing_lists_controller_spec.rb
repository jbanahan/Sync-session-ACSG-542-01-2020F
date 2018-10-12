require 'spec_helper'

describe MailingListsController do
  let (:company) { Factory(:company) }
  let (:user) { Factory(:user, company: company) }

  before :each do
    sign_in_as user
  end

  describe "update" do
    before :each do
      @mailing_list = Factory(:mailing_list, name: 'Mailing List', system_code: 'SYSTEM', user: user, company: user.company, email_addresses: 'test@domain.com')
    end

    it "should update a mailing list given all valid inputs" do
      allow_any_instance_of(User).to receive(:admin?).and_return(true)

      ml = {'name'=>'Mailing List', 'email_addresses'=>'test@domain.com, test2@domain.com'}

      post :update, {company_id: user.company_id, id: @mailing_list.id, mailing_list: ml}
      expect(response).to be_redirect

      @mailing_list.reload
      expect(@mailing_list.split_emails).to include('test2@domain.com')
    end
  end

  describe "create" do
    it "should create a mailing list given all valid inputs" do
      allow_any_instance_of(User).to receive(:admin?).and_return(true)

      ml = {'user_id'=>user.id, 'company_id'=>user.company.id ,'system_code'=>'system', 'name'=>'mailing list', 'email_addresses'=>'test@domain.com'}
      expect {
        post :create, {'company_id'=>user.company_id, 'mailing_list'=>ml}
      }.to change(MailingList, :count).by(1)
      expect(response).to be_redirect
    end

    it 'should not create if there is an invalid email' do
      allow_any_instance_of(User).to receive(:admin?).and_return(true)

      ml = {'user_id'=>user.id, 'company_id'=>user.company.id ,'system_code'=>'system', 'name'=>'mailing list', 'email_addresses'=>'test@domain'}

      expect {
        post :create, {'company_id'=>user.company_id, 'mailing_list'=>ml}
      }.to change(MailingList, :count).by(0)

      expect(flash[:errors].size).to eq 1
      expect(flash[:errors]).to include(/invalid/)
    end
  end
end
