describe OpenChain::Report::HmCanadaDrawbackReport do

  describe "permission?" do
    let(:user) { Factory(:user) }

    it "allows access to group members" do
      group = Group.use_system_group described_class::HM_CANADA_DRAWBACK_USERS, create: true
      expect(user).to receive(:in_group?).with(group).and_return true
      expect(described_class.permission? user).to eq true
    end

    it "forbids access to user not in group" do
      group = Group.use_system_group described_class::HM_CANADA_DRAWBACK_USERS, create: true
      expect(user).to receive(:in_group?).with(group).and_return false
      expect(described_class.permission? user).to eq false
    end

    it "generates group if it does not exist" do
      expect(Group.where(system_code:described_class::HM_CANADA_DRAWBACK_USERS).first).to be_nil
      expect(described_class.permission? user).to eq false
      group = Group.where(system_code:described_class::HM_CANADA_DRAWBACK_USERS).first
      expect(group).to_not be_nil
      expect(group.name).to eq "H&M Canada Drawback Report"
      expect(group.description).to eq "Users permitted to run the H&M Canada Drawback Report."
    end
  end

  describe "generate_and_send_report" do
    let(:user) { Factory(:user) }

    after :each do
      @tf.close! if @tf
    end
    
    it "generates report" do
      entry_us = Factory(:entry, entry_number:"entry-X", customer_number:"HENNE", release_date:Date.new(2017,3,5))
      invoice_us = entry_us.commercial_invoices.create!(invoice_number:"55666-01")
      invoice_line_us_1 = invoice_us.commercial_invoice_lines.create!(customs_line_number:23, part_number:"5678901", unit_price:BigDecimal.new("2.34"))
      invoice_line_us_2 = invoice_us.commercial_invoice_lines.create!(customs_line_number:24, part_number:"5678902", unit_price:BigDecimal.new("1.53"))
      invoice_line_us_3 = invoice_us.commercial_invoice_lines.create!(customs_line_number:25, part_number:"5678901", unit_price:BigDecimal.new("3.84"))
      i2_return_1 = HmI2DrawbackLine.create!(invoice_number:"55666", shipment_type:"returns", part_number:"567890133333", customer_order_reference:"A01", part_description:"part-AB", quantity:5, shipment_date:Date.new(2017,3,7))
      i2_return_2 = HmI2DrawbackLine.create!(invoice_number:"55666", shipment_type:"returns", part_number:"567890144444", customer_order_reference:"A01", part_description:"part-AB", quantity:6, shipment_date:Date.new(2017,3,7))
      i2_return_3 = HmI2DrawbackLine.create!(invoice_number:"55666", shipment_type:"returns", part_number:"567890144444", customer_order_reference:"B02", part_description:"part-AB", quantity:7, shipment_date:Date.new(2017,3,8))
      i2_return_4 = HmI2DrawbackLine.create!(invoice_number:"55666", shipment_type:"returns", part_number:"567890244444", customer_order_reference:"C03", part_description:"part-BC", quantity:8, shipment_date:Date.new(2017,3,9))
      i2_export_1 = HmI2DrawbackLine.create!(invoice_number:"66555", shipment_type:"export", part_number:"567890133333", customer_order_reference:"A01")
      i2_export_2 = HmI2DrawbackLine.create!(invoice_number:"66555", shipment_type:"export", part_number:"567890144444", customer_order_reference:"B02")
      i2_export_3 = HmI2DrawbackLine.create!(invoice_number:"66555", shipment_type:"export", part_number:"567890244444", customer_order_reference:"C03")
      entry_ca = Factory(:entry, entry_number:"CA-entry-Y", customer_number:"HMCAD", import_date:Date.new(2017,3,8))
      invoice_ca = entry_ca.commercial_invoices.create!(invoice_number:"66555-03")
      invoice_line_ca_1 = invoice_ca.commercial_invoice_lines.create!(customs_line_number:34, part_number:"5678901", unit_price:BigDecimal.new("5.55"), quantity:43, subheader_number:39)
      invoice_line_ca_1.commercial_invoice_tariffs.create!(tariff_description:"described")
      invoice_line_ca_2 = invoice_ca.commercial_invoice_lines.create!(customs_line_number:35, part_number:"5678902", unit_price:BigDecimal.new("3.45"), quantity:44, subheader_number:40)

      settings = {'start_date' => "2017-03-01", 'end_date' => "2017-04-30" }
      @tf = subject.generate_and_send_report user, settings
      expect(@tf.original_filename).to eq "HM_Canada_Drawback_Report_2017-03-01_2017-04-30.xlsx"

      reader = XlsxTestReader.new(@tf.path).raw_workbook_data
      expect(reader.length).to eq 1
      sheet = reader["Data"]
      expect(sheet).to_not be_nil
      expect(sheet.length).to eq 4
      expect(sheet[0]).to eq ["HM Order Number", "US Transaction Number", "Part Number", "Description", "Quantity", "Export Date", "Subheader Number", "Line Number", "Unit Price", "CDN Transaction Number", "Part Number", "Description", "Quantity", "Import Date", "Subheader Number", "Line Number", "Unit Price"]
      expect(sheet[1]).to eq ["A01", "entry-X", "567890133333", "part-AB", 5.0, i2_return_1.shipment_date, nil, 23, 2.34, "CA-entry-Y", "5678901", "described", 43.0, Date.new(2017,3,8), 39, 34, 5.55]
      expect(sheet[2]).to eq ["B02", "entry-X", "567890144444", "part-AB", 7.0, i2_return_3.shipment_date, nil, 23, 2.34, "CA-entry-Y", "5678901", "described", 43.0, Date.new(2017,3,8), 39, 34, 5.55]
      expect(sheet[3]).to eq ["C03", "entry-X", "567890244444", "part-BC", 8.0, i2_return_4.shipment_date, nil, 24, 1.53, "CA-entry-Y", "5678902", nil, 44.0, Date.new(2017,3,8), 40, 35, 3.45]
    end

    it "excludes entry with release date before range" do
      entry_us = Factory(:entry, entry_number:"entry-X", customer_number:"HENNE", release_date:Date.new(2017,2,28))
      invoice_us = entry_us.commercial_invoices.create!(invoice_number:"55666-01")
      invoice_line_us = invoice_us.commercial_invoice_lines.create!(customs_line_number:23, part_number:"5678901", unit_price:BigDecimal.new("2.34"))
      i2_return = HmI2DrawbackLine.create!(invoice_number:"55666", shipment_type:"returns", part_number:"567890133333", customer_order_reference:"A01", part_description:"part-AB", quantity:5, shipment_date:Date.new(2017,3,7))
      i2_export = HmI2DrawbackLine.create!(invoice_number:"66555", shipment_type:"export", part_number:"567890133333", customer_order_reference:"A01")
      entry_ca = Factory(:entry, entry_number:"CA-entry-Y", customer_number:"HMCAD", import_date:Date.new(2017,3,8))
      invoice_ca = entry_ca.commercial_invoices.create!(invoice_number:"66555-03")
      invoice_line_ca = invoice_ca.commercial_invoice_lines.create!(customs_line_number:34, part_number:"5678901", unit_price:BigDecimal.new("5.55"), quantity:43, subheader_number:39)

      settings = {'start_date' => "2017-03-01", 'end_date' => "2017-04-30" }
      @tf = subject.generate_and_send_report user, settings
      reader = XlsxTestReader.new(@tf.path).raw_workbook_data
      sheet = reader["Data"]
      expect(sheet.length).to eq 1
    end

    it "excludes entry with release date after range" do
      entry_us = Factory(:entry, entry_number:"entry-X", customer_number:"HENNE", release_date:Date.new(2017,5,1))
      invoice_us = entry_us.commercial_invoices.create!(invoice_number:"55666-01")
      invoice_line_us = invoice_us.commercial_invoice_lines.create!(customs_line_number:23, part_number:"5678901", unit_price:BigDecimal.new("2.34"))
      i2_return = HmI2DrawbackLine.create!(invoice_number:"55666", shipment_type:"returns", part_number:"567890133333", customer_order_reference:"A01", part_description:"part-AB", quantity:5, shipment_date:Date.new(2017,3,7))
      i2_export = HmI2DrawbackLine.create!(invoice_number:"66555", shipment_type:"export", part_number:"567890133333", customer_order_reference:"A01")
      entry_ca = Factory(:entry, entry_number:"CA-entry-Y", customer_number:"HMCAD", import_date:Date.new(2017,3,8))
      invoice_ca = entry_ca.commercial_invoices.create!(invoice_number:"66555-03")
      invoice_line_ca = invoice_ca.commercial_invoice_lines.create!(customs_line_number:34, part_number:"5678901", unit_price:BigDecimal.new("5.55"), quantity:43, subheader_number:39)

      settings = {'start_date' => "2017-03-01", 'end_date' => "2017-04-30" }
      @tf = subject.generate_and_send_report user, settings
      reader = XlsxTestReader.new(@tf.path).raw_workbook_data
      sheet = reader["Data"]
      expect(sheet.length).to eq 1
    end

    it "excludes line with no matching Canada invoice line" do
      entry_us = Factory(:entry, entry_number:"entry-X", customer_number:"HENNE", release_date:Date.new(2017,3,5))
      invoice_us = entry_us.commercial_invoices.create!(invoice_number:"55666-01")
      invoice_line_us = invoice_us.commercial_invoice_lines.create!(customs_line_number:23, part_number:"5678901", unit_price:BigDecimal.new("2.34"))
      i2_return = HmI2DrawbackLine.create!(invoice_number:"55666", shipment_type:"returns", part_number:"567890133333", customer_order_reference:"A01", part_description:"part-AB", quantity:5, shipment_date:Date.new(2017,3,7))
      i2_export = HmI2DrawbackLine.create!(invoice_number:"66555", shipment_type:"export", part_number:"567890133333", customer_order_reference:"A01")

      settings = {'start_date' => "2017-03-01", 'end_date' => "2017-04-30" }
      @tf = subject.generate_and_send_report user, settings
      reader = XlsxTestReader.new(@tf.path).raw_workbook_data
      sheet = reader["Data"]
      expect(sheet.length).to eq 1
    end

    it "excludes line with no matching export I2" do
      entry_us = Factory(:entry, entry_number:"entry-X", customer_number:"HENNE", release_date:Date.new(2017,3,5))
      invoice_us = entry_us.commercial_invoices.create!(invoice_number:"55666-01")
      invoice_line_us = invoice_us.commercial_invoice_lines.create!(customs_line_number:23, part_number:"5678901", unit_price:BigDecimal.new("2.34"))
      i2_return = HmI2DrawbackLine.create!(invoice_number:"55666", shipment_type:"returns", part_number:"567890133333", customer_order_reference:"A01", part_description:"part-AB", quantity:5, shipment_date:Date.new(2017,3,7))

      settings = {'start_date' => "2017-03-01", 'end_date' => "2017-04-30" }
      @tf = subject.generate_and_send_report user, settings
      reader = XlsxTestReader.new(@tf.path).raw_workbook_data
      sheet = reader["Data"]
      expect(sheet.length).to eq 1
    end

    it "excludes line with no matching returns I2" do
      entry_us = Factory(:entry, entry_number:"entry-X", customer_number:"HENNE", release_date:Date.new(2017,3,5))
      invoice_us = entry_us.commercial_invoices.create!(invoice_number:"55666-01")
      invoice_line_us = invoice_us.commercial_invoice_lines.create!(customs_line_number:23, part_number:"5678901", unit_price:BigDecimal.new("2.34"))

      settings = {'start_date' => "2017-03-01", 'end_date' => "2017-04-30" }
      @tf = subject.generate_and_send_report user, settings
      reader = XlsxTestReader.new(@tf.path).raw_workbook_data
      sheet = reader["Data"]
      expect(sheet.length).to eq 1
    end
  end
end