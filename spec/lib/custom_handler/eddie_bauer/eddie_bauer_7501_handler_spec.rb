describe OpenChain::CustomHandler::EddieBauer::EddieBauer7501Handler do
  def create_data
    country = Factory(:country, iso_code: 'US')
    class_1 = Factory(:classification, product: Factory(:product, unique_identifier: "EDDIE-022-3724"), country: country, tariff_records: [Factory(:tariff_record, hts_1: "8513104000")])
    Factory(:classification, product: Factory(:product, unique_identifier: "EDDIE-023-2301"), country: country, tariff_records: [Factory(:tariff_record, hts_1: "foo")])
    Factory(:classification, product: Factory(:product, unique_identifier: "EDDIE-009-0282"), country: country, tariff_records: [Factory(:tariff_record, hts_1: "6104622011")])
    Factory(:classification, product: class_1.product, country: Factory(:country, iso_code: 'CA'), tariff_records: [Factory(:tariff_record, hts_1: "bar" )])
  end

  describe "process" do
    before :each do
      company = with_customs_management_id(Factory(:importer), "EDDIE")
      @u = Factory(:user, email: "nigel@tufnel.net")

      @row_0 = ['ExitDocID', 'TxnCode', 'ProductNum', 'StatusCode', 'HtsNum', 'AdValoremRate', 'Value', 'ExitPrintDate']
      @row_1 = ['316-1548927-0', 'ANPC', '022-3724-800-0000', 'N', '8513104000', '0.035', '2.98', '2016-03-30 00:00:00']
      @row_2 = ['316-1548927-0', 'ANPC', '023-2301-105-0000', 'N', '9404308000', '0.09', '27.16', '2016-03-30 00:00:00']
      @row_3 = ['316-1548927-0', 'ANPC',  '009-0282-139-0030', 'N', '6104622011', '0.149', '14.35', '2016-03-30 00:00:00']

      @cf = double("Custom File")
      allow(@cf).to receive(:path).and_return "path/to/audit_file.xls"
      allow(@cf).to receive(:attached).and_return double("audit file")
      allow(@cf).to receive(:attached_file_name).and_return "audit_file.xls"
      allow(@cf).to receive(:id).and_return 1

      @handler = described_class.new @cf
    end

    it "emails user audit spreadsheet" do
      create_data
      expect(@handler).to receive(:foreach).with(@cf).and_return [@row_0, @row_1, @row_2, @row_3]
      @handler.process @u

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq [ "nigel@tufnel.net" ]
      expect(mail.subject).to eq "Eddie Bauer 7501 Audit"
      expect(mail.body.raw_source).to include "Report attached."
      expect(mail.attachments.size).to eq(1)
    end

    it "produces correct spreadsheet" do
      create_data
      expect(@handler).to receive(:foreach).with(@cf).and_return [@row_0, @row_1, @row_2, @row_3]
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
      allow(@handler).to receive(:create_and_send_report!).and_raise "Disaster!"
      @handler.process @u
      mail = ActionMailer::Base.deliveries.pop

      expect(mail.to).to eq [ "nigel@tufnel.net" ]
      expect(mail.subject).to eq "Eddie Bauer 7501 Audit Completed With Errors"
      expect(mail.body.raw_source).to include "Disaster!"
      expect(mail.attachments.size).to eq(0)

      expect(ErrorLogEntry.last.additional_messages_json).to match(/Failed to process 7501/)
    end

    it "sends error email if file with unaccepted format is submitted"  do
      allow(@cf).to receive(:path).and_return "path/to/audit_file.foo"
      @handler.process @u
      mail = ActionMailer::Base.deliveries.pop

      expect(mail.body.raw_source).to include "No CI Upload processor exists for .foo file types."
    end
  end

end
