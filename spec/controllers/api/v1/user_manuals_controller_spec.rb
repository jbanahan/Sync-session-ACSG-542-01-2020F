require 'spec_helper'

describe Api::V1::UserManualsController do
  describe '#index' do
    it "should find for user and page" do
      u = Factory(:user)
      allow_api_access u

      um1 = double(:user_manual,name:'MyManual',id:1)
      um2 = double(:user_manual,name:'AbcManual',id:2)

      source_page = 'https://www.vfitrack.net/vendor_portal'

      UserManual.should_receive(:for_user_and_page).with(u,source_page).and_return [um1,um2]

      # expecting return to be sorted by name
      expected = {
        'user_manuals' => [
          {'id' => 2, 'name' => um2.name},
          {'id' => 1, 'name' => um1.name}
        ]
      }

      get :index, source_page: source_page

      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq expected
    end
  end
end