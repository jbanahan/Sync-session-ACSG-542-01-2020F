# The type: :model is here to force rspec to not treat this test like a controller
# test and setup request / reesponse / controller etc...just do a plain test
describe AuthTokenSupport, type: :model do

  let (:cookies) { 
    {}
  }

  subject {
    Class.new {
      include AuthTokenSupport

      def current_user
        nil
      end

      def run_as_user
        nil
      end

      def cookies
        nil
      end
    }.new
  }

  describe "set_auth_token_cookie" do

    let (:user) { 
      u = User.new 
      u.username = "user"
      u.api_auth_token = "token"

      u
    }

    let (:run_as) {
      u = User.new 
      u.username = "runas"
      u.api_auth_token = "runastoken"

      u
    }

    it "sets AUTH-TOKEN cookie for current user" do
      expect(subject).to receive(:current_user).at_least(1).times.and_return user
      expect(subject).to receive(:cookies).at_least(1).times.and_return cookies

      subject.set_auth_token_cookie

      expect(cookies["AUTH-TOKEN"]).to eq({value: user.user_auth_token})
    end

    it "sets AUTH_TOKEN cookie and RUN-AS-AUTH-TOKEN" do
      expect(subject).to receive(:current_user).at_least(1).times.and_return user
      expect(subject).to receive(:run_as_user).at_least(1).times.and_return run_as
      expect(subject).to receive(:cookies).at_least(1).times.and_return cookies

      subject.set_auth_token_cookie

      expect(cookies["AUTH-TOKEN"]).to eq({value: user.user_auth_token})
      expect(cookies["RUN-AS-AUTH-TOKEN"]).to eq({value: run_as.user_auth_token})
    end

    it "deletes runas token if user is no longer running as someone else" do
      cookies["RUN-AS-AUTH-TOKEN"] = true

      expect(subject).to receive(:current_user).at_least(1).times.and_return user
      expect(subject).to receive(:cookies).at_least(1).times.and_return cookies

      subject.set_auth_token_cookie

      expect(cookies["RUN-AS-AUTH-TOKEN"]).to be_nil
    end
  end

  describe "user_from_cookie" do
    let! (:user) { Factory(:user, username: "user", api_auth_token: "token") }

    it "finds user from auth-token cookie" do
      cookies["AUTH-TOKEN"] = "user:token"
      u = subject.user_from_cookie(cookies)
      expect(user).to eq u
    end

    it "returns nil if cookie doesn't exist" do
      expect(subject.user_from_cookie cookies).to be_nil
    end
  end

  describe "run_as_user_from_cookie" do
    let! (:user) { Factory(:user, username: "user", api_auth_token: "token") }

    it "finds user from auth-token cookie" do
      cookies["RUN-AS-AUTH-TOKEN"] = "user:token"
      u = subject.run_as_user_from_cookie(cookies)
      expect(user).to eq u
      
    end

    it "returns nil if cookie doesn't exist" do
      expect(subject.run_as_user_from_cookie cookies).to be_nil
    end
  end

  describe "user_from_auth_token" do
    let! (:user) { Factory(:user, username: "user", api_auth_token: "token") }

    it "finds a user given an authtoken" do
      u = subject.user_from_auth_token "user:token"
      expect(u).to eq user
      # Verify groups is preloaded
      expect(u.association(:groups).loaded?).to eq true
    end

    it "returns nil if authtoken doesn't have a token value" do
      expect(subject.user_from_auth_token "user:").to be_nil
    end

    it "returns nil if authtoken doesn't have a user value" do
      expect(subject.user_from_auth_token ":token").to be_nil
    end

    it "returns nil if authtoken is malformed" do
      expect(subject.user_from_auth_token "user").to be_nil
      expect(subject.user_from_auth_token "user:token:token:token").to be_nil
    end

    it "returns nil if authtoken doesn't have a value" do
      expect(subject.user_from_auth_token nil).to be_nil
    end    
  end
end