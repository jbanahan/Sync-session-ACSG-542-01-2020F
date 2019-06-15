describe UserManual do
  let (:company) { Factory(:company,:master=>true) }
  let (:user) { Factory(:user, company: company)}

  describe '#for_user_and_page' do
    it "should find for user and page" do
      um1 = Factory(:user_manual,page_url_regex:'vendor_portal')
      Factory(:user_manual,page_url_regex:'dont_find')

      expect(UserManual.for_user_and_page(user,'https://www.vfitrack.net/vendor_portal#something')).to eq [um1]
    end
    it "should not find if user not in groups" do
      Factory(:user_manual,page_url_regex:'vendor_portal',groups:"A\nB")

      expect(UserManual.for_user_and_page(user,'https://www.vfitrack.net/vendor_portal#something')).to eq []
    end
    it "should not find if NOT user can_view?" do
      Factory(:user_manual,page_url_regex:'vendor_portal')
      expect_any_instance_of(UserManual).to receive(:can_view?).and_return false
      expect(UserManual.for_user_and_page(user,'https://www.vfitrack.net/vendor_portal')).to eq []
    end
    it "should find if page_url_regex is blank" do
      um1 = Factory(:user_manual)

      expect(UserManual.for_user_and_page(user,'https://www.vfitrack.net/vendor_portal#something')).to eq [um1]
    end
  end
  describe '#can_view?' do
    it "should be true if user in group" do
      um = Factory(:user_manual,page_url_regex:'vendor_portal',groups:"A\nB")
      
      g = Factory(:group,system_code:'B')
      user.groups << g

      expect(um.can_view?(user)).to be_truthy
    end
    it "should be true if groups are blank" do
      um = Factory(:user_manual,page_url_regex:'vendor_portal')
      expect(um.can_view?(user)).to be_truthy
    end
    it "should be true if user is in master company and user manual is master only" do
      um = Factory(:user_manual,page_url_regex:'vendor_portal',master_company_only: true)

      expect(um.can_view?(user)).to be_truthy
    end
    it "should be false if user not in group" do
      um = Factory(:user_manual,page_url_regex:'vendor_portal',groups:"A\nB")
      expect(um.can_view?(user)).to be_falsey
    end
    it "should be false if user not in master company and user manual is master only" do
      um = Factory(:user_manual,page_url_regex:'vendor_portal',master_company_only: true)
      user.company.update_attributes(:master=>false)
      expect(um.can_view?(user)).to be_falsey
    end
  end
  describe '#to_category_hash' do
    it "should sort within category hash with empty string for nil" do
      u1 = UserManual.new(category:'c99',name:'x')
      u2 = UserManual.new(category:'c27',name:'x')
      u3 = UserManual.new(name:'y')
      u4 = UserManual.new(category:'c99',name:'a')
      
      ch = described_class.to_category_hash([u1,u2,u3,u4])
      
      expected = {''=>[u3],'c27'=>[u2],'c99'=>[u4,u1]}
      expect(ch).to eq expected
    end
  end
end
