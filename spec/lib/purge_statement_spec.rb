describe OpenChain::PurgeStatement do
  subject { described_class }

  describe "run_schedulable" do
    it "executes the purge function" do
      expect(subject).to receive(:purge).once
      subject.run_schedulable
    end
  end

  describe "purge" do
    it "removes anything received more than 5 years by default" do
      m = Factory.create(:monthly_statement, received_date: 5.years.ago)

      subject.purge
      expect {m.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "uses final recieved date in the event recieved date is nil" do
      m = Factory.create(:monthly_statement, final_received_date: 5.years.ago)

      subject.purge
      expect {m.reload}.to raise_error ActiveRecord::RecordNotFound
    end

    it "associated daily statements are removed with the monthly" do
      m = Factory.create(:monthly_statement, final_received_date: 5.years.ago)
      d = Factory.create(:daily_statement, monthly_statement: m)

      subject.purge
      expect {d.reload}.to raise_error ActiveRecord::RecordNotFound
    end
  end
end
