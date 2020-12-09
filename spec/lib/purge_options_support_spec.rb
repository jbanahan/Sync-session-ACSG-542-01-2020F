describe OpenChain::PurgeOptionsSupport do

  subject do
    Class.new do
      include OpenChain::PurgeOptionsSupport

      def self.purge older_than: nil # rubocop:disable Lint/UnusedMethodArgument
        nil
      end

    end
  end

  describe "execute_purge" do

    let (:options) { {"years_old" => 5} }
    let (:now) { Time.zone.now }

    it "parses years_old argument from options, and passes it to 'purge' method" do
      expect(subject).to receive(:purge).with(older_than: (now.in_time_zone("America/New_York").beginning_of_day - 5.years))

      subject.execute_purge(options, default_years_ago: 3)
    end

    it "falls back to default value if no 'years_ago' key is present" do
      options.delete "years_old"
      expect(subject).to receive(:purge).with(older_than: (now.in_time_zone("America/New_York").beginning_of_day - 3.years))

      subject.execute_purge(options, default_years_ago: 3)
    end

    it "allows for using alternate timezone in options" do
      options["time_zone"] = "America/Chicago"
      expect(subject).to receive(:purge).with(older_than: (now.in_time_zone("America/Chicago").beginning_of_day - 5.years))

      subject.execute_purge(options, default_years_ago: 3)
    end

    it "allows for implementing class to define alternate default_timezone" do
      expect(subject).to receive(:default_timezone).and_return "America/Chicago"

      expect(subject).to receive(:purge).with(older_than: (now.in_time_zone("America/Chicago").beginning_of_day - 5.years))

      subject.execute_purge(options, default_years_ago: 3)
    end
  end
end