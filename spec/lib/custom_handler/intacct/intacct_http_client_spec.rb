describe OpenChain::CustomHandler::Intacct::IntacctHttpClient do

  describe "process_response_body" do
    it "wraps the response body in a REXML::Document" do
      r = subject.send(:process_response_body, "<xml>Test</xml>")
      expect(r).to be_a(REXML::Document)
      expect(r.to_s).to eq REXML::Document.new("<xml>Test</xml>").to_s
    end

    it "logs and raises an error if the body is not valid XML" do
      expect_any_instance_of(REXML::ParseException).to receive(:log_me).with ["Invalid Intacct API Response:\n<Test"]
      expect { subject.send(:process_response_body, "<Test") }.to raise_error REXML::ParseException
    end
  end

  describe "http_request" do
    let (:post) do
      post = Net::HTTP::Post.new(URI.parse("http://localhost"))
      post.body = "<xml>Test</xml>"
      post
    end

    let! (:response) do
      r = instance_double(Net::HTTPResponse)
      allow(r).to receive(:code).and_return "200"
      allow(r).to receive(:[]).and_return({})
      allow(r).to receive(:body).and_return "<xml>Test</xml>"
      r
    end

    it "wraps the response body in a REXML::Document" do
      expect(Net::HTTP).to receive(:start).and_return response

      r = subject.send(:http_request, URI.parse("http://localhost"), post)
      expect(r).to be_a(REXML::Document)
      expect(r.to_s).to eq REXML::Document.new("<xml>Test</xml>").to_s
    end
  end

  describe "before_request_send" do
    let (:headers) { {} }

    it "adds Content-Type header" do
      subject.send(:before_request_send, nil, nil, headers: headers, connection_options: nil)
      expect(headers.size).to eq 1
      expect(headers["Content-Type"]).to eq "x-intacct-xml-request"
    end
  end
end