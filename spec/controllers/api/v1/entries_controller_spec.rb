require 'spec_helper'

describe Api::V1::EntriesController do

  describe :validate do
    it "runs validations and returns result hash" do
      MasterSetup.get.update_attributes(:entry_enabled=>true)
      u = Factory(:master_user,entry_view:true)
      allow_api_access u
      ent = Factory(:entry)
      bvt = BusinessValidationTemplate.create!(module_type:'Entry')
      bvt.search_criterions.create! model_field_uid: "ent_entry_num", operator: "nq", value: "XXXXXXXXXX"
      
      post :validate, id: ent.id, :format => 'json'
      expect(bvt.business_validation_results.first.validatable).to eq ent
      expect(JSON.parse(response.body)["business_validation_result"]["single_object"]).to eq "Entry"
    end
  end
end