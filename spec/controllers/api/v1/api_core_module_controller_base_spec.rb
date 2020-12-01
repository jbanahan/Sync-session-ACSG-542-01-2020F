describe Api::V1::ApiCoreModuleControllerBase do
  describe '#index' do
    controller do
      def core_module
        CoreModule::PRODUCT
      end
    end
    it 'should allow csv download' do
      allow_any_instance_of(User).to receive(:view_products?).and_return true
      FactoryBot(:product, unique_identifier:'myuid')
      allow_api_user FactoryBot(:master_user)
      get :index, format: :csv, fields: 'prod_uid'
      expect(response.body).to eq "#{ModelField.find_by_uid(:prod_uid).label}\nmyuid"
      expect(response).to be_success
    end
  end
end
