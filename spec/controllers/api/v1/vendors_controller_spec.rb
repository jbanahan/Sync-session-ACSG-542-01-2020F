describe Api::V1::VendorsController do
  context 'base methods' do
    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:vendor_management_enabled?).and_return true
      ms
    }
    before :each do
      @u = FactoryBot(:master_user, vendor_view:true, vendor_edit:true)
      allow_api_access @u
    end
    describe '#index' do
      it 'should return vendors' do
        FactoryBot(:company, vendor:true, name:'V1')
        FactoryBot(:company, vendor:true, name:'V2')
        get :index
        h = JSON.parse(response.body)['results']
        expect(h.collect {|v| v['cmp_name']}).to eq ['V1', 'V2']
      end
    end
    describe '#create' do
      it 'should create with vendor flag set to true' do
        h = {'cmp_name'=>'compname'}
        expect {post :create, company:h}.to change(Company, :count).by(1)
        expect(response).to be_success
        c = Company.last
        expect(c.name).to eq 'compname'
        expect(c).to be_vendor
      end
    end
    describe '#update' do
      it 'should update vendor' do
        v = FactoryBot(:company, vendor:true, name:'V1')
        h = {'id'=>v.id, 'cmp_name'=>'compname'}
        put :update, id: v.id.to_s, company: h
        expect(response).to be_success
        v.reload
        expect(v.name).to eq 'compname'
        expect(v).to be_vendor
      end
    end
    describe '#show' do
      it 'should get vendor' do
        v = FactoryBot(:company, vendor:true, name:'V1')
        get :show, id: v.id.to_s
        expect(response).to be_success
        h = JSON.parse(response.body)['company']
        expect(h['cmp_name']).to eq 'V1'
      end
    end
  end
end
