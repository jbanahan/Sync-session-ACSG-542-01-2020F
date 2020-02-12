describe OpenChain::CustomHandler::DeliveryOrderSpreadsheetGenerator do

  describe "get_generator" do
    subject { described_class }

    it "returns default generator for random customers" do
      expect(described_class.get_generator "RNDM").to be_a(OpenChain::CustomHandler::DeliveryOrderSpreadsheetGenerator)
    end

    it "returns pvh specific generator" do
      expect(described_class.get_generator "PVH").to be_a(OpenChain::CustomHandler::Pvh::PvhDeliveryOrderSpreadsheetGenerator)
    end
  end

  describe "generate_delivery_order_data" do
    let (:lading_port) { Port.new name: "lading_port"}
    let (:unlading_port) { Port.new name: "unlading_port"}
    let (:entry) {
      Entry.new broker_reference: "reference", vessel: "vessel", voyage: "voy", location_of_goods_description: "loc", carrier_code: "CODE", master_bills_of_lading: "ABC", arrival_date: DateTime.new(2016, 2, 16, 12, 00), total_packages: 20, total_packages_uom: 'CTNS', gross_weight: 10, lading_port: lading_port, unlading_port: unlading_port
    }

    it "generates delivery order data" do
      data = subject.generate_delivery_order_data entry
      expect(data.length).to eq 1

      d = data.first
      expect(d.date).to eq Time.zone.now.in_time_zone("America/New_York").to_date
      expect(d.vfi_reference).to eq "reference"
      expect(d.vessel_voyage).to eq "vessel Vvoy"
      expect(d.freight_location).to eq "loc"
      expect(d.port_of_origin).to eq "lading_port"
      expect(d.importing_carrier).to eq "CODE"
      expect(d.bill_of_lading).to eq "ABC"
      expect(d.arrival_date).to eq Date.new(2016, 2, 16)
      expect(d.no_cartons).to eq "20 CTNS"
      expect(d.weight).to eq "22 LBS"
      expect(d.body).to eq ["PORT OF DISCHARGE: unlading_port"]
      expect(d.tab_title).to eq "reference"
    end

    it "generates different message for multiple bills of lading" do
      entry.master_bills_of_lading = "ABC\nDEF"
      data = subject.generate_delivery_order_data(entry).first
      expect(data.bill_of_lading).to eq "MULTIPLE - SEE BELOW"
    end
  end

  describe "generate_delivery_order_spreadsheets" do
    let (:delivery_order) {
      d = OpenChain::CustomHandler::DeliveryOrderSpreadsheetGenerator::DeliveryOrderData.new
      d.date = Date.new(2016, 2, 16)
      d.vfi_reference = "REF"
      d.instruction_provided_by = ["Customer", "Name"]
      d.vessel_voyage = "VES VOY"
      d.importing_carrier = "CAR"
      d.freight_location = "LOC"
      d.port_of_origin = "ORIGIN"
      d.bill_of_lading = "LAD"
      d.arrival_date = Date.new(2016, 2, 17)
      d.last_free_day = Date.new(2016, 2, 18)
      d.do_issued_to = "INLAND CARRIER"
      d.for_delivery_to = ["DELIVER", "TO", "ADDRESS"]
      d.special_instructions = ["SOME", "INSTRUCTIONS"]
      d.no_cartons = "1 CTN"
      d.weight = "10 LBS"
      d.body = ["BODY"]
      d.tab_title = "Title"

      d
    }

    def tab_expectations sub, d, index
      expect(sub).to receive(:clone_template_page).with(d.tab_title).and_return index
      expect(sub).to receive(:set_cell).with(index, "K", 6, d.date)
      expect(sub).to receive(:set_cell).with(index, "M", 6, d.vfi_reference)
      expect(sub).to receive(:set_multiple_vertical_cells).with(index, "F", 7, d.instruction_provided_by, 4)
      expect(sub).to receive(:set_cell).with(index, "B", 10, d.vessel_voyage)
      expect(sub).to receive(:set_cell).with(index, "B", 12, d.importing_carrier)
      expect(sub).to receive(:set_cell).with(index, "F", 12, d.freight_location)
      expect(sub).to receive(:set_cell).with(index, "L", 12, d.port_of_origin)
      expect(sub).to receive(:set_cell).with(index, "B", 14, d.bill_of_lading)
      expect(sub).to receive(:set_cell).with(index, "F", 14, d.arrival_date)
      expect(sub).to receive(:set_cell).with(index, "H", 14, d.last_free_day)
      expect(sub).to receive(:set_cell).with(index, "J", 14, d.do_issued_to)
      expect(sub).to receive(:set_multiple_vertical_cells).with(index, "B", 16, d.for_delivery_to, 5)
      expect(sub).to receive(:set_multiple_vertical_cells).with(index, "I", 16, d.special_instructions, 5)
      expect(sub).to receive(:set_cell).with(index, "B", 22, d.no_cartons)
      expect(sub).to receive(:set_cell).with(index, "M", 22, d.weight)
      expect(sub).to receive(:set_multiple_vertical_cells).with(index, "B", 23, d.body, 1000)
    end

    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:uuid).and_return 'test-uuid'
      ms
    }

    it "generates spreadsheet data using xl client" do
      xl_client = double("OpenChain::XLClient")
      expect(xl_client).to receive(:delete_sheet).with 0
      expect(xl_client).to receive(:save).with "#{master_setup.uuid}/delivery_orders/REF.xlsx", bucket: "chainio-temp"
      allow(subject).to receive(:xl).and_return xl_client

      tab_expectations subject, delivery_order, 1

      files = subject.generate_delivery_order_spreadsheets delivery_order
      expect(files.length).to eq 1
      expect(files.first).to eq({bucket: 'chainio-temp', path: "#{master_setup.uuid}/delivery_orders/REF.xlsx"})
    end

    it "handles no delivery order files" do
      files = subject.generate_delivery_order_spreadsheets []
      expect(files).to be_empty
    end
  end

  describe "send_delivery_order" do
    let (:user) { User.new email: "me@there.com"}
    let (:temp1) {
      @tf = Tempfile.new("file")
      @tf << "Content" # We need to put content in here, otherwise the mailer strips blank files from the emails
      @tf.flush
      Attachment.add_original_filename_method(@tf, "file.xlsx")
      @tf
    }
    let (:temp2) {
      @tf2 = Tempfile.new("file")
      @tf2 << "Content" # We need to put content in here, otherwise the mailer strips blank files from the emails
      @tf2.flush
      Attachment.add_original_filename_method(@tf2, "file-b.xls")
      @tf2
    }

    after :each do
      @tf.close! if defined?(@tf) && !@tf.closed?
      @tf2.close! if defined?(@tf2) && !@tf2.closed?
    end

    it "emails delivery order files to user" do
      files = [{bucket: "bucket-a", path: "path/to/file.xlsx"}, {bucket: "bucket-b", path: "path/to/file-b.xls"}]
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket-a", "path/to/file.xlsx", original_filename: "file.xlsx").and_return temp1
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket-b", "path/to/file-b.xls", original_filename: "file-b.xls").and_return temp2

      subject.send_delivery_order user, "12345", files

      expect(ActionMailer::Base.deliveries.size).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "Delivery Order for File # 12345"
      expect(m.body.raw_source).to include "Attached are the Delivery Order files for File # 12345."
      expect(m.attachments["file.xlsx"]).not_to be_nil
      expect(m.attachments["file-b.xls"]).not_to be_nil
    end

    it "sends different message to user if there are no delivery orders generated" do
      subject.send_delivery_order user, "12345", []

      expect(ActionMailer::Base.deliveries.size).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "Delivery Order for File # 12345"
      expect(m.body.raw_source).to include "No Delivery Orders were generated for File # 12345."
    end
  end

  describe "generate_and_send_delivery_orders" do
    let (:entry) { Factory(:entry, broker_reference: "12345") }
    let (:user) { Factory(:user) }
    let (:temp1) {
      @tf = Tempfile.new("file")
      @tf << "Content" # We need to put content in here, otherwise the mailer strips blank files from the emails
      @tf.flush
      Attachment.add_original_filename_method(@tf, "file.xlsx")
      @tf
    }

    after :each do
      @tf.close! if defined?(@tf) && !@tf.closed?
    end

    it "generates and sends data" do
      # mock out the call to actually write the files and download them from s3
      expect_any_instance_of(described_class).to receive(:generate_delivery_order_spreadsheets).and_return [{bucket: "bucket", path: "path/to/file.xls"}]
      expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path/to/file.xls", original_filename: "file.xls").and_return temp1

      described_class.generate_and_send_delivery_orders user.id, entry.id

      # Ultimately, just make sure the email was sent
      expect(ActionMailer::Base.deliveries.size).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq [user.email]
      expect(m.subject).to eq "Delivery Order for File # 12345"
    end
  end
end
