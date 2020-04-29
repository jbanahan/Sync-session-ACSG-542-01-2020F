describe Api::V1::AddressesController do
  let (:user) { Factory(:admin_user) }
  let :enable_admin do
    allow_api_access user
  end
  describe '#index' do
    it 'should get addresses that user can view' do
      c = Factory(:company)
      Factory(:address, system_code:'ABCD', company:c)
      Factory(:address) # don't find this one

      allow_api_access Factory(:user, company:c)

      get :index
      expect(response).to be_success
      h = JSON.parse(response.body)
      expect(h['results'].size).to eq(1)
      expect(h['results'][0]['add_syscode']).to eq 'ABCD'
    end
    it 'should apply filters' do
      c = Factory(:company)
      Factory(:address, system_code:'ABCD', company:c)
      Factory(:address, system_code:'DEFG', company:c)
      Factory(:address) # don't find this one

      allow_api_access Factory(:user, company:c)

      get :index, sid1:'add_syscode', sop1: 'eq', sv1:'ABCD'
      expect(response).to be_success
      h = JSON.parse(response.body)
      expect(h['results'].size).to eq(1)
      expect(h['results'][0]['add_syscode']).to eq 'ABCD'
    end
  end

  describe '#create' do
    it 'should make new address' do
      enable_admin
      us = Factory(:country, iso_code:'US')
      c = Factory(:company)
      h = {'address'=>{
        'add_name'=>'My Name',
        'add_syscode'=>'sysc',
        'add_line_1'=>'1 any street',
        'add_city'=>'new york',
        'add_cntry_iso'=>'US',
        'add_comp_db_id'=>c.id.to_s
      }}
      expect {post :create, h}.to change(Address, :count).from(0).to(1)
      expect(response).to be_success
      a = c.addresses.first
      expect(a.name).to eq 'My Name'
      expect(a.system_code).to eq 'sysc'
      expect(a.line_1).to eq '1 any street'
      expect(a.city).to eq 'new york'
      expect(a.country).to eq us

    end
    it 'should not make address without company' do
      enable_admin
      Factory(:country, iso_code:'US')
      Factory(:company)
      h = {'address'=>{
        'add_name'=>'My Name',
        'add_syscode'=>'sysc',
        'add_line_1'=>'1 any street',
        'add_city'=>'new york',
        'add_cntry_iso'=>'US'
      }}
      expect {post :create, h}.to_not change(Address, :count)
      expect(response.body).to match(/add_comp_db_id/)
      expect(response).to_not be_success
      expect(Address.count).to eq 0
    end
    it "allows making new addresses tied to the user's company" do
      enable_admin
      user.company = Factory(:company)
      user.save!
      allow_any_instance_of(Address).to receive(:can_view?).with(user).and_return true

      us = Factory(:country, iso_code:'US')
      c = Factory(:company)
      h = {'address'=>{
        'add_name'=>'My Name',
        'add_syscode'=>'sysc',
        'add_line_1'=>'1 any street',
        'add_city'=>'new york',
        'add_cntry_iso'=>'US',
        'add_comp_db_id'=>"current_user"
      }}
      post :create, h
      expect(response).to be_success
      a = Address.where(system_code: "sysc").first
      expect(a.company_id).to eq user.company_id
    end
  end
  describe '#update' do
    it 'should not allow company to be changed' do
      enable_admin
      c = Factory(:company)
      c2 = Factory(:company)
      a = Factory(:address, company:c)
      h = {'id'=>a.id.to_s,
        'address'=>{
          'id'=>a.id.to_s,
          'add_comp_db_id'=>c2.id.to_s
      }}
      expect {put :update, h}.to_not change(a, :updated_at)
      expect(response.body).to match(/change the company for an address/)
      expect(response).to_not be_success
    end
    it 'should not allow hash key to be changed' do
      enable_admin
      c = Factory(:company)
      a = Factory(:address, company:c)
      h = {'id'=>a.id.to_s,
        'address'=>{
          'id'=>a.id.to_s,
          'add_line_1'=>'other street'
      }}
      expect {put :update, h}.to_not change(a, :updated_at)
      expect(response.body).to match(/change the address, only its setup flags/)
      expect(response).to_not be_success
    end
    it 'should allow shipping flag to be changed' do
      enable_admin
      c = Factory(:company)
      a = Factory(:address, company:c, shipping:false)
      h = {'id'=>a.id.to_s,
        'address'=>{
          'id'=>a.id.to_s,
          'add_shipping'=>true
      }}
      expect {put :update, h}.to_not change(a, :updated_at)
      expect(response).to be_success
      a.reload
      expect(a.shipping?).to be_truthy
    end
    it "disallows updating addresses unless user can edit" do
      expect_any_instance_of(Address).to receive(:can_edit?).with(user).and_return false

      enable_admin
      c = Factory(:company)
      a = Factory(:address, company:c, shipping:false)
      h = {'id'=>a.id.to_s,
        'address'=>{
          'id'=>a.id.to_s,
          'add_shipping'=>true
      }}
      put :update, h
      expect(response).not_to be_success
    end
  end
  describe '#destroy' do
    it 'should not allow in use address to be destroyed' do
      enable_admin
      a = Factory(:address)
      Factory(:order, ship_from:a)
      expect {delete :destroy, id: a.id}.to_not change(Address, :count)
      expect(response).to_not be_success
      expect(response.body).to match(/still in use/)
    end
    it 'should allow not in use address to be destroyed' do
      enable_admin
      a = Factory(:address)
      expect {delete :destroy, id: a.id}.to change(Address, :count).from(1).to(0)
      expect(response).to be_success
    end
  end

end
