describe Api::V1::UserManualsController do
  describe '#index' do
    it "finds for user and page" do
      u = Factory(:user)
      allow_api_access u

      um1 = um2 = nil

      Timecop.freeze(DateTime.new(2019, 3, 15, 12)) do
        um1 = Factory(:user_manual, name: 'Man1', wistia_code: 'wc', category: 'cat')
        um2 = Factory(:user_manual, name: 'AbcManual')
      end

      source_page = 'https://www.vfitrack.net/vendor_portal'

      expect(controller).to receive(:url).with(um1).and_return "custom URL"
      expect(controller).to receive(:url).with(um2).and_return nil
      expect(UserManual).to receive(:for_user_and_page).with(u, source_page).and_return [um1, um2]

      # expecting return to be sorted by name
      expected = {
        'user_manuals' => [
          {'id' => um2.id, 'name' => um2.name, 'url' => nil, 'wistia_code' => nil, 'category' => nil, 'last_update' => '03-15-2019'},
          {'id' => um1.id, 'name' => um1.name, 'url' => 'custom URL', 'wistia_code' => um1.wistia_code, 'category' => um1.category, 'last_update' => '03-15-2019'}
        ]
      }

      get :index, source_page: source_page

      expect(response).to be_success
      expect(JSON.parse(response.body)).to eq expected
    end
  end
end
