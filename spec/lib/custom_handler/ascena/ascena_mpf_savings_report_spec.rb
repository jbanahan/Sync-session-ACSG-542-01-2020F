describe OpenChain::CustomHandler::Ascena::AscenaMpfSavingsReport do

  subject { described_class }
  let! (:ascena) { with_customs_management_id(create(:importer, name: "Ascena", system_code: "ASCENA"), "ASCE") }
  let! (:ann) { with_customs_management_id(create(:importer, name: "Ann"), "ATAYLOR") }
  let! (:maurices) { with_customs_management_id(create(:importer, name: "Maurices"), "MAUR") }
  let! (:ascena_master) { with_customs_management_id(create(:importer, name: "Ascena Master"), "ASCENAMASTER") }

  describe "permissions" do

    let! (:user) { create(:master_user) }
    let!(:ms) do
      m = stub_master_setup
      allow(m).to receive(:custom_feature?).with("Ascena Reports").and_return true
      allow(user).to receive(:view_entries?).and_return true
      m
    end

    let!(:cust_descriptions) {[{cust_num: "ASCE", sys_code: "ASCENA", name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"},
                               {cust_num: "ATAYLOR", sys_code: "ATAYLOR", name: "ANN TAYLOR INC", short_name: "Ann"},
                               {cust_num: "MAUR", sys_code: "MAUR", name: "MAURICES", short_name: "Maurices"}]}

    it "returns empty if 'Ascena Reports' custom feature absent" do
      allow(ms).to receive(:custom_feature?).with("Ascena Reports").and_return false
      expect(subject.permissions user).to be_empty
    end

    it "returns empty if user can't view entries" do
      allow(user).to receive(:view_entries?).and_return false
      expect(subject.permissions user).to be_empty
    end

    it "returns info for Ascena, Ann, Maurices if master user" do
      expect(subject.permissions user).to eq(cust_descriptions)
    end

    it "returns info for Ascena, Ann, Maurices if user belongs to ASCENAMASTER" do
      user.company = ascena_master; user.company.save!
      expect(subject.permissions user).to eq(cust_descriptions)
    end

    it "returns info for Ascena, Ann, Maurices if user belongs to ASCE_TRADE_ASSOC group" do
      user.company.update master: false
      g = create(:group, system_code: "ASCE_TRADE_ASSOC")
      user.groups << g
      expect(subject.permissions user).to eq(cust_descriptions)
    end

    it "returns only info for user's company if user doesn't belong to privileged category" do
      user.company = ascena; user.company.save!
      expect(subject.permissions user).to eq([{cust_num: "ASCE", sys_code: "ASCENA", name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"}])
    end

    it "omits info for missing company" do
      maurices.destroy
      expect(subject.permissions user).to eq([{cust_num: "ASCE", sys_code: "ASCENA", name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"},
                                              {cust_num: "ATAYLOR", sys_code: "ATAYLOR", name: "ANN TAYLOR INC", short_name: "Ann"}])
    end
  end

  describe "run_schedulable" do
    let!(:current_fm) { create(:fiscal_month, company: ascena, start_date: Date.new(2018, 3, 15), end_date: Date.new(2018, 4, 15), year: 2018, month_number: 2) }
    let!(:previous_fm) { create(:fiscal_month, company: ascena, start_date: Date.new(2018, 2, 15), end_date: Date.new(2018, 3, 14), year: 2018, month_number: 1) }

    it "runs report for previous fiscal month on fourth day of fiscal month" do
      Tempfile.open(["hi", ".xls"]) do |t|
        expect_any_instance_of(subject).to receive(:run).with(previous_fm).and_yield t
        Timecop.freeze(DateTime.new(2018, 3, 18, 12, 0)) do
          subject.run_schedulable('email' => ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'],
                                  'cust_numbers' => ['ASCE', 'ATAYLOR'],
                                  'company' => 'ASCENA',
                                  'fiscal_day' => 4)
        end

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk']
        expect(mail.subject).to eq "Ascena-Ann MPF Savings Report 2018-01"
        expect(mail.body).to match /Attached is the Ascena-Ann MPF Savings Report for 2018-01\./
      end
    end

    it "does nothing on other days" do
      Timecop.freeze(DateTime.new(2018, 3, 20, 12, 0)) do
        subject.run_schedulable('email' => ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'],
                                'cust_numbers' => ['ASCE', 'ATAYLOR'],
                                'company' => 'ASCENA',
                                'fiscal_day' => 3)
      end
      mail = ActionMailer::Base.deliveries.pop
      expect(mail).to be_nil
    end
  end

  describe '.max_mpf_amount' do
    before do
      @entry = create(:entry)
      @klass = described_class.new(['123456'])
    end

    it "returns the highest maximum MPF amount if the entry has no entry date" do
      expect(@klass.max_mpf_amount(@entry)).to eql(BigDecimal.new("519.76"))
    end

    it "returns 519.76 if the entry's entry date is on or after 01/10/2019" do
      @entry.release_date = DateTime.parse("01/10/2019 00:00:00")
      @entry.save!

      expect(@klass.max_mpf_amount(@entry)).to eql(BigDecimal.new("519.76"))
    end

    it "returns 508.70 if the entry's date is before 01/10/2019" do
      @entry.release_date = DateTime.parse("01/09/2019 00:00:00")
      @entry.save!

      expect(@klass.max_mpf_amount(@entry)).to eql(BigDecimal.new("508.70"))
    end

    it "returns 497.99 if the entry's date is before 01/10/2018" do
      @entry.release_date = DateTime.parse("01/09/2018 00:00:00")
      @entry.save!

      expect(@klass.max_mpf_amount(@entry)).to eql(BigDecimal.new("497.99"))
    end
  end

  describe '.min_mpf_amount' do
    before do
      @entry = create(:entry)
      @klass = described_class.new(['123456'])
    end

    it "returns the highest minimum MPF amount if the entry has no entry date" do
      expect(@klass.min_mpf_amount(@entry)).to eql(BigDecimal.new("26.79"))
    end

    it "returns 26.79 if the entry's entry date is on or after 01/10/2019" do
      @entry.release_date = DateTime.parse("01/10/2019 00:00:00")
      @entry.save!

      expect(@klass.min_mpf_amount(@entry)).to eql(BigDecimal.new("26.79"))
    end

    it "returns 26.22 if the entry's date is before 01/10/2019" do
      @entry.release_date = DateTime.parse("01/09/2019 00:00:00")
      @entry.save!

      expect(@klass.min_mpf_amount(@entry)).to eql(BigDecimal.new("26.22"))
    end

    it "returns 25.67 if the entry's date is before 01/10/2018" do
      @entry.release_date = DateTime.parse("01/09/2018 00:00:00")
      @entry.save!

      expect(@klass.min_mpf_amount(@entry)).to eql(BigDecimal.new("25.67"))
    end
  end

  describe '.mpf_calculation_date' do
    before do
      @entry = create(:entry)
      @klass = described_class.new(['123456'])
    end

    it 'prioritizes first_it_date' do
      Timecop.freeze(Date.parse("2019/09/17 07:00:00")) do
        first_it_date = 1.day.ago
        release_date = 2.days.ago
        @entry.first_it_date = first_it_date
        @entry.release_date = release_date
        @entry.save!
        expect(@klass.mpf_calculation_date(@entry)).to eql(first_it_date.to_date)
      end
    end

    it 'returns release_date if no first_it_date' do
      Timecop.freeze(Date.parse("2019/09/17 07:00:00")) do
        release_date = 2.days.ago
        @entry.release_date = release_date
        @entry.save!
        expect(@klass.mpf_calculation_date(@entry)).to eql(release_date)
      end
    end

    it 'returns nil if neither first_it_date or release_date is present' do
      expect(@klass.mpf_calculation_date(@entry)).to eql(nil)
    end
  end

  describe '#generate_initial_hash' do
    before do
      @entry = create(:entry)
      @port = create(:port, name: 'Entry Port')
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
