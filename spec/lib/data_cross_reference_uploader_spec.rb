describe OpenChain::DataCrossReferenceUploader do
  describe "process" do
    let(:user) { Factory(:user) }
    let!(:co) { Factory(:company, system_code: "ACME") }
    let(:cf) { instance_double "CustomFile" }
    let(:handler) { described_class.new cf }
    let(:row_0) { ['Key', 'Value'] }
    let(:row_1) { ['k1', 'v1'] }
    let(:row_2) { ['k2', 'v2'] }

    before do
      allow(cf).to receive(:id).and_return 1
    end

    it "uploads records, messages user" do
      allow(cf).to receive(:attached_file_name).and_return "xref_upload.xls"
      expect(DataCrossReference).to receive(:xref_edit_hash).with(user).and_return({"xref" => {key_label: "key", value_label: "value", company: {system_code: "ACME"}}})
      expect(handler).to receive(:foreach).with(cf, {skip_blank_lines: true}).and_yield(row_0, 0).and_yield(row_1, 1).and_yield(row_2, 2)
      expect(DataCrossReference).to receive(:preprocess_and_add_xref!).with('xref', 'k1', 'v1', co.id).and_return true
      expect(DataCrossReference).to receive(:preprocess_and_add_xref!).with('xref', 'k2', 'v2', co.id).and_return true

      handler.process user, cross_reference_type: 'xref', company_id: co.system_code
      msg = user.messages.first
      expect(msg.subject).to eq "File Processing Complete"
      expect(msg.body).to eq "Cross-reference upload for file xref_upload.xls is complete."
    end

    it "uploads records without associated company" do
      allow(cf).to receive(:attached_file_name).and_return "xref_upload.xls"
      expect(DataCrossReference).to receive(:xref_edit_hash).with(user).and_return({"xref" => {key_label: "key", value_label: "value"}})
      expect(handler).to receive(:foreach).with(cf, {skip_blank_lines: true}).and_yield(row_0, 0).and_yield(row_1, 1)
      expect(DataCrossReference).to receive(:preprocess_and_add_xref!).with('xref', 'k1', 'v1', nil).and_return true

      handler.process user, cross_reference_type: 'xref'
    end

    it "sets user error message if no key found" do
      row_2 = ['', 'v2']
      allow(cf).to receive(:attached_file_name).and_return "xref_upload.xls"
      expect(DataCrossReference).to receive(:xref_edit_hash).with(user).and_return({"xref" => {key_label: "key", value_label: "value", company: {system_code: "ACME"}}})
      expect(handler).to receive(:foreach).with(cf, {skip_blank_lines: true}).and_yield(row_0, 0).and_yield(row_1, 1).and_yield(row_2, 2)
      expect(DataCrossReference).to receive(:preprocess_and_add_xref!).with('xref', 'k1', 'v1', co.id).and_return true
      expect(DataCrossReference).to receive(:preprocess_and_add_xref!).with('xref', '', 'v2', co.id).and_return false

      handler.process user, cross_reference_type: 'xref', company_id: co.system_code
      msg = user.messages.first
      expect(msg.subject).to eq 'File Processing Complete With Errors'
      expect(msg.body).to eq 'Cross-reference uploader generated errors on the following row(s): 2. Missing or invalid field.'
    end

    it "raises exception for file-type other than csv, xls, xlsx" do
      allow(cf).to receive(:attached_file_name).and_return "xref_upload.txt"
      handler = described_class.new cf
      handler.process user, cross_reference_type: 'xref'
      msg = user.messages.first
      expect(msg.subject).to eq "File Processing Complete With Errors"
      expect(msg.body).to eq "Unable to process file xref_upload.txt due to the following error:<br>Only XLS, XLSX, and CSV files are accepted."
    end
  end
end