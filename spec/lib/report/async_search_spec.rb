describe OpenChain::Report::AsyncSearch do 

  subject { described_class }
  let (:user) { User.new }
  let (:search_setup) { SearchSetup.new download_format: "xlsx", user: user}
  let (:tempfile) { 
    # Write something to the tempfile, this is needed to make sure the attachment is actually added when emailed
    t = Tempfile.new ["temp", ".xlsx"] 
    t.write "Testing"
    t.flush
    t
  }

  after :each do 
    tempfile.close! unless tempfile.closed?
  end

  describe "run" do 
    it "uses SearchWriter to write a report and yields the tempfile created" do
      expect(Tempfile).to receive(:open).and_yield tempfile
      expect(SearchWriter).to receive(:write_search).with(search_setup, tempfile,  user: user, audit: nil)
      expect(SearchSchedule).to receive(:report_name).with(search_setup, "xlsx", include_timestamp: true).and_return "report.xlsx"
      subject.run(user, search_setup) do |t|
        expect(t).to eq tempfile
        expect(t.original_filename).to eq "report.xlsx"
      end
    end

    it "uses SearchWriter to write a report and returns the tempfile created" do
      expect(Tempfile).to receive(:open).and_return tempfile
      expect(SearchWriter).to receive(:write_search).with(search_setup, tempfile, user: user, audit: nil)
      expect(SearchSchedule).to receive(:report_name).with(search_setup, "xlsx", include_timestamp: true).and_return "report.xlsx"

      t = subject.run(user, search_setup)
      expect(t).to eq tempfile
      expect(t.original_filename).to eq "report.xlsx"
    end

    it "raises an error if user doesn't match the search setup" do 
      # I don't know how this could even happen, but I'll leave this check here.
      expect { subject.run(User.new, search_setup) }.to raise_error "You cannot run another user's report.  Your id is , this report is for user "
    end

    it "returns nil if search_setup is nil" do
      expect(subject.run(user, nil)).to eq nil
    end

    it "handles bad chars in the report name for tempfiles" do
      expect(Tempfile).to receive(:open).with(["report_name_", ".xlsx"]).and_yield tempfile
      expect(SearchWriter).to receive(:write_search).with(search_setup, tempfile,  user: user, audit: nil)
      expect(SearchSchedule).to receive(:report_name).with(search_setup, "xlsx", include_timestamp: true).and_return "report/name.xlsx"
      subject.run(user, search_setup) do |t|
        expect(t).to eq tempfile
        expect(t.original_filename).to eq "report/name.xlsx"
      end
    end
  end

  describe "run_and_email_report" do 
    let (:user) { Factory(:user) }
    let (:search_setup) { Factory(:search_setup, name: "Test", user: user, download_format: "xlsx") }

    it "runs report and emails it" do
      expect(Tempfile).to receive(:open).and_yield tempfile
      expect(SearchWriter).to receive(:write_search).with(search_setup, tempfile,  user: user, audit: nil)
      expect(SearchSchedule).to receive(:report_name).with(search_setup, "xlsx", include_timestamp: true).and_return "report.xlsx"

      subject.run_and_email_report user.id, search_setup.id, {to: "me@there.com", subject: "Testing", body: "Testing"}

      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "Testing"
      expect(m.body.raw_source).to include "Testing"
      expect(m.attachments["report.xlsx"]).not_to be_nil
    end

    it "handles raised exceptions" do
      e = StandardError.new "Error!"
      expect(subject).to receive(:run).and_raise e
      expect(e).to receive(:log_me)

      subject.run_and_email_report user.id, search_setup.id, {to: "me@there.com", subject: "Testing", body: "Testing"}

      m = user.messages.first
      expect(m.subject).to eq "Report FAILED: Test"
      expect(m.body).to eq "<p>Your report failed to run due to a system error: Error!</p>"
    end
  end

  describe "run_report" do 
    let (:user) { Factory(:user) }
    let (:search_setup) { Factory(:search_setup, name: "Test", user: user, download_format: "xlsx") }

    it "looks up the search setup and passes it to run" do
      expect(subject).to receive(:run).with(user, search_setup, {"search_setup_id" => search_setup.id})

      subject.run_report user, {"search_setup_id" => search_setup.id}
    end

    it "passes down the given block to run" do
      # This is kinda hokey, but it works...we're passing a proc as a block to the run_report
      # method and then using the rspec method chain to see what's passed to the run methdo, then verifying
      # that the given proc/block is what was passed down
      proc_block = Proc.new {}
      expect(subject).to receive(:run).with(user, search_setup, {"search_setup_id" => search_setup.id}) do |*args, &block|
        expect(proc_block).to be block
      end

      subject.run_report user, {"search_setup_id" => search_setup.id}, &proc_block
    end
  end
end
