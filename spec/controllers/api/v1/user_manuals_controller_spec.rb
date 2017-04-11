require 'spec_helper'

describe Api::V1::UserManualsController do
  describe '#index' do
    it "should find for user and page" do
      u = Factory(:user)
      allow_api_access u

      um1 = UserManual.new(name:'Man1',wistia_code:'wc',category:'cat')
      um1.id = 1
      um2 = UserManual.new(name:'AbcManual')
      um2.id = 2

      source_page = 'https://www.vfitrack.net/vendor_portal'

      expect(UserManual).to receive(:for_user_and_page).with(u,source_page).and_return [um1,um2]

      # expecting return to be sorted by name
      expected = {
        'user_manuals' => [
          {'id' => 2, 'name' => um2.name, 'wistia_code' => nil, 'category' => nil},
          {'id' => 1, 'name' => um1.name, 'wistia_code' => um1.wistia_code, 'category' => um1.category}
        ]
      }

      get :index, source_page: source_page

      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq expected
    end
  end
end
