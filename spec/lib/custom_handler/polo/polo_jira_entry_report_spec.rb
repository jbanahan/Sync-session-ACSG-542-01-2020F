describe OpenChain::CustomHandler:: Polo::PoloJiraEntryReport do

  subject { described_class }

  describe "permission?" do
    before(:each) do
      ms = stub_master_setup
      allow(ms).to receive(:system_code).and_return "www-vfitrack-net"
    end

    it "allows access for master users who can view entries" do
      u = FactoryBot(:master_user)
      expect(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for Polo, non-master users who can view entries" do
      u = FactoryBot(:user)
      u.company.system_code = 'RLMASTER'
      expect(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "prevents access by users who can't view entries" do
      u = FactoryBot(:master_user)
      expect(u).to receive(:view_entries?).and_return false
      expect(subject.permission? u).to eq false
    end

    it "prevents access for non-Polo, non-master users who can view entries" do
      u = FactoryBot(:user)
      u.company.system_code = 'Not Polo'
      expect(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq false
    end
  end

  # run_report can't really be tested at the moment because it involves a Jira database not available to tests.

  describe "run_schedulable" do
    it "intializes the report class and runs it" do
      settings = {"email_to"=>["goofus@fakeemail.com"]}

      allow(Time).to receive(:now).and_return Time.new(2017, 9, 26)

      f = File.open('spec/fixtures/files/test_sheet_1.xls', 'rb')
      expect_any_instance_of(subject).to receive(:run).and_return(f)

      subject.run_schedulable(settings)

      # Verify some settings values were populated by the scheduling method for report-running purposes.
      expect(settings['start_date']).to eq('2017-08-01')
      expect(settings['end_date']).to eq('2017-09-01')

      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eq(["goofus@fakeemail.com"])
      expect(mail.subject).to eq("[VFI Track] Jira Ticket Discrepancy Report for the Month of 08/2017")
      expect(mail.body).to include ERB::Util.html_escape("Attached please find the Jira Ticket Discrepancy Report for the Month of 08/2017.  For any issues related to the report or to change the report email distribution list, please contact VFI Track Support at vfitrack_support@vandegriftinc.com.")
      expect(mail.attachments.length).to eq(1)
    end

    it "fails if no email address provided" do
      settings = {}

      expect_any_instance_of(subject).not_to receive(:run)
      expect(OpenMailer).not_to receive(:send_simple_html)

      expect { subject.run_schedulable(settings) }.to raise_error(RuntimeError, 'Scheduled instances of the Jira Ticket Discrepancy Report must include an email_to setting with an array of email addresses.')

      # Verify some settings values were not populated.
      expect(settings['start_date']).to eq(nil)
      expect(settings['end_date']).to eq(nil)
    end
  end

end