require 'open_chain/ftp_file_support'

describe OpenChain::CustomHandler::Siemens::SiemensB2XmlGenerator do
  include OpenChain::FtpFileSupport

  def default_row(overrides = {})
    h = {importer_name: "PUMA Canada Inc", importer_id: "PUMA", bn: "807150586RM0001", entry_num: "11981200020462", previous_txn_num: "11981003895907",
         broker_file_num: "3895907", port_of_entry: "809", k84_acct_date: "05/25/2020", release_date: "05/18/2020",
         previous_txn_line: "4", country_of_origin: "KH", place_of_export: "KH", tariff_treatment: "2", currency_code: "CAD",
         currency_conversion_rate: "1", line_num: "4", type: "C", product_num: "59778657", product_desc: "Sweater",
         hs_num: "1234.56.78.90", invoice_qty: "369", customs_duty_rate: "18", customs_duty: "458.95", gst_rate: "5",
         gst: "150.43", excise_tax_rate: "0", sima_code: "1234", sima_assessment: "0", value_for_duty: "2549.71",
         value_for_currency_conversion: "2549.71", vfd_code: "24", purchase_order_num: "1122334455",
         summary_date: "05/18/2020", tariff_code: 'tariff_code', oic_code: 'oic_code', ruling: 'ruling', reason: "This is a reason" }
        .merge(overrides)
    r = []
    r[0] = h[:importer_name]
    r[1] = h[:importer_id]
    r[2] = h[:bn]
    r[3] = "not used"
    r[4] = h[:entry_num]
    r[5] = h[:previous_txn_num]
    r[6] = h[:broker_file_num]
    r[7] = h[:port_of_entry]
    r[8] = h[:k84_acct_date]
    r[9] = h[:release_date]
    r[10] = "not used"
    r[11] = "not used"
    r[12] = h[:summary_date]
    r[13] = "not used"
    r[14] = h[:previous_txn_line]
    r[15] = h[:country_of_origin]
    r[16] = h[:place_of_export]
    r[17] = h[:tariff_treatment]
    r[18] = h[:currency_code]
    r[19] = h[:currency_conversion_rate]
    r[20] = h[:line_num]
    r[21] = h[:type]
    r[22] = h[:product_num]
    r[23] = h[:product_desc]
    r[24] = h[:hs_num]
    r[25] = h[:tariff_code]
    r[26] = h[:invoice_qty]
    r[27] = h[:customs_duty_rate]
    r[28] = h[:customs_duty]
    r[29] = h[:gst_rate]
    r[30] = h[:gst]
    r[31] = h[:excise_tax_rate]
    r[32] = h[:sima_code]
    r[33] = h[:sima_assessment]
    r[34] = h[:value_for_duty]
    r[35] = h[:value_for_currency_conversion]
    r[36] = h[:vfd_code]
    r[37] = h[:purchase_order_num]
    r[38] = h[:oic_code]
    r[39] = h[:ruling]
    r[40] = "not used"
    r[41] = "not used"
    r[42] = "not used"
    r[43] = "not used"
    r[44] = "not used"
    r[45] = "not used"
    r[46] = "not used"
    r[47] = "not used"
    r[48] = "not used"
    r[50] = h[:reason]

    r
  end

  let(:cf) { instance_double(CustomFile) }

  describe "#total_payable" do
    it 'returns the value if positive' do
      klass = described_class.new(cf)
      expect(klass.total_payable(1000.00)).to eq(1000.00)
    end

    it 'returns 0 if negative' do
      klass = described_class.new(cf)
      expect(klass.total_payable(-1000.00)).to eq(0.00)
    end
  end

  describe "#caevl01_total" do
    it 'returns the absolute value if negative' do
      klass = described_class.new(cf)
      expect(klass.caevn01_total(-1000.00)).to eq(1000.00)
    end

    it 'returns 0 if positive' do
      klass = described_class.new(cf)
      expect(klass.caevn01_total(1000.00)).to eq(0.00)
    end
  end

  describe "#calculate_product_values" do
    it "does not mix up totals between entries" do
      row_1 = default_row({entry_num: '1234', type: 'A', value_for_duty: "1000"})
      row_2 = default_row({entry_num: '1234', type: 'C', value_for_duty: "500"})
      row_3 = default_row({entry_num: '3456', type: 'A', value_for_duty: "2000"})
      row_4 = default_row({entry_num: '3456', type: 'C', value_for_duty: "1000"})

      lines = [row_1, row_2, row_3, row_4]

      klass = described_class.new(cf)
      product_rollup = klass.rollup_products(lines)
      product_totals = klass.calculate_product_values(product_rollup)
      expect(product_totals['1234'][:value_for_duty]).to eq(-500)
      expect(product_totals['3456'][:value_for_duty]).to eq(-1000)
    end
  end

  describe "parse" do
    let(:now) { ActiveSupport::TimeZone["America/New_York"].parse("2020-03-15 02:05:08") }
    let(:x) { instance_double(OpenChain::XLClient) }
    let(:p) { described_class.new(cf) }
    let(:file) { Tempfile.new }

    it 'ignores A lines when building XML' do
      rows = [default_row, default_row({type: 'A'})]

      expect(x).to receive(:all_row_values).and_return(rows)
      expect(Tempfile).to receive(:open).with(["siemens", ".xml"]).and_yield(file)

      doc = nil

      expect(p).to receive(:ftp_file).with(file, connect_vfitrack_net("to_ecs/siemens_hc/b2", "1005029_CA_B2_119_11981200020462_20200315020508.xml")) do |f|
        doc = REXML::Document.new(f.read)
        f.close!
      end

      Timecop.freeze(now) { p.parse(x) }

      elem_root = doc.root
      elem_dec = elem_root.elements.to_a("Declaration")[0]
      line_elements = elem_dec.elements.to_a("DeclarationLine")
      expect(line_elements.count).to eq(1)
    end

    it 'sends an xml file' do
      rows = [default_row]

      allow(stub_master_setup).to receive(:production?).and_return false

      expect(p).to receive(:generate_xml).with(rows).and_return REXML::Document.new("<FakeXml><child>A</child></FakeXml>")
      expect(x).to receive(:all_row_values).and_return(rows)
      expect(Tempfile).to receive(:open).with(["siemens", ".xml"]).and_yield(file)

      doc = nil

      expect(p).to receive(:ftp_file).with(file, connect_vfitrack_net("to_ecs/siemens_hc/b2", "1005029_CA_B2_119_11981200020462_20200315020508.xml")) do |f|
        doc = REXML::Document.new(f.read)
        f.close!
      end

      Timecop.freeze(now) { p.parse(x) }

      expect(doc.root.name).to eq "FakeXml"
    end
  end

  describe "process" do
    it "initializes XLClient and passes to parse" do
      x = instance_double(OpenChain::XLClient)
      expect(OpenChain::XLClient).to receive(:new_from_attachable).with(cf).and_return(x)
      expect_any_instance_of(described_class).to receive(:parse).with(x)
      allow(described_class).to receive(:can_view?).and_return(true)
      described_class.new(cf).process(User.new)
    end

    it "will not run if user cannot view" do
      u = User.new
      expect(described_class).to receive(:can_view?).with(u).and_return(false)
      expect_any_instance_of(described_class).not_to receive(:parse)
      described_class.new(cf).process(u)
    end

    it "writes error message to user" do
      u = Factory(:user)
      allow(OpenChain::XLClient).to receive(:new_from_attachable).and_return(instance_double('x'))
      expect(described_class).to receive(:can_view?).and_return true
      expect_any_instance_of(described_class).to receive(:parse).and_raise "some error"
      expect {described_class.new(cf).process(u)}.to change(u.messages, :count).from(0).to(1)
      expect(u.messages.first.subject).to match(/ERROR/)
    end
  end

  describe "can_view?" do
    before do
      allow_any_instance_of(MasterSetup).to receive(:custom_feature?).and_return true
    end

    it "is false if user is not an admin" do
      u = Factory(:user, admin: false)
      expect(described_class.new(cf).can_view?(u)).to eq false
    end

    it "is true if user is an admin" do
      u = Factory(:user, admin: true)
      expect(described_class.new(cf).can_view?(u)).to eq true
    end
  end

  describe "rollup_rows" do
    it 'does not roll up multiple rows if entry numbers are different' do
      r1 = default_row({entry_num: 1234, product_num: 'line1'})
      r2 = default_row({entry_num: 2345, product_num: 'line2'})
      p = described_class.new(instance_double('attachable'))
      hsh = p.rollup_entries([r1, r2])

      expect(hsh[1234].length).to eq(1)
      expect(hsh[2345].length).to eq(1)
    end

    it 'rolls up multiple rows if entry numbers are identical' do
      r1 = default_row({entry_num: 1234, product_num: 'line1'})
      r2 = default_row({entry_num: 1234, product_num: 'line2'})
      p = described_class.new(instance_double('attachable'))
      hsh = p.rollup_entries([r1, r2])

      expect(hsh[1234].length).to eq(2)
    end
  end

  describe "generate_xml" do
    def generate_product_rollup(instance, rows)
      product_rollup = instance.rollup_products(rows)
      total_values = instance.calculate_product_values(product_rollup)
      allow(instance).to receive(:product_rollup).and_return(product_rollup)
      allow(instance).to receive(:total_values).and_return(total_values)
    end

    it 'puts negative total values in the declaration line' do
      p = described_class.new(instance_double('attachable'))
      allow(p).to receive(:total_payable).and_return(0.00)
      allow(p).to receive(:caevn01_total).and_return(100.00)
      r1 = default_row

      generate_product_rollup(p, [r1])

      doc = p.generate_xml([r1])
      elem_root = doc.root
      elem_dec = elem_root.elements.to_a("Declaration")[0]
      expect(elem_dec.text("TotalPayable")).to eq "0.0"

      line_elements = elem_dec.elements.to_a("DeclarationLine")
      expect(line_elements.size).to eq 1
      elem_line_1 = line_elements[0]
      expect(elem_line_1.text("CAEVN01")).to eq("100.0")
    end

    it 'puts positive total values in the declaration' do
      p = described_class.new(instance_double('attachable'))
      allow(p).to receive(:total_payable).and_return(1000.00)
      allow(p).to receive(:caevn01_total).and_return(0.00)
      r1 = default_row

      generate_product_rollup(p, [r1])

      doc = p.generate_xml([r1])
      elem_root = doc.root
      elem_dec = elem_root.elements.to_a("Declaration")[0]
      expect(elem_dec.text("TotalPayable")).to eq "1000.0"

      line_elements = elem_dec.elements.to_a("DeclarationLine")
      expect(line_elements.size).to eq 1
      elem_line_1 = line_elements[0]
      expect(elem_line_1.text("CAEVN01")).to eq("0.0")
    end

    it 'handles split rows' do
      r1 = default_row({line_num: "10/SL"})
      p = described_class.new(instance_double('attachable'))

      generate_product_rollup(p, [r1])

      doc = p.generate_xml([r1])
      elem_root = doc.root
      elem_dec = elem_root.elements.to_a("Declaration")[0]
      line_elements = elem_dec.elements.to_a("DeclarationLine")
      elem_line_1 = line_elements[0]
      expect(elem_line_1.text("LineNum")).to eq "10/SL"
      expect(elem_line_1.text("PreviousTxnLine")).to eq "10"
    end

    it 'handles multiple rows' do
      r1 = default_row({entry_num: 1234, product_num: 'line1'})
      r2 = default_row({entry_num: 1234, product_num: 'line2'})
      p = described_class.new(instance_double('attachable'))

      generate_product_rollup(p, [r1, r2])

      doc = p.generate_xml([r1, r2])

      elem_root = doc.root
      elem_dec = elem_root.elements.to_a("Declaration")[0]
      line_elements = elem_dec.elements.to_a("DeclarationLine")
      expect(line_elements.size).to eq 2
      elem_line_1 = line_elements[0]
      elem_line_2 = line_elements[1]
      expect(elem_line_1.text("ProductNum")).to eq "line1"
      expect(elem_line_2.text("ProductNum")).to eq "line2"
    end

    describe 'SpecialAuthority handling' do
      it 'is blank if neither ruling nor oic_code exists' do
        r1 = default_row(ruling: nil, oic_code: nil)

        p = described_class.new(instance_double('attachable'))

        generate_product_rollup(p, [r1])

        doc = p.generate_xml([r1])
        elem_root = doc.root

        elem_dec = elem_root.elements.to_a("Declaration")[0]
        line_elements = elem_dec.elements.to_a("DeclarationLine")
        elem_line_1 = line_elements[0]

        expect(elem_line_1.text("SpecialAuthority")).to eq(nil)
      end

      it 'is oic_code if both ruling and oic_code exists' do
        r1 = default_row(ruling: 'ruling', oic_code: 'oic_code')

        p = described_class.new(instance_double('attachable'))

        generate_product_rollup(p, [r1])

        doc = p.generate_xml([r1])
        elem_root = doc.root

        elem_dec = elem_root.elements.to_a("Declaration")[0]
        line_elements = elem_dec.elements.to_a("DeclarationLine")
        elem_line_1 = line_elements[0]

        expect(elem_line_1.text("SpecialAuthority")).to eq('oic_code')
      end

      it 'is ruling if ruling exists but oic_code does not' do
        r1 = default_row(ruling: 'ruling', oic_code: nil)

        p = described_class.new(instance_double('attachable'))

        generate_product_rollup(p, [r1])

        doc = p.generate_xml([r1])
        elem_root = doc.root

        elem_dec = elem_root.elements.to_a("Declaration")[0]
        line_elements = elem_dec.elements.to_a("DeclarationLine")
        elem_line_1 = line_elements[0]

        expect(elem_line_1.text("SpecialAuthority")).to eq('ruling')
      end

      it 'is oic_code if oic_code exists but ruling does not' do
        r1 = default_row(ruling: nil, oic_code: 'oic_code')

        p = described_class.new(instance_double('attachable'))

        generate_product_rollup(p, [r1])

        doc = p.generate_xml([r1])
        elem_root = doc.root

        elem_dec = elem_root.elements.to_a("Declaration")[0]
        line_elements = elem_dec.elements.to_a("DeclarationLine")
        elem_line_1 = line_elements[0]

        expect(elem_line_1.text("SpecialAuthority")).to eq('oic_code')
      end
    end

    it 'produces XML' do
      r1 = default_row
      p = described_class.new(instance_double('attachable'))

      generate_product_rollup(p, [r1])

      doc = p.generate_xml([r1])

      elem_root = doc.root
      expect(elem_root.name).to eq "CA_EV"
      expect(elem_root.namespace('xs')).to eq 'http://www.w3.org/2001/XMLSchema'

      elem_dec = elem_root.elements.to_a("Declaration")[0]
      expect(elem_dec).not_to be_nil

      expect(elem_dec.text("EntryNum")).to eq "11981200020462"
      expect(elem_dec.text("SummaryDate")).to eq "05/18/2020"
      expect(elem_dec.text("BrokerFileNum")).to eq "3895907"
      expect(elem_dec.text("EntryType")).to eq "B2"
      expect(elem_dec.text("ReleaseDate")).to eq "05/18/2020"
      expect(elem_dec.text("CurrencyCode")).to eq "CAD"
      expect(elem_dec.text("PortOfEntry")).to eq "809"
      expect(elem_dec.text("ImporterID")).to eq "807150586RM0001"
      expect(elem_dec.text("ImporterName")).to eq "PUMA Canada Inc"
      expect(elem_dec.text("TotalValueForDuty")).to eq "2549.71"
      expect(elem_dec.text("TotalCustomsDuty")).to eq "458.95"
      expect(elem_dec.text("TotalSIMAAssessment")).to eq "0.0"
      expect(elem_dec.text("TotalExciseTax")).to eq "0.0"
      expect(elem_dec.text("TotalGST")).to eq "150.43"
      expect(elem_dec.text("TotalPayable")).to eq "609.38"

      line_elements = elem_dec.elements.to_a("DeclarationLine")
      expect(line_elements.size).to eq 1
      elem_line_1 = line_elements[0]

      expect(elem_line_1.text("CountryOfOrigin")).to eq "KH"
      expect(elem_line_1.text("PlaceOfExport")).to eq "KH"
      expect(elem_line_1.text("TariffTreatment")).to eq "2"
      expect(elem_line_1.text("LineNum")).to eq "4"
      expect(elem_line_1.text("InvoiceQty")).to eq "369"
      expect(elem_line_1.text("PurchaseOrderNum")).to eq "1122334455"
      expect(elem_line_1.text("ProductNum")).to eq "59778657"
      expect(elem_line_1.text("ProductDesc")).to eq "Sweater"
      expect(elem_line_1.text("HsNum")).to eq "1234567890"
      expect(elem_line_1.text("PreviousTxnNum")).to eq "11981003895907"
      expect(elem_line_1.text("PreviousTxnLine")).to eq "4"
      expect(elem_line_1.text("VFDCode")).to eq "24"
      expect(elem_line_1.text("SIMACode")).to eq "1234"
      expect(elem_line_1.text("CustomsDutyRate")).to eq "18"
      expect(elem_line_1.text("ExciseTaxRate")).to eq "0"
      expect(elem_line_1.text("GSTRate")).to eq "5"
      expect(elem_line_1.text("CurrencyConversionRate")).to eq "1"
      expect(elem_line_1.text("ValueForCurrencyConversion")).to eq "2549.71"
      expect(elem_line_1.text("CustomsDuty")).to eq "458.95"
      expect(elem_line_1.text("SIMAAssessment")).to eq "0"
      expect(elem_line_1.text("ExciseTax")).to eq nil
      expect(elem_line_1.text("OICCode")).to eq "oic_code"
      expect(elem_line_1.text("K84AcctDate")).to eq "05/25/2020"
      expect(elem_line_1.text("SubHeaderNum")).to eq "4"
      expect(elem_line_1.text("ValueForDuty")).to eq "2549.71"
      expect(elem_line_1.text("TariffCode")).to eq "tariff_code"
      expect(elem_line_1.text("SpecialAuthority")).to eq('oic_code')
      expect(elem_line_1.text("ClientNumber")).to eq('PUMA')
      expect(elem_line_1.text("CAEVN01")).to eq('0.0')
      expect(elem_line_1.text("CAEVL01")).to eq('This is a reason')
    end
  end
end