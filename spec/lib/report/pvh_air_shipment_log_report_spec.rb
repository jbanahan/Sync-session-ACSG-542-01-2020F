describe OpenChain::Report::PvhAirShipmentLogReport do

  describe "run_report" do

    # Server config
    let!(:ms) {
      ms = stub_master_setup
      allow(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return true
      allow(ms).to receive(:request_host).and_return "localhost"
    }

    # Container test data
    let(:port) { Factory(:port) }
    let(:container1) { Factory(:container, container_number: "CONT1", quantity: 5, entry: Factory(:entry, broker_reference: "123", customer_number: "PVH", master_bills_of_lading: "ABCD", house_bills_of_lading: "EFGH", transport_mode_code: 40, arrival_date: Time.zone.now, worksheet_date: Time.zone.parse("2014-10-01 00:00"), entry_port_code: port.schedule_d_code, store_names: "A\n B", customer_references: "A123 10/1/14\n1234\nB123")) }
    let(:entry) { container1.entry }
    let!(:container2) { Factory(:container, container_number: "CONT1", quantity: 10, entry: entry) }

    let(:temp) { described_class.new.run_report Hash.new }
    let(:wb) { Spreadsheet.open temp.path }
    let(:sheet) { wb.worksheets.first }

    # Ensure the temporary file is closed after each expectation
    after :each do
      temp.close! if temp
    end

    it "runs report with basic information" do
      expect(sheet.row(0)).to eq ["Broker Reference", "Entry Number", "Master Bills", "House Bills", "Carrier Code", "Vessel/Airline", "Country Export Codes", "Customer References", "Worksheet Date", "Departments", "Total Packages", "Container Numbers", "ETA Date", "Arrival Date", "Port of Entry Name", "Docs Received Date", "First Summary Sent", "First Release Date", "Available Date", "First DO Date", "Trucker", "Comments", "Links"]
      # I'm really just checking a couple key columns to make sure they contain the expected info.
      expect(sheet.row(1)[0]).to eq entry.broker_reference
      expect(sheet.row(1)[7]).to eq "A123, B123"
      # Verifies we're changing time (and date) from UTC to Eastern
      expect(sheet.row(1)[8]).to eq Date.new(2014, 9, 30)
      expect(sheet.row(1)[9]).to eq "A, B"
      expect(sheet.row(1)[10]).to eq container1.quantity
      expect(sheet.row(1)[11]).to eq container1.container_number
      expect(sheet.row(1)[14]).to eq port.name
      expect(sheet.row(1)[22]).to eq "Web View"

      expect(sheet.row(2)[0]).to eq entry.broker_reference
      expect(sheet.row(2)[10]).to eq container2.quantity
      expect(sheet.row(2)[11]).to eq container2.container_number

      expect(sheet.row(3)).to eq []
    end

    it "runs report with given start date" do
      entry.update_attributes! arrival_date: (Time.zone.now - 20.days)
      temp = described_class.new.run_report 'start_date' => (Time.zone.now - 22.days).strftime("%Y-%m-%d")

      wb = Spreadsheet.open temp.path
      sheet = wb.worksheets.first
      expect(sheet.row(1)[0]).to eq entry.broker_reference
    end

    it "runs report with given end date" do
      entry.update_attributes! arrival_date: (Time.zone.now - 2.days)
      temp = described_class.new.run_report 'end_date' => (Time.zone.now).strftime("%Y-%m-%d")

      wb = Spreadsheet.open temp.path
      sheet = wb.worksheets.first
      expect(sheet.row(1)[0]).to eq entry.broker_reference
    end
  end

  describe "run_schedulable" do
    let(:temp) { Tempfile.new "file" }

    # Flush the temp file before every expectation
    before :each do
      temp << "Test"
      temp.flush
    end

    after :each do
      temp.close! unless temp.closed?
    end

    it "runs report and emails it to specified people" do
      expect_any_instance_of(described_class).to receive(:run_report).with('email_to' => ['me@there.com']).and_return temp

      described_class.run_schedulable 'email_to' => ['me@there.com']

      m = OpenMailer.deliveries.first
      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "[VFI Track] PVH Air Shipment Log"
      expect(m.body.raw_source).to include "Attached is the PVH Air Shipment Log Report for "
      attachment = m.attachments.first
      expect(attachment).not_to be_nil
      expect(attachment.read).to eq "Test"
      expect(temp).to be_closed
    end

    it "raises an error if no emails are specified" do
      expect {described_class.run_schedulable Hash.new}.to raise_error "Scheduled instances of the PVH Air Shipment Report must include an email_to setting with an array of email addresses."
    end
  end

  describe "permission?" do
    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return true
      ms
    }

    context "set with custom feature WWW VFI Track Reports" do

      it "allows permission for master users with custom_feature WWW VFI Track Reports set" do
        user = Factory(:master_user)
        expect(user).to receive(:view_entries?).and_return true
        expect(described_class.permission? user).to eq true
      end

      it "denies permission for users that can't view entries" do
        user = Factory(:master_user)
        expect(user).to receive(:view_entries?).and_return false
        expect(described_class.permission? user).to eq false
      end

      context "with pvh company" do
        let (:user) { 
          user = Factory(:user) 
          allow(user).to receive(:view_entries?).and_return true
          user
        }

        let! (:pvh) { Factory(:company, importer: true, system_code: "PVH") }

        it "denies users that are not linked to pvh" do
          expect(described_class.permission? user).to eq false
        end

        it "allows to pvh users" do 
          user.company = pvh
          user.save!

          expect(described_class.permission? user).to eq true
        end

        it "allows to users linked to pvh" do
          company = Factory(:importer)
          company.linked_companies << pvh
          user.company = company
          user.save! 
          
          expect(described_class.permission? user).to eq true
        end
      end
    end

    it "denies permission for non-WWW VFI Track Reports instance" do
      # Improper server setup
      allow(master_setup).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return false
      user = Factory(:master_user)
      allow(user).to receive(:view_entries?).and_return true
      expect(described_class.permission? user).to eq false
    end
  end
end
