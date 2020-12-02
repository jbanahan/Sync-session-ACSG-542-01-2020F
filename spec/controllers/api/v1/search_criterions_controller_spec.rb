describe Api::V1::SearchCriterionsController do
  let(:user) { create(:master_user) }
  let(:search_setup) { create(:search_setup, user: user) }
  let(:criterion) { search_setup.search_criterions.create! value: "ABC", operator: "gt", model_field_uid: "prod_uid"}

  before do
    allow_api_access user
  end

  describe "create" do

    it "creates a new search_criterion" do
      post :create, {search_criterion: {linked_object_type: "SearchSetup", linked_object_id: search_setup.id, operator: "eq", value: "1", model_field_uid: "prod_uid"}}
      expect(response).to be_success

      search_setup.reload
      expect(search_setup.search_criterions.length).to eq 1
      sc = search_setup.search_criterions.first

      j = JSON.parse response.body

      expect(j).to eq({'search_criterion' => {'id' => sc.id, 'value' => sc.value, 'operator' => sc.operator,
                                              'model_field_uid' => sc.model_field_uid, 'include_empty' => sc.include_empty?,
                                              'label' => "Unique Identifier", 'datatype' => "string"}})
    end

    it "fails if user can't edit linked object" do
      user = create(:user)
      allow_api_access user

      post :create, {search_criterion: {linked_object_type: "SearchSetup", linked_object_id: search_setup.id, operator: "eq", value: "1", model_field_uid: "prod_uid"}}
      expect(response.status).to eq 404
    end

    it "fails if linked object doesn't exist" do
      post :create, {search_criterion: {linked_object_type: "SearchSetup", linked_object_id: -1, operator: "eq", value: "1", model_field_uid: "prod_uid"}}
      expect(response.status).to eq 404
    end

    it "returns errors if update validations fail" do
      post :create, {search_criterion: {linked_object_type: "SearchSetup", linked_object_id: search_setup.id, operator: nil, value: "1", model_field_uid: "prod_uid"}}
      expect(response.status).to eq 500

      j = JSON.parse response.body
      expect(j['errors']).not_to be_empty
    end
  end

  describe "update" do

    it "updates an existing criterion" do
      put :update, {id: criterion.id, search_criterion: {linked_object_type: "SearchSetup", linked_object_id: criterion.search_setup.id,
                                                         operator: "eq", value: "1", model_field_uid: "prod_name", include_empty: true}}
      expect(response).to be_success
      j = JSON.parse response.body

      expect(j).to eq({'search_criterion' => {'id' => criterion.id, 'value' => '1', 'operator' => 'eq',
                                              'model_field_uid' => 'prod_name', 'include_empty' => true, 'label' => "Name",
                                              'datatype' => "string"}})
    end

    it "fails if user can't edit linked object" do
      user = create(:user)
      allow_api_access user

      put :update, {id: criterion.id, search_criterion: {linked_object_type: "SearchSetup", linked_object_id: criterion.search_setup.id,
                                                         operator: "eq", value: "1", model_field_uid: "prod_uid",
                                                         label: "Unique Identifier", datatype: "string"}}
      expect(response.status).to eq 404
    end

    it "fails if linked object doesn't exist" do
      put :update, {id: criterion.id, search_criterion: {linked_object_type: "SearchSetup", linked_object_id: -1, operator: "eq", value: "1", model_field_uid: "prod_uid"}}
      expect(response.status).to eq 404
    end

    it "fails if id does not belong to linked object" do
      another_ss = create(:search_setup, user: user)

      put :update, {id: criterion.id, search_criterion: {linked_object_type: "SearchSetup", linked_object_id: another_ss.id,
                                                         operator: "eq", value: "1", model_field_uid: "prod_uid"}}
      expect(response.status).to eq 404
    end

    it "returns errors if update validations fail" do
      put :update, {id: criterion.id, search_criterion: {linked_object_type: "SearchSetup", linked_object_id: criterion.search_setup.id,
                                                         operator: nil, value: "1", model_field_uid: "prod_uid"}}
      expect(response.status).to eq 500

      j = JSON.parse response.body
      expect(j['errors']).not_to be_empty
    end
  end

  describe "destroy" do

    it "deletes a criterion" do
      delete :destroy, {id: criterion.id, search_criterion: {linked_object_type: "SearchSetup", linked_object_id: criterion.search_setup.id}}
      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq({"OK" => "OK"})
    end

    it "fails if user can't edit linked object" do
      user = create(:user)
      allow_api_access user

      delete :destroy, {id: criterion.id, search_criterion: {linked_object_type: "SearchSetup", linked_object_id: criterion.search_setup.id}}
      expect(response.status).to eq 404
    end

    it "fails if linked object doesn't exist" do
      delete :destroy, {id: criterion.id, search_criterion: {linked_object_type: "SearchSetup", linked_object_id: -1, operator: "eq", value: "1", model_field_uid: "prod_uid"}}
      expect(response.status).to eq 404
    end

    it "fails if id does not belong to linked object" do
      another_ss = create(:search_setup, user: user)

      delete :destroy, {id: criterion.id, search_criterion: {linked_object_type: "SearchSetup", linked_object_id: another_ss.id,
                                                             operator: "eq", value: "1", model_field_uid: "prod_uid"}}
      expect(response.status).to eq 404
    end
  end

  describe "index" do

    it "returns search criterions" do
      get :index, {search_criterion: {linked_object_type: "SearchSetup", linked_object_id: criterion.search_setup.id}}

      expect(response).to be_success
      j = JSON.parse response.body
      expect(j).to eq({'search_criterions' => [{'id' => criterion.id, 'value' => "ABC", 'operator' => "gt", 'model_field_uid' => "prod_uid",
                                                'include_empty' => false, 'label' => "Unique Identifier", 'datatype' => "string"}]})
    end

    it "fails if user can't view linked object" do
      user = create(:user)
      allow_api_access user
      get :index, {search_criterion: {linked_object_type: "SearchSetup", linked_object_id: criterion.search_setup.id}}

      expect(response.status).to eq 404
    end

    it "fails if linked object doesn't exist" do
      get :index, {search_criterion: {linked_object_type: "SearchSetup", linked_object_id: -1}}
      expect(response.status).to eq 404
    end
  end
end