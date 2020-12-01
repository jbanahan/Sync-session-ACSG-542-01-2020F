describe OpenChain::CustomHandler::BookingEmailSender do

  subject { described_class }

  let (:order_line) {
    order_line = FactoryBot(:order_line, order: FactoryBot(:order, vendor: FactoryBot(:company, name: "Vendor")))
    o = order_line.order
    o.order_from_address = FactoryBot(:address, company: o.vendor)
    o.save!

    order_line
  }

  let (:shipment_line) {
    shipment_line = FactoryBot(:shipment_line, product: order_line.product, shipment: FactoryBot(:shipment, forwarder: FactoryBot(:company, name: "Forwarder"), reference: "reference", first_port_receipt: FactoryBot(:port, name: "Port Name", unlocode: "AAAAA")))
    shipment_line.linked_order_line_id = order_line.id
    shipment_line.save!

    shipment_line
  }
  let (:shipment) { shipment_line.shipment }

  let (:shipment_attachment) { shipment.attachments.create! attached_file_name: "file.txt"}

  let (:user) { FactoryBot(:user) }
  let (:origin_docs) { FactoryBot(:user, company: shipment.forwarder, username: "OriginDocs", email: "me@there.com")}


  describe "send_email" do
    it "generates booking spreadsheet, zips all attachments associated with shipment and emails them" do
      shipment_attachment
      origin_docs

      # Just yield any old file we have, the class under test just emails the file, so it doesn't really matter....just check that the file goes out
      expect(OpenChain::CustomHandler::BookingSpreadsheetGenerator).to receive(:generate).with(user, shipment, [shipment_line]).and_yield File.open('spec/fixtures/files/Standard Booking Form.xlsx', "rb")
      expect(subject).to receive(:zip_attachments) do |filename, attachments|
        expect(filename).to eq "reference.zip"
        expect(attachments.length).to eq 1
        expect(attachments.first).to eq shipment_attachment
      end.and_yield File.open("spec/fixtures/files/test_sheets.zip", "rb")

      subject.send_email("Message Type", user, shipment, [shipment_line])

      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eq ["me@there.com"]
      expect(mail.subject).to eq "Message Type - reference - Port Name - Vendor"
      expect(mail.attachments.size).to eq 2
      expect(mail.attachments["test_sheets.zip"]).not_to be_nil
      expect(mail.attachments["Standard Booking Form.xlsx"]).not_to be_nil
    end

    it "handles if no attachments are there" do
      origin_docs
      expect(OpenChain::CustomHandler::BookingSpreadsheetGenerator).to receive(:generate).with(user, shipment, [shipment_line]).and_yield File.open('spec/fixtures/files/Standard Booking Form.xlsx', "rb")

      subject.send_email("Message Type", user, shipment, [shipment_line])
      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries.first
      expect(mail.attachments.size).to eq 1
      expect(mail.attachments["Standard Booking Form.xlsx"]).not_to be_nil
    end

    it "raises an error if no origin docs user is present" do
      expect {subject.send_email("Message Type", user, shipment, [shipment_line]) }.to raise_error "Forwarder company Forwarder must have a user with a username 'OriginDocs' added to it with a valid email address."
    end

    it "raises an error if origin docs user's email is missing" do
      origin_docs.update_attributes! email: ""
      expect {subject.send_email("Message Type", user, shipment, [shipment_line]) }.to raise_error "Forwarder company Forwarder must have a user with a username 'OriginDocs' added to it with a valid email address."
    end

    it "raises an error if shipment is missing a forwarder" do
      shipment.forwarder = nil
      shipment.save

      expect {subject.send_email("Message Type", user, shipment, [shipment_line]) }.to raise_error "Shipment reference does not have a forwarder associated with it."
    end
  end
end