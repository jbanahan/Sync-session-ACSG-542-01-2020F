describe RequestLog do

  let (:request_headers) {
    {"HEADER" => "value"}
  }

  let (:request) { 
    r = instance_double(ActionDispatch::Request)
    allow(r).to receive(:original_url).and_return "URL"
    allow(r).to receive(:method).and_return "METHOD"
    allow(r).to receive(:headers).and_return request_headers
    allow(r).to receive(:uuid).and_return "UUID"

    r
  }

  let (:parameters) {
    {"key" => "value"}
  }

  describe "build_log_from_request" do
    subject { described_class }
    let (:user) { 
      u = User.new
      u.username = "test"
      u
    }

    it "builds a log request" do
      expect(subject).to receive(:request_to_hash).with(request, parameters).and_return({"test"=>"test"})
      expect(subject).to receive(:create_json_attachment).with({"test"=>"test"}, "UUID.json").and_return nil
      log = subject.build_log_from_request user, request, parameters

      expect(log.user).to be user
      expect(log.http_method).to eq "METHOD"
      expect(log.url).to eq "URL"
      a = log.attachment
      expect(a).not_to be_nil
    end
  end

  describe "request_to_hash" do
    subject { described_class }

    it "converts request and parameter data into a hash" do
      now = ActiveSupport::TimeZone["America/New_York"].parse("2017-12-01 08:00:00 -0400")
      expected_hash = {
        timestamp: "2017-12-01T12:00:00Z",
        method: "METHOD",
        url: "URL",
        headers: {
          "HEADER" => "value"
        },
        parameters: {
          "key" => "value"
        }
      }
      Timecop.freeze(now) {
        hash = subject.request_to_hash request, parameters
        expect(hash).to eq expected_hash
      }
    end

    it "skips headers that don't have capitalized first letters" do
      request_headers["hEADER2"] = "value"

      h = subject.request_to_hash request, parameters
      expect(h[:headers]).to eq({"HEADER" => "value"})
    end

    it "replaces any parameter that does not have a string key" do
      parameters["val"] = Object.new

      h = subject.request_to_hash request, parameters
      expect(h[:parameters]).to eq ({"key" => "value", "val" => "[not captured]"})
    end
  end


  describe "create_json_attachment" do
    subject { described_class }

    it "creates a json attachment" do 
      io = subject.create_json_attachment({test: "Testing"}, "file.json")

      expect(io.content_type).to eq "application/json"
      expect(io.original_filename).to eq "file.json"
      expect(io.read).to eq '{"test":"Testing"}'
    end
  end
end
