describe OpenChain::UserSupport::CreateUserFromTemplate do
  let!(:current_user) { Factory(:user, email: "some@thing.xyz") }
  subject { OpenChain::UserSupport::CreateUserFromTemplate }

  describe 'transactional_user_creation' do
    it "creates a user safely and returns true if completed" do
      new_user = Factory(:user)
      expect(subject.transactional_user_creation new_user, current_user, nil, nil).to eq true
    end

    it "rollsback change on failure" do
      expect{subject.transactional_user_creation(Factory(:user, email: current_user.email),
        current_user, nil, nil)}.to raise_exception(ActiveRecord::RecordInvalid, "Validation failed: Email has already been taken")
        .and change {User.count}.by(0)
    end
  end

  describe "build_user" do
    it "builds a user given a template and unique user information" do
      template_json = {
        homepage:'/something',
        department:'blah'
      }
      t = Factory(:user_template, template_json: template_json.to_json)

      c = Factory(:company)
      first_name = "Joe"
      last_name = "Smith"
      email = "jsmith@domain.tld"
      time_zone = "Eastern Time (US & Canada)"

      u = subject.build_user t, c, first_name, last_name, nil, email, time_zone
      expect(u.username).to eq email
      expect(u.first_name).to eq first_name
      expect(u.last_name).to eq last_name
      expect(u.email).to eq email
      expect(u.time_zone).to eq time_zone
      expect(u.homepage).to eq '/something'
      expect(u.department).to eq 'blah'
      expect(u.disallow_password).to eq false
      expect(u.email_format).to eq 'html'
      expect(u.email_new_messages).to eq false
      expect(u.password_reset).to eq true
      expect(u.company).to eq c
    end
  end
end
