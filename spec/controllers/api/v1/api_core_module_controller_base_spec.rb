describe Api::V1::ApiCoreModuleControllerBase do
  describe '#index' do
    controller do
      def core_module
        CoreModule::PRODUCT
      end
    end
    it 'should allow csv download' do
      User.any_instance.stub(:view_products?).and_return true
      Factory(:product,unique_identifier:'myuid')
      allow_api_user Factory(:master_user)
      get :index, format: :csv, fields: 'prod_uid'
      expect(response.body).to eq "#{ModelField.find_by_uid(:prod_uid).label}\nmyuid"
      expect(response).to be_success
    end
  end
end
