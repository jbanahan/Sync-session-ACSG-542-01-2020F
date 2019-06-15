describe Api::V1::BusinessRulesController do
  before :each do
    @u = Factory(:master_user)
    allow_api_access @u
  end
  describe '#for_module' do
    it 'should return business rules hash' do
      h = {'a'=>'b'}
      ord = Factory(:order)
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      allow_any_instance_of(User).to receive(:view_business_validation_results?).and_return true
      expect_any_instance_of(described_class).to receive(:results_to_hsh).with(@u,ord).and_return h

      get :for_module, module_type: 'Order', id: ord.id.to_s

      expect(response).to be_success
      expected_response = {'business_rules'=>h}
      expect(JSON.parse(response.body)).to eq expected_response
    end
    it 'should return 404 for bad module type' do
      ord = Factory(:order)
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      get :for_module, module_type: 'BAD', id: ord.id.to_s

      expect(response).to_not be_success

      expect(response.status).to eq 404
    end
    it 'should return 404 if object does not exist' do
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      get :for_module, module_type: 'Order', id: '999'

      expect(response).to_not be_success

      expect(response.status).to eq 404
    end
    it 'should return 401 if user cannot view business rules' do
      h = {'a'=>'b'}
      ord = Factory(:order)
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      allow_any_instance_of(User).to receive(:view_business_validation_results?).and_return false
      expect_any_instance_of(described_class).to receive(:results_to_hsh).with(@u,ord).and_return h

      get :for_module, module_type: 'Order', id: ord.id.to_s

      expect(response).to_not be_success
    end
  end

  describe '#refresh' do
    it 'should update business rule and return result' do
      h = {'a'=>'b'}
      ord = Factory(:order)
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      allow_any_instance_of(User).to receive(:view_business_validation_results?).and_return true
      expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with(ord)
      expect_any_instance_of(described_class).to receive(:results_to_hsh).with(@u,ord).and_return h

      post :refresh, module_type: 'Order', id: ord.id.to_s

      expect(response).to be_success
      expected_response = {'business_rules'=>h}
      expect(JSON.parse(response.body)).to eq expected_response
    end
    it 'should return 404 for bad module type' do
      ord = Factory(:order)
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      post :refresh, module_type: 'BAD', id: ord.id.to_s

      expect(response).to_not be_success

      expect(response.status).to eq 404
    end
    it 'should return 404 if object does not exist' do
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      post :refresh, module_type: 'Order', id: '999'

      expect(response).to_not be_success

      expect(response.status).to eq 404
    end
    it 'should return 401 if user cannot view business rules' do
      ord = Factory(:order)
      allow_any_instance_of(Order).to receive(:can_view?).and_return true
      allow_any_instance_of(User).to receive(:view_business_validation_results?).and_return false

      post :refresh, module_type: 'Order', id: ord.id.to_s

      expect(response).to_not be_success
    end
  end
end
