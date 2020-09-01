describe ApiSession do

  let(:api_session) { Factory(:api_session, last_server_response: nil, class_name: "OpenChain::CustomHandler::SomeGenerator") }
  let(:user) { Factory(:user) }

  describe "can_view?" do
    it "allows sys_admin users to view" do
      user.sys_admin = true
      user.save!
      expect(subject.can_view?(user)).to eq true
      user.sys_admin = false
      expect(subject.can_view?(user)).to eq false
    end
  end

  context "attachments" do
    let(:req_file) { Factory(:attachment, attachable: api_session, attachment_type: "request", attached_file_name: "req") }
    let(:resp_file1) { Factory(:attachment, attachable: api_session, attachment_type: "response", attached_file_name: "resp1") }
    let(:resp_file2) { Factory(:attachment, attachable: api_session, attachment_type: "response", attached_file_name: "resp2") }

    before do
      req_file; resp_file1; resp_file2
      resp_file1.created_at = Time.zone.now + 1.day
      resp_file1.save!
    end

    describe "request_file, request_file=" do
      it "assigns/retrieves request file, assigns attachment filename to request_file_name attribute" do
        req_file.attachable = nil; req_file.save!
        expect(api_session.request_file).to be_nil
        expect(api_session.request_file_name).to be_nil

        api_session.request_file = req_file
        api_session.save!
        expect(api_session.request_file).to eq req_file
        expect(api_session.request_file_name).to eq "req"
      end
    end

    describe "response_files" do
      it "retries response files ordered by creation date" do
        expect(api_session.response_files).to eq [resp_file2, resp_file1]
      end
    end
  end

  describe "successful" do
    it "returns 'Y' for 'OK' server response" do
      api_session.update! last_server_response: "OK"
      expect(api_session.successful).to eq 'Y'
    end

    it "returns 'N' any number" do
      api_session.update! last_server_response: "322"
      expect(api_session.successful).to eq 'N'
    end

    it "returns nil if no response" do
      expect(api_session.successful).to be_nil
    end
  end

  describe "short_class_name" do
    it "returns class_name without namespacing" do
      expect(api_session.short_class_name).to eq "SomeGenerator"
    end
  end

  describe "purge" do
    subject { described_class }

    it "removes anything older than given date" do
      session = nil
      Timecop.freeze(Time.zone.now - 1.second) { session = Factory(:api_session) }

      subject.purge Time.zone.now

      expect {session.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "does not remove items newer than given date" do
      session = nil
      now = Time.zone.now
      Timecop.freeze(now + 1.second) { session = Factory(:api_session) }

      subject.purge now

      expect {session.reload}.not_to raise_error
    end
  end

end
