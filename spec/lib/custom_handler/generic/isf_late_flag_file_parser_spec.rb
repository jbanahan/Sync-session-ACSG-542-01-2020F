describe OpenChain::CustomHandler::Generic::IsfLateFlagFileParser do
  let(:user) { Factory(:user) }
  let(:custom_file) { double "custom file "}
  before { allow(custom_file).to receive(:attached_file_name).and_return "file.xls" }

  describe 'can_view?' do
    let(:subject) { described_class.new(nil) }
    let(:ms) { stub_master_setup }

    it "allow master users on systems with feature" do
      expect(ms).to receive(:custom_feature?).with('ISF Late Filing Report').and_return true
      expect(user.company).to receive(:broker?).and_return true
      expect(subject.can_view? user).to eq true
    end

    it "blocks non-master users on systems with feature" do
      allow(ms).to receive(:custom_feature?).with('ISF Late Filing Report').and_return true
      expect(user.company).to receive(:broker?).and_return false
      expect(subject.can_view? user).to eq false
    end

    it "blocks master users on systems without feature" do
      expect(ms).to receive(:custom_feature?).with('ISF Late Filing Report').and_return false
      expect(user.company).to receive(:broker?).and_return true
      expect(subject.can_view? user).to eq false
    end
  end

  describe 'valid_file?' do
    it "allows expected file extensions and forbids weird ones" do
      expect(OpenChain::CustomHandler::Generic::IsfLateFlagFileParser.valid_file? 'abc.CSV').to eq true
      expect(OpenChain::CustomHandler::Generic::IsfLateFlagFileParser.valid_file? 'abc.csv').to eq true
      expect(OpenChain::CustomHandler::Generic::IsfLateFlagFileParser.valid_file? 'def.XLS').to eq true
      expect(OpenChain::CustomHandler::Generic::IsfLateFlagFileParser.valid_file? 'def.xls').to eq true
      expect(OpenChain::CustomHandler::Generic::IsfLateFlagFileParser.valid_file? 'ghi.XLSX').to eq true
      expect(OpenChain::CustomHandler::Generic::IsfLateFlagFileParser.valid_file? 'ghi.xlsx').to eq true
      expect(OpenChain::CustomHandler::Generic::IsfLateFlagFileParser.valid_file? 'xls.txt').to eq false
      expect(OpenChain::CustomHandler::Generic::IsfLateFlagFileParser.valid_file? 'abc.').to eq false
    end
  end

  describe 'process' do
    let(:subject) { described_class.new(custom_file) }
    let(:file_reader) { double "dummy reader" }
    let!(:transaction_1) { Factory(:security_filing, transaction_number: "Transaction1") }
    let!(:transaction_2) { Factory(:security_filing, transaction_number: "Transaction2") }

    let(:header_row) { ["A", "B", "C", "D", "E", "F", "G", "H"] }
    let(:blank_row) { ["", "", "", "", "", "", "", ""] }
    let(:row_1) { ["x", "x", "x", "Transaction-1", "x", "x", "07/21/17 05:33:33 PM", "07/20/17 01:02:03 AM"] }
    let(:row_2) { ["x", "x", "x", "Transaction-2", "x", "x", "07/22/17 12:34:56 PM", "07/21/17 12:12:12 PM"] }

    it "parses file and updates transaction records" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_yield(header_row).and_yield(header_row).and_yield(blank_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(blank_row).and_yield(header_row).and_yield(row_1).and_yield(blank_row).and_yield(row_2)

      subject.process user
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete"
      expect(m.body).to eq "ISF Late Flag processing for file 'file.xls' is complete."

      transaction_1_saved = SecurityFiling.where(transaction_number: 'Transaction1').first
      expect(transaction_1_saved).not_to be_nil
      expect(transaction_1_saved.late_filing).to eq(true)
      expect(transaction_1_saved.us_customs_first_file_date).to eq(DateTime.new(2017, 7, 21, 17, 33, 33, ActiveSupport::TimeZone["America/New_York"].now.zone))
      expect(transaction_1_saved.vessel_departure_date).to eq(DateTime.new(2017, 7, 20, 1, 2, 3, ActiveSupport::TimeZone["America/New_York"].now.zone))

      transaction_2_saved = SecurityFiling.where(transaction_number: 'Transaction2').first
      expect(transaction_2_saved).not_to be_nil
      expect(transaction_2_saved.late_filing).to eq(true)
      expect(transaction_2_saved.us_customs_first_file_date).to eq(DateTime.new(2017, 7, 22, 12, 34, 56, ActiveSupport::TimeZone["America/New_York"].now.zone))
      expect(transaction_2_saved.vessel_departure_date).to eq(DateTime.new(2017, 7, 21, 12, 12, 12, ActiveSupport::TimeZone["America/New_York"].now.zone))
    end

    it "errors when ISF transactions are not found" do
      SecurityFiling.where(transaction_number: 'Transaction1').delete_all
      SecurityFiling.where(transaction_number: 'Transaction2').delete_all

      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(row_1).and_yield(row_2)

      subject.process user
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "ISF Late Flag processing for file 'file.xls' is complete.\n\nFailed to process Transaction Number 'Transaction-1' due to the following error: 'ISF transaction could not be found.'\nFailed to process Transaction Number 'Transaction-2' due to the following error: 'ISF transaction could not be found.'"
    end

    it "errors when file is missing Transaction Number" do
      row_missing_transaction = ["x", "x", "x", "", "x", "x", "07/21/17 05:33:33 PM", "07/20/17 01:02:03 AM"]

      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(header_row).and_yield(row_missing_transaction)

      subject.process user
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "ISF Late Flag processing for file 'file.xls' is complete.\n\nFailed to process Transaction Number '' due to the following error: 'Transaction Number is required for all lines.'"
    end

    it "catches and logs exceptions" do
      expect(subject).to receive(:file_reader).with(custom_file).and_return(file_reader)
      expect(file_reader).to receive(:foreach).and_raise("Terrible Exception")

      subject.process user
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "ISF Late Flag processing for file 'file.xls' is complete.\n\nThe following fatal error was encountered: Terrible Exception"
    end
  end

end