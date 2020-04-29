describe OpenChain::HealthCheckMiddleware do

  let (:app) { lambda {|env| } }

  subject { described_class.new app }

  describe "call" do

    let (:health_check_env) {
      {"PATH_INFO" => "/health_check"}
    }

    let (:master_setup) {
      # Normally I wouldn't bother adding expectations to a lookup, but since this runs
      # very often, I'd like to make sure a very specific query is run
      expect(MasterSetup).to receive(:limit).with(1).and_return MasterSetup
      expect(MasterSetup).to receive(:pluck).with(:uuid).and_return ["12345"]
      MasterSetup.new uuid: "12345"
    }

    it "handles requests to /health_check target by looking up MasterSetup uuid" do
      master_setup
      expect(subject.call health_check_env).to eq [200, {"Content-Type" => "text/plain; charset=utf-8"}, ["12345"]]
    end

    it "passes through requests not send to /health_check" do
      env = {"PATH_INFO" => "/not_health_check"}
      expect(app).to receive(:call).with(env)
      subject.call(env)
    end

    it "handles errors" do
      error = Exception.new("This is an error message")
      error.set_backtrace(["Line 1", "Line 2"])
      expect(MasterSetup).to receive(:limit).and_raise error

      response = subject.call(health_check_env)
      expect(response[0]).to eq 503
      expect(response[1]).to eq({"Content-Type" => "text/plain; charset=utf-8"})
      expect(response[2]).to eq ["This is an error message\n        Line 1\n        Line 2"]
    end
  end

end