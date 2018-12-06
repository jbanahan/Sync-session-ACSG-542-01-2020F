describe OpenChain::Report::InboundFileReport do 

  def xlsx mail_attachment
    XlsxTestReader.new(StringIO.new(mail_attachment.read))
  end

  def get_xlsx_data filename: "VFI Track Files 2018-11-02-12-06.xlsx"
    mail = ActionMailer::Base.deliveries.first
    expect(mail).not_to be_nil
    a = mail.attachments[filename]
    expect(a).not_to be_nil
    x = xlsx(a)
    sheet = x.sheet "VFI Track Files" 
    expect(x).not_to be_nil

    x.raw_data sheet
  end

  describe "run" do
    let! (:master_setup) { stub_master_setup }
    let (:settings) { 
      {email_to: "me@there.com"}
    }

    let (:company) { Factory(:company, name: "Company", system_code: "CODE") }
    let! (:rejected_log) { InboundFile.create! company_id: company.id, file_name: "rejected.txt", parser_name: "OpenChain::RejectedParser", process_start_date: Time.zone.parse("2018-11-02 12:00"), process_end_date: Time.zone.parse("2018-11-02 12:05"), process_status: "Rejected"}
    let! (:error_log) { InboundFile.create! company_id: company.id, file_name: "error.txt", parser_name: "OpenChain::ErrorParser", process_start_date: Time.zone.parse("2018-11-02 12:01"), process_end_date: Time.zone.parse("2018-11-02 12:05"), process_status: "Error"}
    let! (:warning_log) { InboundFile.create! company_id: company.id, file_name: "warning.txt", parser_name: "OpenChain::WarningParser", process_start_date: Time.zone.parse("2018-11-02 12:02"), process_end_date: Time.zone.parse("2018-11-02 12:05"), process_status: "Warning"}
    let! (:success_log) { InboundFile.create! company_id: company.id, file_name: "success.txt", parser_name: "OpenChain::SuccessParser", process_start_date: Time.zone.parse("2018-11-02 12:03"), process_end_date: Time.zone.parse("2018-11-02 12:05"), process_status: "Success"}
    
    context "with default settings" do 
      it "runs report and emails to email_to" do
        subject.run Time.zone.parse("2018-11-02 12:04"), Time.zone.parse("2018-11-02 12:06"), settings

        mail = ActionMailer::Base.deliveries.first
        expect(mail).not_to be_nil
        expect(mail.to).to eq ["me@there.com"]
        expect(mail.subject).to eq "VFI Track Files Report"
        a = mail.attachments["VFI Track Files 2018-11-02-12-06.xlsx"]
        expect(a).not_to be_nil

        x = xlsx(a)
        sheet = x.sheet "VFI Track Files" 
        expect(x).not_to be_nil

        data = x.raw_data sheet

        # There's some sort of bug in the xlsx parsing gem (or possibly the xlsx creator) we use.  
        # I think it's using floats internally that's throwing off the times by a second or so, hence the inexactly values below
        expect(data.length).to eq 3
        expect(data[0]).to eq ["Web View", "Parser", "File Name", "Company Name", "Start Time", "End Time", "Status"]
        expect(data[1]).to eq ["Web View", "RejectedParser", "rejected.txt", "Company", Time.zone.parse("2018-11-02 8:00"), Time.zone.parse("2018-11-02 8:04:59"), "Rejected"]
        expect(data[2]).to eq ["Web View", "ErrorParser", "error.txt", "Company", Time.zone.parse("2018-11-02 8:00:59"), Time.zone.parse("2018-11-02 8:04:59"), "Error"]
      end

      it "emails to mailing list" do
        settings["email_to"] = nil
        settings["mailing_list"] = "list"
        MailingList.create! company_id: company.id, user_id: Factory(:user).id, system_code: "list", name: "List", email_addresses: "you@there.com"

        subject.run Time.zone.parse("2018-11-02 12:04"), Time.zone.parse("2018-11-02 12:06"), settings

        mail = ActionMailer::Base.deliveries.first
        expect(mail).not_to be_nil
        expect(mail.to).to eq ["you@there.com"]
      end
    end

    it "restricts by system codes" do
      company = Factory(:company, system_code: "TEST")
      settings["company_system_codes"] = ["TEST"]

      subject.run Time.zone.parse("2018-11-02 12:04"), Time.zone.parse("2018-11-02 12:06"), settings

      data = get_xlsx_data
      expect(data.length).to eq 1
    end

    it "restricts by status" do
      settings["statuses"] = ["Success"]
      subject.run Time.zone.parse("2018-11-02 12:04"), Time.zone.parse("2018-11-02 12:06"), settings

      data = get_xlsx_data
      expect(data.length).to eq 2
      expect(data[1][2]).to eq "success.txt"
    end

    it "outputs csv" do
      settings["output_format"] = "csv"
      subject.run Time.zone.parse("2018-11-02 12:04"), Time.zone.parse("2018-11-02 12:06"), settings

      mail = ActionMailer::Base.deliveries.first
      expect(mail).not_to be_nil
      a = mail.attachments["VFI Track Files 2018-11-02-12-06.csv"]
      expect(a).not_to be_nil

      data = CSV.parse a.read
      expect(data.length).to eq 3
    end
    
  end

  describe "run_schedulable" do
    subject { described_class } 

    let (:job) { 
      j = instance_double(SchedulableJob)
      allow(j).to receive(:id).and_return 100
      j
    }

    it "bases poll key off current schedule's id" do
      expect(SchedulableJob).to receive(:current).and_return job
      start_date = Time.zone.now
      end_date = Time.zone.now
      settings = {}

      expect_any_instance_of(subject).to receive(:run).with(start_date, end_date, settings)
      expect(subject).to receive(:poll).with(job_name: "SchedulableJob-100").and_yield(start_date, end_date)

      subject.run_schedulable settings
    end

    it "uses given job name" do
      start_date = Time.zone.now
      end_date = Time.zone.now
      settings = {"job_name" => "job"}

      expect_any_instance_of(subject).to receive(:run).with(start_date, end_date, settings)
      expect(subject).to receive(:poll).with(job_name: "job").and_yield(start_date, end_date)

      subject.run_schedulable settings
    end
  end

end
