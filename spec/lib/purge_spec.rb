describe OpenChain::Purge do

  subject { described_class }

  describe "purge_data_prior_to", :disable_delayed_jobs do
    let (:reference_date) { Time.zone.now }

    it "purges data" do 
      expect(History).to receive(:purge).with reference_date
      expect(DebugRecord).to receive(:purge).with reference_date
      expect(ErrorLogEntry).to receive(:purge).with reference_date
      expect(FtpSession).to receive(:purge).with reference_date
      expect(SentEmail).to receive(:purge).with reference_date
      expect(InboundFile).to receive(:purge).with reference_date

      expect(Message).to receive(:purge_messages)
      expect(ReportResult).to receive(:purge)
      expect(EntityComparatorLog).to receive(:purge)

      subject.purge_data_prior_to reference_date
    end

    it "delays all purge calls" do
      obj = double("obj").as_null_object

      expect(History).to receive(:delay).and_return obj
      expect(DebugRecord).to receive(:delay).and_return obj
      expect(ErrorLogEntry).to receive(:delay).and_return obj
      expect(FtpSession).to receive(:delay).and_return obj
      expect(SentEmail).to receive(:delay).and_return obj
      expect(InboundFile).to receive(:delay).and_return obj

      expect(Message).to receive(:delay).and_return obj
      expect(ReportResult).to receive(:delay).and_return obj
      expect(EntityComparatorLog).to receive(:delay).and_return obj

      subject.purge_data_prior_to reference_date
    end
  end

  describe "run_schedulable" do
    it "uses config to determine purge timeframe" do
      config = {'years_ago' => 1, 'months_ago' => 6, 'days_ago' => 20}

      now = Time.zone.now

      expect(subject).to receive(:purge_data_prior_to).with (((now - 1.year) - 6.months) - 20.days).change(sec: 0)

      Timecop.freeze { subject.run_schedulable config }
    end

    it "handles just years timeframe" do
      now = Time.zone.now

      expect(subject).to receive(:purge_data_prior_to).with (now - 1.year).change(sec: 0)

      Timecop.freeze { subject.run_schedulable({"years_ago" => 1}) }
    end

    it "handles just months timeframe" do
      now = Time.zone.now

      expect(subject).to receive(:purge_data_prior_to).with (now - 1.month).change(sec: 0)

      Timecop.freeze { subject.run_schedulable({"months_ago" => 1}) }
    end

    it "handles just days timeframe" do
      now = Time.zone.now

      expect(subject).to receive(:purge_data_prior_to).with (now - 1.day).change(sec: 0)

      Timecop.freeze { subject.run_schedulable({"days_ago" => 1}) }
    end

    it "raises an error if no config is set up" do
      expect{subject.run_schedulable({})}.to raise_error "You have not configured a data purge retention period."
    end
  end
end