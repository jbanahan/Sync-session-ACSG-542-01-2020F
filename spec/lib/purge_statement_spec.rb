describe OpenChain::PurgeStatement do
  subject { described_class }

  describe "run_schedulable" do

    let (:now) { Time.zone.now }

    it "executes the purge function" do
      start_date = now.in_time_zone("America/New_York").beginning_of_day - 5.years
      expect(subject).to receive(:purge).with(older_than: start_date)

      Timecop.freeze(now) do
        subject.run_schedulable({})
      end
    end

    it "uses alternate years_old value" do
      start_date = now.in_time_zone("America/New_York").beginning_of_day - 10.years
      expect(subject).to receive(:purge).with(older_than: start_date)

      Timecop.freeze(now) do
        subject.run_schedulable({"years_old" => 10})
      end
    end
  end

  describe "purge" do
    it "removes anything received more than 5 years by default" do
      m = FactoryBot.create(:monthly_statement, received_date: 5.years.ago)

      subject.purge older_than: 5.years.ago
      expect(m).not_to exist_in_db
    end

    it "uses final recieved date in the event recieved date is nil" do
      m = FactoryBot.create(:monthly_statement, final_received_date: 5.years.ago)

      subject.purge older_than: 5.years.ago
      expect(m).not_to exist_in_db
    end

    it "associated daily statements are removed with the monthly" do
      m = FactoryBot.create(:monthly_statement, final_received_date: 5.years.ago)
      d = FactoryBot.create(:daily_statement, monthly_statement: m)

      subject.purge older_than: 5.years.ago
      expect(m).not_to exist_in_db
      expect(d).not_to exist_in_db
    end
  end
end
