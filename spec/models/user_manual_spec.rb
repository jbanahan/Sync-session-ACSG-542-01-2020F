require 'spec_helper'

describe UserManual do
  describe '#for_user_and_page' do
    it "should find for user and page" do
      um1 = Factory(:user_manual,page_url_regex:'vendor_portal')
      um2 = Factory(:user_manual,page_url_regex:'dont_find')

      u = Factory(:user)

      expect(UserManual.for_user_and_page(u,'https://www.vfitrack.net/vendor_portal#something')).to eq [um1]
    end
    it "should not find if user not in groups" do
      um1 = Factory(:user_manual,page_url_regex:'vendor_portal',groups:"A\nB")
      u = Factory(:user)

      expect(UserManual.for_user_and_page(u,'https://www.vfitrack.net/vendor_portal#something')).to eq []
    end
    it "should not find if NOT user can_view?" do
      um1 = Factory(:user_manual,page_url_regex:'vendor_portal')
      u = Factory(:user)
      expect_any_instance_of(UserManual).to receive(:can_view?).and_return false
      expect(UserManual.for_user_and_page(u,'https://www.vfitrack.net/vendor_portal')).to eq []
    end
    it "should find if page_url_regex is blank" do
      um1 = Factory(:user_manual)
      u = Factory(:user)

      expect(UserManual.for_user_and_page(u,'https://www.vfitrack.net/vendor_portal#something')).to eq [um1]
    end
  end
  describe '#can_view?' do
    it "should be true if user in group" do
      um = Factory(:user_manual,page_url_regex:'vendor_portal',groups:"A\nB")
      
      g = Factory(:group,system_code:'B')
      u = Factory(:user)
      u.groups << g

      expect(um.can_view?(u)).to be_truthy
    end
    it "should be true if groups are blank" do
      um = Factory(:user_manual,page_url_regex:'vendor_portal')
      u = Factory(:user)
      expect(um.can_view?(u)).to be_truthy
    end
    it "should be false if user not in group" do
      um = Factory(:user_manual,page_url_regex:'vendor_portal',groups:"A\nB")
      u = Factory(:user)
      expect(um.can_view?(u)).to be_falsey
    end
  end
end
