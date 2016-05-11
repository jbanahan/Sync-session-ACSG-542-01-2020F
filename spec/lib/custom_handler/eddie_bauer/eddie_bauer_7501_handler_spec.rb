require 'spec_helper'

describe OpenChain::CustomHandler::EddieBauer::EddieBauer7501Handler do
  def create_data
    country = Factory(:country, iso_code: 'US')
    class_1 = Factory(:classification, product: Factory(:product, unique_identifier: "022-3724"), country: country, tariff_records: [Factory(:tariff_record, hts_1: "8513104000")])
    Factory(:classification, product: Factory(:product, unique_identifier: "023-2301"), country: country, tariff_records: [Factory(:tariff_record, hts_2: "foo")])
    Factory(:classification, product: Factory(:product, unique_identifier: "009-0282"), country: country, tariff_records: [Factory(:tariff_record, hts_3: "6104622011")])
    Factory(:classification, product: class_1.product, country: Factory(:country, iso_code: 'CA'), tariff_records: [Factory(:tariff_record, hts_1: "bar" )])
  end

  describe :process do
    before :each do
      @u = Factory(:user, email: "nigel@tufnel.net")
      @u.company.stub(:alliance_customer_number).and_return "EDDIE"

      @row_0 = ['ExitDocID', 'TxnCode', 'ProductNum', 'StatusCode', 'HtsNum', 'AdValoremRate', 'Value', 'ExitPrintDate']
      @row_1 = ['316-1548927-0', 'ANPC', '022-3724-800-0000', 'N', '8513104000', '0.035', '2.98', '2016-03-30 00:00:00']
      @row_2 = ['316-1548927-0', 'ANPC', '023-2301-105-0000', 'N', '9404308000', '0.09', '27.16', '2016-03-30 00:00:00']
      @row_3 = ['316-1548927-0', 'ANPC',  '009-0282-139-0030', 'N', '6104622011', '0.149', '14.35', '2016-03-30 00:00:00']
    
      @cf = double("Custom File")
      @cf.stub(:path).and_return "path/to/audit_file.xls"
      @cf.stub(:attached).and_return double("audit file")
      @cf.stub(:attached_file_name).and_return "audit_file.xls"
    
      @handler = described_class.new @cf
    end

    it "emails user audit spreadsheet" do
      create_data
      @handler.should_receive(:foreach).at_least(2).times.and_yield(@row_0).and_yield(@row_1).and_yield(@row_2).and_yield(@row_3)
      @handler.process @u

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq [ "nigel@tufnel.net" ]
      expect(mail.subject).to eq "Eddie Bauer 7501 Audit"
      expect(mail.body.raw_source).to include "Report attached."
      expect(mail.attachments).to have(1).item
    end

    it "produces correct spreadsheet" do
      create_data
      @handler.should_receive(:foreach).at_least(2).times.and_yield(@row_0).and_yield(@row_1).and_yield(@row_2).and_yield(@row_3)
      @handler.process @u

      mail = ActionMailer::Base.deliveries.pop
      io = StringIO.new(mail.attachments.first.read)
      sheet = Spreadsheet.open(io).worksheet 0

      expect(sheet.rows.length).to eq 4
      expect(sheet.name).to eq "7501 Audit"
      expect(sheet.row(0)).to eq ['ExitDocID', 'TxnCode', 'ProductNum', 'StatusCode', 'HtsNum', 'AdValoremRate', 'Value', 'ExitPrintDate', 'VFI Track - HTS', 'Match?' ]
      expect(sheet.row(1)).to eq ['316-1548927-0', 'ANPC', '022-3724-800-0000', 'N', '8513104000', '0.035', '2.98', '2016-03-30 00:00:00', '8513104000', 'TRUE']
      expect(sheet.row(2)).to eq ['316-1548927-0', 'ANPC', '023-2301-105-0000', 'N', '9404308000', '0.09', '27.16', '2016-03-30 00:00:00', 'foo', 'FALSE']
      expect(sheet.row(3)).to eq ['316-1548927-0', 'ANPC',  '009-0282-139-0030', 'N', '6104622011', '0.149', '14.35', '2016-03-30 00:00:00', '6104622011', 'TRUE']
    end

    it "includes exceptions in error email" do
      @handler.stub(:create_and_send_report!).and_raise "Disaster!"
      @handler.process @u
      mail = ActionMailer::Base.deliveries.pop

      expect(mail.to).to eq [ "nigel@tufnel.net" ]
      expect(mail.subject).to eq "Eddie Bauer 7501 Audit Completed With Errors"
      expect(mail.body.raw_source).to include "Disaster!"
      expect(mail.attachments).to have(0).item
    end

    it "sends error email if non-xls file is submitted"  do
      @cf.stub(:path).and_return "path/to/audit_file.csv"
      @handler.process @u
      mail = ActionMailer::Base.deliveries.pop
      
      expect(mail.body.raw_source).to include "No CI Upload processor exists for .csv file types."
    end
  end

end