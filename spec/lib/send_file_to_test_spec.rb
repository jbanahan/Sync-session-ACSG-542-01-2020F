describe OpenChain::SendFileToTest do
  describe "execute" do

    let(:tempfile) do
      t = Tempfile.new ['file', '.txt']
      t << "File Contents"
      t.flush
      t
    end

    before do
      ms = stub_master_setup
      allow(ms).to receive(:send_test_files_to_instance).and_return "test_server"
    end

    after do
      tempfile.close! unless tempfile.closed?
    end

    it "sends file to test" do
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("this_bucket",
                                                                   "2018-05/04/www.vfitrack.net/_kewill_entry/long_file_name.json",
                                                                   original_filename: "foo.json")
                                                             .and_yield tempfile
      expect(subject).to receive(:ftp_file)
        .with(tempfile, {server: 'connect.vfitrack.net', username: 'ecs', password: 'wzuomlo',
                         folder: "test_server/_kewill_entry", protocol: 'sftp', port: 2222, remote_file_name: "long_file_name.json"})
      subject.execute "this_bucket", "2018-05/04/www.vfitrack.net/_kewill_entry/long_file_name.json", options: {original_filename: "foo.json"}
    end
  end
end
