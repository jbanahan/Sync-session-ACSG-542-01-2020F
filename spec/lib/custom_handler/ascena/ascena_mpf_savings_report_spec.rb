describe OpenChain::CustomHandler::Ascena::AscenaMpfSavingsReport do

  subject { described_class }
  let! (:ascena) { Factory(:importer, alliance_customer_number: "ASCE", name: "Ascena", system_code: "ASCENA") }
  let! (:ann) { Factory(:importer, alliance_customer_number: "ATAYLOR", name: "Ann") }

  describe "permission?" do
    let!(:ms) do
      m = stub_master_setup
      allow(m).to receive(:custom_feature?).with("Ascena Reports").and_return true
      m
    end

    it "allows access for master users who can view entries" do
      u = Factory(:master_user)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for Ascena users who can view entries" do
      u = Factory(:user, company: ascena)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for users of Ascena's parent companies" do
      parent = Factory(:company, linked_companies: [ascena])
      u = Factory(:user, company: parent)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for Ann users who can view entries" do
      u = Factory(:user, company: ann)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for users of Ann's parent companies" do
      parent = Factory(:company, linked_companies: [ann])
      u = Factory(:user, company: parent)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "prevents access by other companies" do
      u = Factory(:user)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq false
    end

    it "prevents access by users who can't view entries" do
      u = Factory(:master_user)
      allow(u).to receive(:view_entries?).and_return false
      expect(subject.permission? u).to eq false
    end

    it "prevents access if Ascena record not found" do
      ascena.destroy
      u = Factory(:user, company: ann)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq false
    end

    it "prevents access if Ann record not found" do
      ann.destroy
      u = Factory(:user, company: ascena)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq false
    end

    it "prevents access on instance without 'Ascena Reports' custom feature" do
      u = Factory(:master_user)
      allow(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("Ascena Reports").and_return false
      expect(subject.permission? u).to eq false
    end
  end

  describe "run_schedulable" do
    let!(:current_fm) { Factory(:fiscal_month, company: ascena, start_date: Date.new(2018,3,15), end_date: Date.new(2018,4,15), year: 2018, month_number: 2) }
    let!(:previous_fm) { Factory(:fiscal_month, company: ascena, start_date: Date.new(2018,2,15), end_date: Date.new(2018,3,14), year: 2018, month_number: 1) }

    it "runs report for previous fiscal month on fourth day of fiscal month" do
      Tempfile.open(["hi", ".xls"]) do |t|
        expect_any_instance_of(subject).to receive(:run).with(previous_fm).and_yield t
        Timecop.freeze(DateTime.new(2018,3,18,12,0)) do
          subject.run_schedulable('email' => ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'],
                                  'cust_numbers' => ['ASCE', 'ATAYLOR'],
                                  'company' => 'ASCENA',
                                  'fiscal_day' => 3)
        end

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk']
        expect(mail.subject).to eq "MPF Savings Report 2018-01"
        expect(mail.body).to match /Attached is the MPF Savings Report for 2018-01\./
      end
    end

    it "does nothing on other days" do
      Timecop.freeze(DateTime.new(2018,3,20,12,0)) do
        subject.run_schedulable('email' => ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'],
                                'cust_numbers' => ['ASCE', 'ATAYLOR'],
                                'company' => 'ASCENA',
                                'fiscal_day' => 3)
      end
      mail = ActionMailer::Base.deliveries.pop
      expect(mail).to be_nil
    end
  end

  describe '#generate_initial_hash' do
    before do
      @entry = Factory(:entry)
      @port = Factory(:port, name: 'Entry Port')
      @entry.transport_mode_code = "1"
      @entry.us_entry_port = @port
      @entry.broker_reference = 'abcdef'
      @entry.entry_number = 'e123number'
      @entry.master_bills_of_lading = "123\n345"
      @entry.save!
    end

    it 'generates the initial hash' do
      expected_initial_hash = {
          transport: "1",
          entry_port_name: 'Entry Port',
          broker_number: 'abcdef',
          entry_number: 'e123number',
          master_bills: ['123', '345'],
          total_master_bills: 2,
          master_bill_list: {},
          totals: {}
      }
      expect(subject.new(nil).generate_initial_hash(@entry)).to eql(expected_initial_hash)
    end
  end

  describe '#calculate_grand_totals' do
    it 'properly calculates the grand total' do
      totals_hash = {
          sum_payable: 100.00,
          sum_mpf: 55.00,
          original_per_bl: 1005.00,
          savings: 1.00
      }

      existing_hash = {
          sum_payable: 5.00,
          sum_mpf: 10.00,
          original_per_bl: 20.00,
          savings: 1.00
      }

      expected_end_hash = {
          sum_payable: 105.00,
          sum_mpf: 65.00,
          original_per_bl: 1025.00,
          savings: 2.00
      }

      subject.new(nil).calculate_grand_totals(existing_hash, totals_hash)

      expect(totals_hash).to eql(expected_end_hash)
    end
  end
end