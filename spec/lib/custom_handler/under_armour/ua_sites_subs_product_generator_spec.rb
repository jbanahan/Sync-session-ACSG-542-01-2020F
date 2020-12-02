describe OpenChain::CustomHandler::UnderArmour::UaSitesSubsProductGenerator do
  describe "run_and_send_email" do
    it "sends email with attached reports for sites and subs" do
      u = create(:user, time_zone: "Eastern Time (US & Canada)")
      sites_generator = OpenChain::CustomHandler::UnderArmour::UaSitesProductGenerator
      subs_generator = OpenChain::CustomHandler::UnderArmour::UaSubsProductGenerator

      Timecop.freeze(DateTime.new(2017, 05, 01)) do
        Tempfile.open("") do |sites_csv|
          Tempfile.open("") do |subs_csv|
            sites_csv << "test"
            sites_csv.flush
            subs_csv << "test"
            subs_csv.flush
            expect(sites_generator).to receive(:process).and_return sites_csv
            expect(subs_generator).to receive(:process).and_return subs_csv
            described_class.run_and_email u, ["tufnel@stonehenge.biz"]
          end
        end
      end

      expect(ActionMailer::Base.deliveries.count).to eq 1
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["tufnel@stonehenge.biz"]
      expect(mail.subject).to eq "Sites and Subs reports"
      expect(mail.body.raw_source).to include "Sites and Subs reports attached (unless empty)."
      expect(mail.attachments.size).to eq 2
      att1, att2 = mail.attachments
      expect(att1.filename ).to eq "sites_report_2017-04-30.csv"
      expect(att2.filename ).to eq "subs_report_2017-04-30.csv"
    end
  end

end

