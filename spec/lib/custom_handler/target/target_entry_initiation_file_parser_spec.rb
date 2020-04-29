describe OpenChain::CustomHandler::Target::TargetEntryInitiationFileParser do

  describe "process_file" do
    let (:file_data) { IO.read('spec/fixtures/files/target_entry_initiation.txt') }

    def expect_date(s, code, date)
      shipment_date = s.dates.find {|d| d.code == code}
      expect(shipment_date).not_to be_nil, -> { "expected to find #{code} date in shipment."}
      expect(shipment_date.date).to eq date
    end

    it "processes an entry initiation file" do
      now = Time.zone.now
      shipments = nil
      Timecop.freeze(now) { shipments = subject.process_file file_data }

      expect(shipments.length).to eq 1

      s = shipments.first
      expect(s.customer).to eq "TARGET"
      expect(s.customs_ship_mode).to eq 11
      expect(s.vessel).to eq "YM UNISON"
      expect(s.voyage).to eq "084E-"
      expect(s.lading_port).to eq "55206"
      expect(s.unlading_port).to eq "3002"
      expect(s.entry_port).to eq "3002"
      expect_date(s, :export_date, Date.new(2019, 12, 3))
      expect_date(s, :est_arrival_date, Date.new(2019, 12, 19))
      expect_date(s, :arrival_date, Date.new(2019, 12, 19))
      expect_date(s, :import_date, Date.new(2019, 12, 19))
      # Charges should be moved down to the invoice
      expect(s.charges).to be_nil
      expect(s.carrier).to eq "YMLU"
      expect(s.weight_kg).to eq 13271
      expect(s.recon_value_flag).to eq true
      expect(s.country_of_export).to be_nil

      expect(s.bills_of_lading.length).to eq 1
      bol = s.bills_of_lading.first
      expect(bol.master_bill).to eq "YMLUW490360331"
      # Because the master bill is repeated...we don't expect a house bill to be present
      expect(bol.house_bill).to be_nil

      expect(s.containers.length).to eq 2
      expect(s.containers.first.container_number).to eq "TGBU6451898"
      expect(s.containers.second.container_number).to eq "YMLU8645801"

      expect(s.invoices.length).to eq 1
      i = s.invoices.first

      expect(i.invoice_number).to eq "YMLUW490360331"
      expect(i.charges).to eq 1.234
      expect(i.invoice_date).to eq now.in_time_zone("America/New_York").to_date

      expect(i.invoice_lines.length).to eq 2

      l = i.invoice_lines.first
      expect(l.po_number).to eq "0032-2663814"
      expect(l.part_number).to eq "032020738-106879518"
      expect(l.cartons).to eq 101
      expect(l.pieces).to eq 101
      expect(l.unit_price).to eq BigDecimal("119.545")
      expect(l.foreign_value).to eq BigDecimal("12074.05")
      expect(l.country_of_origin).to eq "VN"
      expect(l.country_of_export).to eq "VN"
      expect(l.container_number).to eq "TGBU6451898"

      l = i.invoice_lines.second
      expect(l.po_number).to eq "0032-2663814"
      expect(l.part_number).to eq "032020739-106879518"
      expect(l.cartons).to eq 300
      expect(l.pieces).to eq 300
      expect(l.unit_price).to eq BigDecimal("81.744")
      expect(l.foreign_value).to eq BigDecimal("24523.20")
      expect(l.country_of_origin).to eq "VN"
      expect(l.country_of_export).to eq "VN"
      expect(l.container_number).to eq "YMLU8645801"
    end
  end

  describe "process_01" do
    let (:line) { "0112YMLUW490360331                YMLUW490360331                11YM UNISON                          084E-VN 5520630022019120320191219        1.234YMLU000013270.520001" }
    let (:shipment) {
      s = described_class::CiLoadEntry.new
      s.bills_of_lading = []
      s.dates = []
      s
    }

    it "parses house bill information for ocean if different than master" do
      line.sub!("YMLUW490360331", "MAEUXXXXXXXXXX")
      subject.process_01 shipment, line
      bol = shipment.bills_of_lading.first
      expect(bol.master_bill).to eq "YMLUW490360331"
      expect(bol.house_bill).to eq "MAEUXXXXXXXXXX"
    end

    it "parses air primary bill into house bill for air" do
      line[64, 2] = "40"
      subject.process_01 shipment, line
      bol = shipment.bills_of_lading.first
      expect(bol.master_bill).to be_nil
      expect(bol.house_bill).to eq "YMLUW490360331"
    end

    it "parses air master air waybill for air if numbers are different" do
      line[64, 2] = "40"
      line.sub!("YMLUW490360331", "MAEUXXXXXXXXXX")

      subject.process_01 shipment, line

      bol = shipment.bills_of_lading.first
      expect(bol.master_bill).to eq "YMLUW490360331"
      expect(bol.house_bill).to eq "MAEUXXXXXXXXXX"
    end

    it "leaves recon flag nil if not Y" do
      line[164, 3] = "000"
      subject.process_01 shipment, line
      expect(shipment.recon_value_flag).to be_nil
    end
  end

  describe "process_02" do
    let (:shipment) {
      s = described_class::CiLoadEntry.new
      s.containers = []
      s
    }
    let (:line) { "0212YMLUW490360331                TGBU6451898"}

    it "does nothing if container is blank" do
      line[34, 15] = "               "
      subject.process_02 shipment, line
      expect(shipment.containers.length).to eq 0
    end
  end

  describe "process_04" do
    let (:shipment) {
      s = described_class::CiLoadEntry.new
      s.invoices = []
      i = described_class::CiLoadInvoice.new
      i.invoice_lines = []
      s
    }
    let (:line) { "0412YMLUW490360331                0032-2663814106879518032020738101      1        101      000000119.545VN          0.0000.000TGBU6451898"}

    it "doesn't calculate line value if unit price is zero" do
      line[92, 13] = "0.00         "
      i = described_class::CiLoadInvoiceLine.new
      subject.process_04 shipment, shipment.invoices.first, i, line

      expect(i.foreign_value).to be_nil
    end

    it "doesn't calculate line value if piece count is zero" do
      line[82, 9] = "0        "
      i = described_class::CiLoadInvoiceLine.new
      subject.process_04 shipment, shipment.invoices.first, i, line

      expect(i.foreign_value).to be_nil
    end
  end

  describe "add_special_tariffs?" do
    it "returns false" do
      expect(subject.add_special_tariffs? nil, nil, nil).to eq false
    end
  end
end