describe RunAsSession do

  describe "purge" do
    subject { described_class }

    it "removes anything older than two years" do
      error = nil
      Timecop.freeze(Time.zone.now - 2.years) { error = RunAsSession.create! }

      subject.purge

      expect(error).not_to exist_in_db
    end

    it "does not remove items newer than two years old" do
      error = nil
      Timecop.freeze(Time.zone.now - 1.year) { error = RunAsSession.create! }

      subject.purge

      expect(error).to exist_in_db
    end
  end

end
