describe OpenChain::CustomHandler::Pvh::PvhCanadaBillingInvoiceFileGenerator do

  let! (:pvh) {
    Factory(:importer, system_code: "PVH")
  }

  let (:product) {
    Factory(:product, importer: pvh, unique_identifier: "PVH-PART")
  }

  let (:order) {
    order = Factory(:order, order_number: "ORDER", customer_order_number: "ORDER", importer_id: pvh.id)
    # Create two order lines with different quantities / unit prices and make sure the best one is used on the invoic
    order_line = order.order_lines.create! product_id: product.id, quantity: 10, line_number: 1, price_per_unit: 10
    order_line = order.order_lines.create! product_id: product.id, quantity: 20, line_number: 8, price_per_unit: 5
    order
  }

  let (:shipment) {
    s = Factory(:shipment, master_bill_of_lading: "MBOL1234567890", house_bill_of_lading: "HBOL987654321", mode: "Ocean", importer: pvh)
    c = s.containers.create! container_number: "ABCD1234567890", fcl_lcl: "FCL"

    l = Factory(:shipment_line, shipment: s, container: c, quantity: 10, product: product, linked_order_line_id: order.order_lines.first.id, gross_kgs: 200)
    l2 = Factory(:shipment_line, shipment: s, container: c, quantity: 20, product: product, linked_order_line_id: order.order_lines.second.id, gross_kgs: 100)

    l.shipment.reload
  }

  let (:entry) {
    e = Factory(:entry, broker_reference: "12345", importer_id: pvh.id, customer_number: "PVH", container_numbers: "ABCD1234567890", master_bills_of_lading: "MBOL9999\n MBOL1234567890")
    invoice = e.commercial_invoices.create! invoice_number: "1"
    line = invoice.commercial_invoice_lines.create! po_number: "ORDER", part_number: "PART", quantity: BigDecimal("20"), unit_price: BigDecimal("5"), value: BigDecimal("100")
    tariff_1 = line.commercial_invoice_tariffs.create! duty_amount: BigDecimal("50"), gst_amount: BigDecimal("5")
    tariff_2 = line.commercial_invoice_tariffs.create! duty_amount: BigDecimal("25"), gst_amount: BigDecimal("2.50")

    e
  }

  let (:entry_snapshot) {
    entry.reload
    JSON.parse(CoreModule.find_by_object(entry).entity_json(entry))
  }

  let (:now) { Time.zone.parse("2018-11-07 12:00") }

  around :each do |example|
    Timecop.freeze(now) { example.run }
  end

  let (:captured_xml) { [] }

  before :each do 
    allow(subject).to receive(:ftp_sync_file) do |temp, sync_record|
      captured_xml << temp.read
    end
  end

  def validate_invoice_header x, invoice_number
    file_invoice = invoice_number.gsub("-", "_")

    expect(x.name).to eq "GenericInvoiceMessage"
    expect(x).to have_xpath_value("TransactionInfo/Sender/Code", "VANDEGRIFT")
    expect(x).to have_xpath_value("TransactionInfo/Receiver/Code", "PVH")
    expect(x).to have_xpath_value("TransactionInfo/File/ReceivedTime/Date", "2018-11-07")
    expect(x).to have_xpath_value("TransactionInfo/File/ReceivedTime/Time", "07:00:00")
    expect(x).to have_xpath_value("TransactionInfo/File/OriginalFile/FileType", "XML")
    expect(x).to have_xpath_value("TransactionInfo/File/OriginalFile/FileName", "GI_VANDE_PVH_#{file_invoice}_1541592000.xml")
    expect(x).to have_xpath_value("TransactionInfo/File/OriginalFile/MessageType", "GENINV")
    expect(x).to have_xpath_value("TransactionInfo/File/OriginalFile/MessageId", "1541592000")
    expect(x).to have_xpath_value("TransactionInfo/File/OriginalFile/ControlNumber", "1541592000")
    expect(x).to have_xpath_value("TransactionInfo/File/OriginalFile/HeaderControlNumber", "1541592000")
    expect(x).to have_xpath_value("TransactionInfo/File/XMLFile/FileName", "GI_VANDE_PVH_#{file_invoice}_1541592000.xml")
    expect(x).to have_xpath_value("TransactionInfo/File/XMLFile/CreateTime/Date", "2018-11-07")
    expect(x).to have_xpath_value("TransactionInfo/File/XMLFile/CreateTime/Time", "07:00:00")
    expect(x).to have_xpath_value("GenericInvoices/GenericInvoice/@Type", "Broker Invoice")
    expect(x).to have_xpath_value("GenericInvoices/GenericInvoice/Purpose", "Create")
    
    nil
  end

  describe "generate_and_send_duty_charges" do

    let (:broker_invoice_duty) {
      i = entry.broker_invoices.create! invoice_number: "12345", invoice_date: Date.new(2018, 11, 7), invoice_total: BigDecimal("175"), currency: "USD"
      l = i.broker_invoice_lines.create! charge_code: "0001", charge_amount: BigDecimal("175"), charge_description: "DUTY"
      i
    }

    before :each do 
      entry
      broker_invoice_duty
      shipment
    end

    it "sends duty invoices based on commercial invoice line data" do
      inv_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      subject.generate_and_send_duty_charges entry_snapshot, inv_snapshot, broker_invoice_duty

      expect(captured_xml.length).to eq 1

      x = REXML::Document.new(captured_xml.first).root
      validate_invoice_header(x, "12345-DUTY")
      
      inv = REXML::XPath.first(x, "GenericInvoices/GenericInvoice")
      h = REXML::XPath.first(x, "GenericInvoices/GenericInvoice/InvoiceHeader")
      expect(h).to have_xpath_value("InvoiceNumber", "12345-DUTY")
      expect(h).to have_xpath_value("InvoiceDateTime", "2018-11-07T12:00:00")
      expect(inv).to have_xpath_value("count(InvoiceDetails/InvoiceLineItem)", 1)
      expect(inv).to have_xpath_value("InvoiceSummary/NumberOfInvoiceLineItems", "1")

      l = REXML::XPath.first(inv, "InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = 'C530']")
      expect(l).not_to be_nil
      # The level attribute is the same across all lines, so only need to test it here
      expect(l).to have_xpath_value("@Level", "Manifest Line Item")
      expect(l).to have_xpath_value("OrderNumber", "ORDER")
      expect(l).to have_xpath_value("ProductCode", "PART")
      expect(l).to have_xpath_value("ItemNumber", "008")
      expect(l).to have_xpath_value("BLNumber", "MBOL1234567890")
      expect(l).to have_xpath_value("ContainerNumber", "ABCD1234567890")

      c = REXML::XPath.first(l, "ChargeField[Type/Code = 'C530']")
      expect(c).not_to be_nil

      # The ChargeField data is the same across all lines, so only need to test all the data on the first line
      expect(c).to have_xpath_value("Level", "Manifest Line Item")
      expect(c).to have_xpath_value("ChargeDate/Date", "2018-11-07")
      expect(c).to have_xpath_value("ChargeDate/Time", "12:00:00")
      expect(c).to have_xpath_value("ChargeDate/TimeZone", "EST")
      expect(c).to have_xpath_value("Value", "75.0")
      expect(c).to have_xpath_value("Currency", "CAD")

      c = REXML::XPath.first(l, "ChargeField[Type/Code = '0023']")
      expect(c).not_to be_nil
      expect(c).to have_xpath_value("Value", "7.5")
    end

    it "skips charge lines with zero / nil values" do
      line = entry.commercial_invoices.first.commercial_invoice_lines.first
      line.commercial_invoice_tariffs.update_all gst_amount: nil

      inv_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      subject.generate_and_send_duty_charges entry_snapshot, inv_snapshot, broker_invoice_duty

      expect(captured_xml.length).to eq 1

      x = REXML::Document.new captured_xml.first

      l = REXML::XPath.first(x.root, "GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = 'C530']")
      expect(l).not_to be_nil

      l = REXML::XPath.first(x.root, "GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = '0023']")
      expect(l).to be_nil
    end
  end

  describe "generate_and_send_line_charges" do
    let (:broker_invoice_line_charges) {
      i = entry.broker_invoices.create! invoice_number: "12345", invoice_date: Date.new(2018, 11, 7), invoice_total: BigDecimal("250"), currency: "USD"
      l = i.broker_invoice_lines.create! charge_code: "22", charge_amount: BigDecimal("200"), charge_description: "SOMETHING"
      l = i.broker_invoice_lines.create! charge_code: "255", charge_amount: BigDecimal("50"), charge_description: "SOMETHING ELSE"
      i
    }

    before :each do
      entry
      broker_invoice_line_charges
      shipment
    end

    it "sends line level charges" do
      inv_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      subject.generate_and_send_line_charges entry_snapshot, inv_snapshot, broker_invoice_line_charges

      expect(captured_xml.length).to eq 1

      x = REXML::Document.new(captured_xml.first).root
      validate_invoice_header(x, "12345-LINE")

      inv = REXML::XPath.first(x, "GenericInvoices/GenericInvoice")
      h = REXML::XPath.first(x, "GenericInvoices/GenericInvoice/InvoiceHeader")
      expect(h).to have_xpath_value("InvoiceNumber", "12345-LINE")
      expect(h).to have_xpath_value("InvoiceDateTime", "2018-11-07T12:00:00")
      expect(inv).to have_xpath_value("count(InvoiceDetails/InvoiceLineItem)", 1)
      expect(inv).to have_xpath_value("InvoiceSummary/NumberOfInvoiceLineItems", "1")


      l = REXML::XPath.first(inv, "InvoiceDetails/InvoiceLineItem")
      expect(l).not_to be_nil
      # The level attribute is the same across all lines, so only need to test it here
      expect(l).to have_xpath_value("@Level", "Manifest Line Item")
      expect(l).to have_xpath_value("OrderNumber", "ORDER")
      expect(l).to have_xpath_value("ProductCode", "PART")
      expect(l).to have_xpath_value("ItemNumber", "008")
      expect(l).to have_xpath_value("BLNumber", "MBOL1234567890")
      expect(l).to have_xpath_value("ContainerNumber", "ABCD1234567890")

      c = REXML::XPath.first(l, "ChargeField[Type/Code = 'G740']")
      # The ChargeField data is the same across all lines, so only need to test first it here
      expect(c).to have_xpath_value("Level", "Manifest Line Item")
      expect(c).to have_xpath_value("ChargeDate/Date", "2018-11-07")
      expect(c).to have_xpath_value("ChargeDate/Time", "12:00:00")
      expect(c).to have_xpath_value("ChargeDate/TimeZone", "EST")
      expect(c).to have_xpath_value("Value", "200.0")
      expect(c).to have_xpath_value("Currency", "USD")

      c = REXML::XPath.first(l, "ChargeField[Type/Code = '0026']")
      expect(c).to have_xpath_value("Value", "50.0")
    end

    it "prorates charges based on commercial invoice value" do
      broker_invoice_line_charges.broker_invoice_lines.last.destroy
      # By using a value of 200, it forces the valuation of the line to be 2/3 that of the first line, thus forcing some extra math we're testing here too
      line = entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "ORDER", part_number: "PART", value: BigDecimal("200")
      
      inv_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      subject.generate_and_send_line_charges entry_snapshot, inv_snapshot, broker_invoice_line_charges

      expect(captured_xml.length).to eq 1

      x = REXML::Document.new(captured_xml.first).root

      lines = REXML::XPath.each(x, "GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = 'G740']").to_a
  
      expect(lines[0]).not_to be_nil
      expect(lines[0]).to have_xpath_value("ChargeField/Value", "66.67")

      expect(lines[1]).not_to be_nil
      expect(lines[1]).to have_xpath_value("ChargeField/Value", "133.33")
      
    end

    it "makes all unmapped charge codes use the miscellaneous GTN charge code" do
      broker_invoice_line_charges.broker_invoice_lines.first.update_attributes! charge_code: "9999"
      broker_invoice_line_charges.broker_invoice_lines.second.update_attributes! charge_code: "1111"

      inv_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      subject.generate_and_send_line_charges entry_snapshot, inv_snapshot, broker_invoice_line_charges

      expect(captured_xml.length).to eq 1

      x = REXML::Document.new(captured_xml.first).root

      lines = REXML::XPath.each(x, "GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem/ChargeField[Type/Code = '942']").to_a
      expect(lines.length).to eq 1
      expect(lines[0]).not_to be_nil
      expect(lines[0]).to have_xpath_value("Value", "250.0")
    end

    it "matches on shipment quantity if unit cost is the same on all order lines" do
      order.order_lines.update_all price_per_unit: 5

      inv_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      subject.generate_and_send_line_charges entry_snapshot, inv_snapshot, broker_invoice_line_charges

      expect(captured_xml.length).to eq 1
      expect(REXML::Document.new(captured_xml.first).root).to have_xpath_value("GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = 'G740']/ItemNumber", "008")
    end

    it "utilizes the first shipment line found if unit cost / quantity is same for all lines" do
      order.order_lines.update_all price_per_unit: 5
      shipment.shipment_lines.update_all quantity: 20

      inv_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      subject.generate_and_send_line_charges entry_snapshot, inv_snapshot, broker_invoice_line_charges

      expect(captured_xml.length).to eq 1
      expect(REXML::Document.new(captured_xml.first).root).to have_xpath_value("GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = 'G740']/ItemNumber", "001")
    end

    it "utilizes the first shipment line found if unit cost / quantity doesn't match for any line" do
      order.order_lines.update_all price_per_unit: 100
      shipment.shipment_lines.update_all quantity: 200

      inv_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      subject.generate_and_send_line_charges entry_snapshot, inv_snapshot, broker_invoice_line_charges

      expect(captured_xml.length).to eq 1
      expect(REXML::Document.new(captured_xml.first).root).to have_xpath_value("GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = 'G740']/ItemNumber", "001")
    end

    it "uses house bill for non-ocean modes" do 
      shipment.update_attributes! mode: "Air"

      inv_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      subject.generate_and_send_line_charges entry_snapshot, inv_snapshot, broker_invoice_line_charges

      expect(captured_xml.length).to eq 1
      expect(REXML::Document.new(captured_xml.first).root).to have_xpath_value("GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = 'G740']/BLNumber", "HBOL987654321")
    end

    it "uses house bill for LCL ocean modes" do 
      c = shipment.containers.first
      c.fcl_lcl = "LCL"
      c.save!

      inv_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      subject.generate_and_send_line_charges entry_snapshot, inv_snapshot, broker_invoice_line_charges

      expect(captured_xml.length).to eq 1
      expect(REXML::Document.new(captured_xml.first).root).to have_xpath_value("GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = 'G740']/BLNumber", "HBOL987654321")
    end
  end

  describe "generate_and_send_container_charges" do
    let (:broker_invoice_line_container_charges) {
      i = entry.broker_invoices.create! invoice_number: "12345", invoice_date: Date.new(2018, 11, 7), invoice_total: BigDecimal("300"), currency: "CAD"
      l = i.broker_invoice_lines.create! charge_code: "31", charge_amount: BigDecimal("200"), charge_description: "SOMETHING"
      l = i.broker_invoice_lines.create! charge_code: "33", charge_amount: BigDecimal("100"), charge_description: "SOMETHING"
      i
    }

    before :each do
      entry
      broker_invoice_line_container_charges
      shipment
    end

    it "sends container level charges" do
      inv_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      subject.generate_and_send_container_charges entry_snapshot, inv_snapshot, broker_invoice_line_container_charges

      expect(captured_xml.length).to eq 1

      x = REXML::Document.new(captured_xml.first).root
      validate_invoice_header(x, "12345-CONTAINER")

      inv = REXML::XPath.first(x, "GenericInvoices/GenericInvoice")
      h = REXML::XPath.first(x, "GenericInvoices/GenericInvoice/InvoiceHeader")
      expect(h).to have_xpath_value("InvoiceNumber", "12345-CONTAINER")
      expect(h).to have_xpath_value("InvoiceDateTime", "2018-11-07T12:00:00")
      expect(inv).to have_xpath_value("count(InvoiceDetails/InvoiceLineItem)", 2)
      expect(inv).to have_xpath_value("InvoiceSummary/NumberOfInvoiceLineItems", "2")

      l = REXML::XPath.first(inv, "InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = 'C080']")
      expect(l).not_to be_nil
      # The level attribute is the same across all lines, so only need to test it here
      expect(l).to have_xpath_value("@Level", "Container")
      expect(l).not_to have_xpath_value("OrderNumber", "ORDER")
      expect(l).not_to have_xpath_value("ProductCode", "PART")
      expect(l).to have_xpath_value("ItemNumber", "001")
      expect(l).to have_xpath_value("BLNumber", "MBOL1234567890")
      expect(l).to have_xpath_value("ContainerNumber", "ABCD1234567890")
      # The ChargeField data is the same across all lines, so only need to test it here
      expect(l).to have_xpath_value("ChargeField/Level", "Container")
      expect(l).to have_xpath_value("ChargeField/ChargeDate/Date", "2018-11-07")
      expect(l).to have_xpath_value("ChargeField/ChargeDate/Time", "12:00:00")
      expect(l).to have_xpath_value("ChargeField/ChargeDate/TimeZone", "EST")
      expect(l).to have_xpath_value("ChargeField/Value", "200.0")
      expect(l).to have_xpath_value("ChargeField/Currency", "CAD")

      l = REXML::XPath.first(inv, "InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = '545']")
      expect(l).not_to be_nil
      expect(l).to have_xpath_value("ChargeField/Value", "100.0")
    end

    it "prorates container charges based on container weights" do
      broker_invoice_line_container_charges.broker_invoice_lines.last.destroy

      # Add a second container to the entry and the shipment
      entry.update_attributes! container_numbers: (entry.container_numbers + "\n CONT1234567890")

      c = shipment.containers.create! container_number: "CONT1234567890"
      shipment.shipment_lines.first.update_attributes! container_id: c.id

      inv_snapshot = subject.json_child_entities(entry_snapshot, "BrokerInvoice").first
      subject.generate_and_send_container_charges entry_snapshot, inv_snapshot, broker_invoice_line_container_charges

      expect(captured_xml.length).to eq 1

      x = REXML::Document.new(captured_xml.first).root

      lines = REXML::XPath.each(x, "GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem[ChargeField/Type/Code = 'C080']").to_a
      expect(lines.length).to eq 2

      expect(lines[0]).not_to be_nil
      expect(lines[0]).to have_xpath_value("ChargeField/Value", "66.67")

      expect(lines[1]).not_to be_nil
      expect(lines[1]).to have_xpath_value("ChargeField/Value", "133.33")
    end
  end
end