require 'spec_helper'

describe Api::V1::SearchTableConfigsController do
  before :each do
    @u = Factory(:user)
    allow_api_access @u
  end
  describe '#for_page' do
    it "should render all for page" do
      config_hash = {'a'=>'b'}
      stc = Factory(:search_table_config,page_uid:'pid',config_json:config_hash.to_json)
      get :for_page, page_uid: 'pid'
      expect(response).to be_success
      expected = {
        'search_table_configs' => [
          {
            "id"=>stc.id,
            "name"=>stc.name,
            "user_id"=>nil,
            "company_id"=>nil,
            "config"=> config_hash
          }
        ]
      }
      expect(JSON.parse(response.body)).to eq expected
    end
  end
end
