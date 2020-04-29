describe OpenChain::FiscalMonthReminder do
  let(:now) { Date.new 2016, 02, 15 }
  let(:co) { Factory(:company, name: "ACME", system_code: "ac", fiscal_reference: "release_date") }

  describe "fiscal_months_remaining" do
    let!(:fm_fut_1) { Factory(:fiscal_month, company: co, start_date: '20160301', end_date: "20160331") }
    let!(:fm_fut_2) { Factory(:fiscal_month, company: co, start_date: '20160401', end_date: "20160430") }
    let!(:fm_current) { Factory(:fiscal_month, company: co, start_date: '20160201', end_date: "20160229") }

    it "returns the number of fiscal months with a future start_date assigned to a company if it has a fiscal reference" do
      Timecop.freeze(now) { expect(described_class.fiscal_months_remaining co).to eq 2 }
    end

    it "returns nil if a company doesn't have a fiscal reference" do
      co.update_attributes(fiscal_reference: '')
      Timecop.freeze(now) { expect(described_class.fiscal_months_remaining co).to be_nil }
    end
  end

  describe "calendar_needs_update?" do
    it "returns true if input is 6 or fewer" do
      expect(described_class.calendar_needs_update? 6).to eq true
    end

    it "returns false if input is greater than 6" do
      expect(described_class.calendar_needs_update? 7).to eq false
    end

    it "returns false if input is nil" do
      expect(described_class.calendar_needs_update? nil).to eq false
    end
  end

  describe "companies_needing_update" do
    it "returns list of companies needing update" do
      co
      co_2 = Factory(:company, name: "Konvenientz", system_code: "Ko", fiscal_reference: "release_date")
      7.times { Factory(:fiscal_month, company: co, start_date: '20160301') }
      Timecop.freeze(now) { expect(described_class.companies_needing_update).to eq [co_2] }
    end
  end

  describe "run_schedulable" do
    before { co }

    it "sends email to specified recipient(s) if there is a company with a calendar that needs updating" do
      described_class.run_schedulable({'email' => ['test@vandegriftinc.com']})
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq [ "test@vandegriftinc.com" ]
      expect(mail.subject).to eq "Fiscal calendar(s) need update"
      expect(mail.body).to match(/ACME \(ac\)/)
    end

    it "does nothing if no calendars need updating" do
      co.update_attributes(fiscal_reference: '')
      described_class.run_schedulable({'email' => ['test@vandegriftinc.com']})
      mail = ActionMailer::Base.deliveries.pop
      expect(mail).to be_nil
    end
  end
end