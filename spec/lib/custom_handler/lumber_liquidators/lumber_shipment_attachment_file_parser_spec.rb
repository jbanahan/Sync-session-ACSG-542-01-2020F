describe OpenChain::CustomHandler::LumberLiquidators::LumberShipmentAttachmentFileParser do

  describe "process_from_s3" do
    subject { described_class }

    it "uses s3 to download file" do
      tempfile = instance_double(Tempfile)
      expect(subject).to receive(:retrieve_file_data).with('bucket', 'path', {}).and_return tempfile
      expect_any_instance_of(described_class).to receive(:process_file).with tempfile, "bucket", "path", 1
      # This make sure the post processing is invoked too
      expect(tempfile).to receive(:closed?).and_return false
      expect(tempfile).to receive(:close!)

      subject.process_from_s3 'bucket', 'path'
    end

    it "handles a reprocess, where attempt count passed in options" do
      tempfile = instance_double(Tempfile)
      attempt_count = rand(95)
      expect(subject).to receive(:retrieve_file_data).with('bucket', 'path', {attempt_count: attempt_count}).and_return tempfile
      expect_any_instance_of(described_class).to receive(:process_file).with tempfile, "bucket", "path", attempt_count
      expect(tempfile).to receive(:closed?).and_return false
      expect(tempfile).to receive(:close!)

      described_class.process_from_s3 'bucket', 'path', {attempt_count:attempt_count}
    end
  end

  describe "process_file" do
    let (:zip_path) { "spec/fixtures/files/V2OOLU2100046990.zip"}
    let (:file) { File.open(zip_path, "rb")}
    let (:inbound_file) { InboundFile.new }

    before :each do 
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "processes file with matching shipment" do
      shp = Factory(:shipment, master_bill_of_lading:'OU812', reference: '555')

      subject.process_file file, 'A', 'V2OU812.12345.zip', 1

      expect(shp.attachments.length).to eq(1)
      expect(shp.attachments[0].attached_file_name).to eq('V2OU812.pdf')
      expect(shp.attachments[0].attachment_type).to eq('ODS-Forwarder Ocean Document Set')
      expect(inbound_file).to have_identifier(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER, "555")
    end

    it "processes file with matching shipment and existing ODS attachment with newer version" do
      shp = Factory(:shipment, master_bill_of_lading:'OOLU2100046990', reference: '555')
      ods_attach = shp.attachments.create!(attachment_type:'ODS-Forwarder Ocean Document Set', attached_file_name:'V3OOLU2100046990.pdf')

      subject.process_file file, 'A', 'V2OOLU2100046990.12345.zip', 1

      expect(shp.attachments.length).to eq(1)
      # Same record.
      expect(shp.attachments[0]).to eq(ods_attach)
      expect(shp.attachments[0].attached_file_name).to eq('V3OOLU2100046990.pdf')
      expect(shp.attachments[0].attachment_type).to eq('ODS-Forwarder Ocean Document Set')
    end

    it "processes file with matching shipment and existing ODS attachment with same version" do
      shp = Factory(:shipment, master_bill_of_lading:'OOLU2100046990', reference: '555')
      ods_attach = shp.attachments.create!(attachment_type:'ODS-Forwarder Ocean Document Set', attached_file_name:'V2OOLU2100046990.pdf')

      subject.process_file file, 'A', 'V2OOLU2100046990.12345.zip', 1

      expect(shp.attachments.length).to eq(1)
      # Same record.
      expect(shp.attachments[0]).to eq(ods_attach)
      expect(shp.attachments[0].attached_file_name).to eq('V2OOLU2100046990.pdf')
      expect(shp.attachments[0].attachment_type).to eq('ODS-Forwarder Ocean Document Set')
    end

    it "processes file with matching shipment and existing ODS attachment with older version" do
      shp = Factory(:shipment, master_bill_of_lading:'OOLU2100046990', reference: '555')
      ods_attach = shp.attachments.create!(attachment_type:'ODS-Forwarder Ocean Document Set', attached_file_name:'V1OOLU2100046990.pdf')

      subject.process_file file, 'A', 'V2OOLU2100046990.12345.zip', 1

      shp.reload
      expect(shp.attachments.length).to eq(1)
      # Not same record.
      expect(shp.attachments[0]).to_not eq(ods_attach)
      expect(shp.attachments[0].attached_file_name).to eq('V2OOLU2100046990.pdf')
      expect(shp.attachments[0].attachment_type).to eq('ODS-Forwarder Ocean Document Set')
    end

    it "processes file with no matching shipment and has not exceeded max run count" do
      # Any number 95 or less is cool.
      attempt_count = rand(95)

      now = Time.zone.now
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberShipmentAttachmentFileParser).to receive(:delay).with(run_at: now + 1.hour).and_return OpenChain::CustomHandler::LumberLiquidators::LumberShipmentAttachmentFileParser
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberShipmentAttachmentFileParser).to receive(:process_from_s3).with('A', 'V2OOLU2100046990.12345.zip', {attempt_count:(attempt_count + 1)})

      Timecop.freeze(now) { subject.process_file(file, 'A', 'V2OOLU2100046990.12345.zip', attempt_count) }
    end

    it "processes file with no matching shipment and max run count has been exceeded" do
      subject.process_file file, 'A', 'V2OOLU2100046990.12345.zip', 96

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['LL-US@vandegriftinc.com']
      expect(mail.subject).to eq 'Allport Missing Shipment: OOLU2100046990'
      expect(mail.body).to include ERB::Util.html_escape("VFI Track has tried for 4 days to find a shipment matching master bill 'OOLU2100046990' without success.  No further attempts will be made.  Allport document attachments (ODS) are available for this shipment.  VFI operations will be required to manually upload vendor docs (VDS) and shipment docs (ODS) manually.")
      expect(mail.attachments.length).to eq(1)
      expect(mail.attachments[0].filename).to eq('V2OOLU2100046990.pdf')
    end

    it "processes file containing no PDF" do
      user = Factory(:user, first_name:"Nigel", last_name:"Tufnel", company:Factory(:company, name:"ACME"))
      Factory(:mailing_list, name:'Testing', system_code:'ODSNotifications', user:user, email_addresses:"a@b.com,c@d.com, e@f.com")

      unzipped_zip = instance_double(Zip::File)
      expect(Zip::File).to receive(:open).with(zip_path).and_yield(unzipped_zip)
      txt_file = instance_double(Zip::Entry)
      expect(unzipped_zip).to receive(:each).and_yield(txt_file)
      expect(txt_file).to receive(:name).and_return('some_file.txt')

      subject.process_file file, 'A', 'V2OOLU2100046990.12345.zip', 1

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['a@b.com','c@d.com','e@f.com']
      expect(mail.subject).to eq 'Allport ODS docs not in zip file'
      expect(mail.body).to include ERB::Util.html_escape("The attached zip file for master bill 'OOLU2100046990', received on #{Time.now.strftime("%d/%m/%Y")}, is invalid or does not contain a PDF file.  Contact Lumber and Allport for resolution.")
      expect(mail.attachments.length).to eq(1)
      expect(mail.attachments[0].filename).to eq('V2OOLU2100046990.zip')
      expect(mail.reply_to).to eq ['ll-support@vandegriftinc.com']
    end

    it "raises exception when mailing list not set up" do
      unzipped_zip = instance_double(Zip::File)
      expect(Zip::File).to receive(:open).with(zip_path).and_yield(unzipped_zip)
      txt_file = instance_double(Zip::Entry)
      expect(unzipped_zip).to receive(:each).and_yield(txt_file)
      expect(txt_file).to receive(:name).and_return('some_file.txt')

      expect { subject.process_file file, 'A', 'V2OOLU2100046990.12345.zip', 1 }.to raise_error("Allport ODS Notifications mailing list not configured.")

      expect(ActionMailer::Base.deliveries.size).to eq 0
    end

    it "processes invalid zip file" do
      user = Factory(:user, first_name:"Nigel", last_name:"Tufnel", company:Factory(:company, name:"ACME"))
      Factory(:mailing_list, name:'Testing', system_code:'ODSNotifications', user:user, email_addresses:"a@b.com,c@d.com, e@f.com")

      # This is an invalid zip: it's a PDF renamed as a zip.
      file = File.open('spec/fixtures/files/V3OOLU2100046991.zip', 'rb')

      subject.process_file file, 'A', 'V2OOLU2100046991.12345.zip', 1

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['a@b.com','c@d.com','e@f.com']
      expect(mail.subject).to eq 'Allport ODS docs not in zip file'
      expect(mail.body).to include ERB::Util.html_escape("The attached zip file for master bill 'OOLU2100046991', received on #{Time.now.strftime("%d/%m/%Y")}, is invalid or does not contain a PDF file.  Contact Lumber and Allport for resolution.")
      expect(mail.attachments.length).to eq(1)
      expect(mail.attachments[0].filename).to eq('V3OOLU2100046991.zip')
      # This test may fail if the error message for an invalid zip changes, but that's probably not going to happen
      expect(inbound_file).to have_reject_message("Zip end of central directory signature not found")
    end

  end

end