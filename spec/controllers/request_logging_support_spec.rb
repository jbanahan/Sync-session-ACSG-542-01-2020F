# The type: :model is here to force rspec to not treat this test like a controller
# test and setup request / reesponse / controller etc...just do a plain test
describe RequestLoggingSupport, type: :model do

  let (:fake_request) {
    instance_double(ActionDispatch::Request)
  }

  let (:parameters) {
    {}
  }

  subject {
    Class.new {
      include RequestLoggingSupport

      def current_user
        nil
      end

      def run_as_user
        nil
      end

      def request
        nil
      end

      def params
        nil
      end
    }.new
  }

  describe "log_request" do
    let (:user) {
        User.new
      }

    it "logs request if user has debug active" do
      expect(subject).to receive(:current_user).at_least(1).times.and_return user
      expect(user).to receive(:debug_active?).and_return true
      expect(subject).to receive(:params).and_return parameters
      expect(subject).to receive(:request).and_return fake_request
      expect(RequestLog).to receive(:build_log_from_request).with(user, fake_request, parameters).and_return RequestLog.new

      subject.log_request

      expect(RequestLog.all.size).to eq 1
    end

    it "does not log if user does not have debug active" do
      expect(subject).to receive(:current_user).at_least(1).times.and_return user
      expect(user).to receive(:debug_active?).and_return false

      subject.log_request
      expect(RequestLog.all.size).to eq 0
    end

    it "does nothing if user is nil" do
      subject.log_request
      expect(RequestLog.all.size).to eq 0
    end
  end

  describe "log_run_as_request" do
    let (:run_as) { Factory(:user, username: "run_as") }
    let (:user) { Factory(:user, username: "user", run_as: run_as) }

    it "logs the run as request" do
      expect(subject).to receive(:current_user).at_least(1).times.and_return run_as
      expect(subject).to receive(:run_as_user).at_least(1).times.and_return user

      expect(subject).to receive(:params).and_return parameters
      expect(subject).to receive(:request).and_return fake_request
      expect(RequestLog).to receive(:build_log_from_request).with(user, fake_request, parameters).and_return RequestLog.new

      now = Time.zone.parse "2017-01-01 12:00"
      Timecop.freeze(now) { subject.log_run_as_request }

      session = RunAsSession.current_session(user).first
      expect(session).not_to be_nil
      expect(session.user_id).to eq user.id
      expect(session.run_as_user_id).to eq run_as.id
      expect(session.start_time).to eq now

      expect(session.request_logs.length).to eq 1
    end

    it "uses an existing RunAsSession" do
      session = RunAsSession.create! user_id: user.id, run_as_user_id: run_as.id, start_time: Time.zone.now

      expect(subject).to receive(:current_user).at_least(1).times.and_return run_as
      expect(subject).to receive(:run_as_user).at_least(1).times.and_return user

      expect(subject).to receive(:params).and_return parameters
      expect(subject).to receive(:request).and_return fake_request
      expect(RequestLog).to receive(:build_log_from_request).with(user, fake_request, parameters).and_return RequestLog.new

      subject.log_run_as_request

      session.reload
      expect(session.request_logs.length).to eq 1
    end

    it "no-ops if user is not running as anyone else" do
      expect(subject).to receive(:current_user).at_least(1).times.and_return run_as
      expect(subject).to receive(:run_as_user).at_least(1).times.and_return nil
      expect(RunAsSession).not_to receive(:current_session)

      subject.log_run_as_request
    end

    it "no-ops if user is not logged in" do
      expect(subject).to receive(:current_user).and_return nil
      expect(RunAsSession).not_to receive(:current_session)

      subject.log_run_as_request
    end
  end
end