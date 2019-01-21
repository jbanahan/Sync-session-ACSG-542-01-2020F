require 'spec_helper'

describe OpenChain::SpecialTariffCrossReferenceHandler do
  describe 'download handling' do
    let(:user) { Factory(:user, admin: true) }

    subject { described_class.new }

    it 'sends the csv file' do
      Timecop.freeze(Time.zone.now) do
        subject.send_tariffs user

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq [user.email]
        expect(mail.subject).to eq "Special Tariffs Current as of #{Time.zone.now.strftime("%m/%d/%Y")}"
        expect(mail.body).to include "Attached is the list of special tariffs for #{Time.zone.now.strftime("%m/%d/%Y")}"
        expect(mail.attachments).to_not be_empty
      end
    end
  end

  describe 'upload handling' do
    describe 'import' do
      let(:user) { Factory(:user, admin: true)}
      let(:cf) { double "CustomFile" }
      let(:row_0) { [ 'HTS Number', 'Special HTS Number', 'Origin Country ISO', 'Import Country ISO',
                        'Effective Date Start', 'Effective Date End', 'Priority', 'Special Tariff Type',
                        'Suppress From Feeds'] }
      let(:row_1) { [ '1234567890', '0987654321', 'CA', 'US', '2018-12-11', '2019-12-11', '1', '301', 't' ]}
      let(:row_2) { [ '', '0987654321', 'CA', 'US', '2018-12-11', '2019-12-11', '1', '301', 't' ]}
      let(:handler) { described_class.new(cf) }

      before do
        allow(cf).to receive(:id).and_return 1
      end

      it 'sets a user error message if a row is missing an HTS' do
        allow(cf).to receive(:attached_file_name).and_return 'stcr_upload.xls'
        expect(handler).to receive(:foreach).with(cf, {skip_blank_lines: true, skip_headers: true}).and_yield(row_2, 1)

        handler.process user, {}

        msg = user.messages.first
        expect(msg.subject).to eq 'File Processing Complete With Errors'
        expect(msg.body).to eq 'Special Tariff Cross Reference uploader generated errors on the following row(s): 1. Missing or invalid HTS'
      end

      it 'updates existing records' do
        allow(cf).to receive(:attached_file_name).and_return 'stcr_upload.xls'
        expect(handler).to receive(:foreach).with(cf, {skip_blank_lines: true, skip_headers: true}).and_yield(row_1, 1)
        stcr = SpecialTariffCrossReference.create!(hts_number: '1234567890')
        expect(stcr.special_hts_number).to be_nil

        handler.process user, {}
        stcr.reload
        expect(stcr.special_hts_number).to eql('0987654321')
      end

      it 'uploads records, messages users' do
        allow(cf).to receive(:attached_file_name).and_return 'stcr_upload.xls'
        expect(handler).to receive(:foreach).with(cf, {skip_blank_lines: true, skip_headers: true}).and_yield(row_1, 1)

        handler.process user, {}
        expect(SpecialTariffCrossReference.first.hts_number).to eql("1234567890")
        msg = user.messages.first
        expect(msg.subject).to eq "File Processing Complete"
        expect(msg.body).to eq "Special Tariff Cross Reference upload for file stcr_upload.xls is complete"
      end

      it 'raises exception for file-type other than csv, xls, xlsx' do
        allow(cf).to receive(:attached_file_name).and_return 'stcr_upload.txt'
        handler.process user, {}
        msg = user.messages.first
        expect(msg.subject).to eq "File Processing Complete With Errors"
        expect(msg.body).to eq "Unable to process file stcr_upload.txt due to the following error:<br>Only XLS, XLSX, and CSV files are accepted."
      end
    end
  end
end

