describe OpenChain::CustomHandler::Hm::HmPoLineParser do
  let!(:cf) { double("custom file") }
  let!(:handler) { described_class.new cf }

  describe 'process' do
    let(:user) { FactoryBot(:master_user) }

    before :each do
      allow(cf).to receive(:attached).and_return cf
      allow(cf).to receive(:path).and_return "path/to/file.xlsx"
      allow(cf).to receive(:attached_file_name).and_return "file.xlsx"
    end

    it "parses the file" do
      expect(handler).to receive(:process_excel).with(cf).and_return({})
      handler.process user

      expect(user.messages.length).to eq 1
      expect(user.messages.first.subject).to eq "H&M PO File Processing Completed"
      expect(user.messages.first.body).to eq "H&M PO File 'file.xlsx' has finished processing."
    end

    it "handles 'fixable' errors" do
      expect(handler).to receive(:process_excel).with(cf).and_return({fixable: ["This error can be corrected by the user.", "Another message."]})
      handler.process(user)
      expect(user.messages.length).to eq 1
      expect(user.messages.first.subject).to eq "H&M PO File Processing Completed With Errors"
      expect(user.messages.first.body).to eq "H&M PO File 'file.xlsx' has finished processing.\n\nThis error can be corrected by the user.\nAnother message."
    end

    it "handles unexpected errors" do
      expect(handler).to receive(:process_excel).with(cf).and_return({unexpected: ["This error must be handled by IT.", "Another message."]})
      handler.process(user)
      expect(user.messages.length).to eq 1
      expect(user.messages.first.subject).to eq "H&M PO File Processing Completed With Errors"
      expect(user.messages.first.body).to eq "H&M PO File 'file.xlsx' has finished processing.\n\nThis error must be handled by IT.\nAnother message."
    end
  end

  describe "process_excel" do
    let!(:co) { FactoryBot(:company, system_code: "HENNE") }
    let!(:row_0) { ['PO NUMBER', 'PART NUMBER', 'COAST', 'HTS NUMBER', 'MID', 'C/O', 'QTY', 'REPORTING QTY', 'REPORTING UOM', 'NET WT', 'GROSS WT', 'CARTONS', 'UNIT COST', 'CURRENCY', 'INV VALUE', 'ADJUSTED VALUE', 'DOCS RCVD', 'DOCS OK', 'ISSUE CODES', 'COMMENTS'] }
    let!(:row_1) { ['424913', 'HM-1234', 'East', '1111111111', 'BDIRIFABGAZ', 'US', '1', '2', 'ea', nil, '4', '5', '6', 'USD', '7', '8', '2016-08-01', '2016-08-02', 'ABCD', 'no comment'] }
    let!(:row_2) { ['319424', 'HM-4321', 'West', '2222222222', 'BDNIATEX27DHA', 'CA', '2', '3', 'ea', '4', '5', '6', '7', 'CAD', '8', '9', '2016-09-01', '2016-09-02', 'DCBA', 'nothing to see here'] }

    it "parses spreadsheet into new commercial invoice lines" do
      allow(cf).to receive(:path).and_return "file.xlsx"
      expect(handler).to receive(:foreach).with(cf, skip_headers: true).and_yield(row_1, 1).and_yield(row_2, 2)
      expect(handler.process_excel(cf)).to be_empty

      ci_1 = CommercialInvoice.first
      cil_1 = ci_1.commercial_invoice_lines.first
      cit_1 = cil_1.commercial_invoice_tariffs.first
      expect(CommercialInvoice.count).to eq 2

      expect(ci_1.invoice_number).to eq '424913'
      expect(cil_1.part_number).to eq 'HM-1234'
      expect(ci_1.destination_code).to eq 'East'
      expect(cit_1.hts_code).to eq '1111111111'
      expect(ci_1.mfid).to eq 'BDIRIFABGAZ'
      expect(cil_1.country_origin_code).to eq 'US'
      expect(cil_1.quantity).to eq 1
      expect(cit_1.classification_qty_1).to eq 2
      expect(cit_1.classification_uom_1).to eq 'ea'
      expect(cit_1.gross_weight).to eq 4
      expect(ci_1.total_quantity).to eq 5
      expect(cil_1.unit_price).to eq 6
      expect(cil_1.currency).to eq 'USD'
      expect(ci_1.invoice_value_foreign).to eq 7
      expect(cil_1.value_foreign).to eq 8
      expect(ci_1.docs_received_date).to eq Date.parse('2016-08-01')
      expect(ci_1.docs_ok_date).to eq Date.parse('2016-08-02')
      expect(ci_1.issue_codes).to eq 'ABCD'
      expect(ci_1.rater_comments).to eq 'no comment'
      expect(cil_1.line_number).to eq 1
      expect(ci_1.total_quantity_uom).to eq 'CTNS'
      expect(ci_1.importer).to eq co
      # since net wt = 0
      expect(cit_1.classification_qty_2).to be_nil
      expect(cit_1.classification_uom_2).to be_nil

      ci_2 = CommercialInvoice.last
      cil_2 = ci_2.commercial_invoice_lines.first
      cit_2 = cil_2.commercial_invoice_tariffs.first

      expect(ci_2.invoice_number).to eq '319424'
      expect(cil_2.part_number).to eq 'HM-4321'
      expect(ci_2.destination_code).to eq 'West'
      expect(cit_2.hts_code).to eq '2222222222'
      expect(ci_2.mfid).to eq 'BDNIATEX27DHA'
      expect(cil_2.country_origin_code).to eq 'CA'
      expect(cil_2.quantity).to eq 2
      expect(cit_2.classification_qty_1).to eq 3
      expect(cit_2.classification_uom_1).to eq 'ea'
      expect(cit_2.gross_weight).to eq 5
      expect(ci_2.total_quantity).to eq 6
      expect(cil_2.unit_price).to eq 7
      expect(cil_2.currency).to eq 'CAD'
      expect(ci_2.invoice_value_foreign).to eq 8
      expect(cil_2.value_foreign).to eq 9
      expect(ci_2.docs_received_date).to eq Date.parse('2016-09-01')
      expect(ci_2.docs_ok_date).to eq Date.parse('2016-09-02')
      expect(ci_2.issue_codes).to eq 'DCBA'
      expect(ci_2.rater_comments).to eq 'nothing to see here'
      expect(cil_2.line_number).to eq 1
      expect(ci_2.total_quantity_uom).to eq 'CTNS'
      expect(ci_2.importer).to eq co
      # since net wt is > 0
      expect(cit_2.classification_qty_2).to eq 4
      expect(cit_2.classification_uom_2).to eq 'KGS'
    end

    context "with already existing record" do
      let!(:ci) { FactoryBot(:commercial_invoice, importer: co, invoice_number: '424913', destination_code: 'West', mfid: 'ZAGBAFIRIDB', total_quantity: 7, invoice_value_foreign: 9,
                     docs_received_date: '2016-10-02', docs_ok_date: '2016-10-02', issue_codes: 'BADC', rater_comments: 'no comments', total_quantity_uom: 'CTNS') }
      let!(:cil) { FactoryBot(:commercial_invoice_line, commercial_invoice: ci, part_number: 'HM-1234' , country_origin_code: 'UK', quantity: 3, unit_price: 8, currency: 'GBP', value_foreign: 10, line_number: 1) }
      let!(:cit) { FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: cil, hts_code: '3333333333', gross_weight: 6, classification_qty_2: nil, classification_uom_2: nil) }

      it "adds POs with an existing PO number but a different fingerprint" do
        allow(cf).to receive(:path).and_return "file.xlsx"
        handler = described_class.new cf
        expect(handler).to receive(:foreach).with(cf, skip_headers: true).and_yield(row_1, 1)
        expect(handler.process_excel cf).to be_empty

        ci_2 = CommercialInvoice.last
        cil_2 = ci_2.commercial_invoice_lines.last
        cit_2 = cil_2.commercial_invoice_tariffs.last

        expect(ci_2.invoice_number).to eq '424913'
        expect(cil_2.part_number).to eq 'HM-1234'
        expect(ci_2.destination_code).to eq 'East'
        expect(cit_2.hts_code).to eq '1111111111'
        expect(ci_2.mfid).to eq 'BDIRIFABGAZ'
        expect(cil_2.country_origin_code).to eq 'US'
        expect(cil_2.quantity).to eq 1
        expect(cit_2.classification_qty_1).to eq 2
        expect(cit_2.classification_uom_1).to eq 'ea'
        expect(cit_2.gross_weight).to eq 4
        expect(ci_2.total_quantity).to eq 5
        expect(cil_2.unit_price).to eq 6
        expect(cil_2.currency).to eq 'USD'
        expect(ci_2.invoice_value_foreign).to eq 7
        expect(cil_2.value_foreign).to eq 8
        expect(ci_2.docs_received_date).to eq Date.parse('2016-08-01')
        expect(ci_2.docs_ok_date).to eq Date.parse('2016-08-02')
        expect(ci_2.issue_codes).to eq 'ABCD'
        expect(ci_2.rater_comments).to eq 'no comment'
        expect(cil_2.line_number).to eq 1
        expect(ci_2.total_quantity_uom).to eq 'CTNS'
        expect(ci_2.importer).to eq co
        # since net wt = 0
        expect(cit_2.classification_qty_2).to be_nil
        expect(cit_2.classification_uom_2).to be_nil
      end

      it "ignores POs with an existing PO number and the same fingerprint" do
        ci.update_attributes(invoice_value_foreign: 7, docs_received_date: '2016-08-01')
        ci_copy = ci.dup
        cil_copy = cil.dup
        cit_copy = cit.dup

        allow(cf).to receive(:path).and_return "file.xlsx"
        handler = described_class.new cf
        expect(handler).to receive(:foreach).with(cf, skip_headers: true).and_yield(row_1, 1)
        expect(handler.process_excel cf).to be_empty

        ci_2 = CommercialInvoice.last
        cil_2 = ci_2.commercial_invoice_lines.last
        cit_2 = cil_2.commercial_invoice_tariffs.last
        expect(CommercialInvoice.count).to eq 1

        expect(ci_2.invoice_number).to eq ci_copy.invoice_number
        expect(cil_2.part_number).to eq cil_copy.part_number
        expect(ci_2.destination_code).to eq ci_copy.destination_code
        expect(cit_2.hts_code).to eq cit_copy.hts_code
        expect(ci_2.mfid).to eq ci_copy.mfid
        expect(cil_2.country_origin_code).to eq cil_copy.country_origin_code
        expect(cil_2.quantity).to eq cil_copy.quantity
        expect(cit_2.classification_qty_1).to eq cit_copy.classification_qty_1
        expect(cit_2.classification_uom_1).to eq cit_copy.classification_uom_1
        expect(cit_2.gross_weight).to eq cit_copy.gross_weight
        expect(ci_2.total_quantity).to eq ci_copy.total_quantity
        expect(cil_2.unit_price).to eq cil_copy.unit_price
        expect(cil_2.currency).to eq cil_copy.currency
        expect(ci_2.invoice_value_foreign).to eq ci_copy.invoice_value_foreign
        expect(cil_2.value_foreign).to eq cil_copy.value_foreign
        expect(ci_2.docs_received_date).to eq ci_copy.docs_received_date
        expect(ci_2.docs_ok_date).to eq ci_copy.docs_ok_date
        expect(ci_2.issue_codes).to eq ci_copy.issue_codes
        expect(ci_2.rater_comments).to eq ci_copy.rater_comments
        expect(cil_2.line_number).to eq cil_copy.line_number
        expect(ci_2.total_quantity_uom).to eq ci_copy.total_quantity_uom
        expect(ci_2.importer).to eq ci_copy.importer
        # since net wt = 0
        expect(cit_2.classification_qty_2).to eq cit_copy.classification_qty_2
        expect(cit_2.classification_uom_2).to eq cit_copy.classification_uom_2
      end

      it "doesn't generate errors when encountering blank fingerprint values in the db" do
        ci.update_attributes(invoice_value_foreign: nil, docs_received_date: nil)
        cil.update_attributes(part_number: nil)
        allow(cf).to receive(:path).and_return "file.xlsx"
        handler = described_class.new cf
        expect(handler).to receive(:foreach).with(cf, skip_headers: true).and_yield(row_1, 1)
        expect_any_instance_of(Exception).to_not receive(:log_me)
        handler.process_excel cf
      end

      it "doesn't generate error when encountering blank fingerprint values in the upload" do
        row_1[1] = row_1[14] = row_1[16] = ''
        allow(cf).to receive(:path).and_return "file.xlsx"
        handler = described_class.new cf
        expect(handler).to receive(:foreach).with(cf, skip_headers: true).and_yield(row_1, 1)
        expect_any_instance_of(Exception).to_not receive(:log_me)
        handler.process_excel cf
      end

    end

    it "returns an error if custom file has wrong extension" do
      allow(cf).to receive(:path).and_return "file.csv"
      handler = described_class.new cf
      expect(handler.process_excel(cf)[:fixable]).to eq ["No CI Upload processor exists for .csv file types."]
      expect(CommercialInvoice.count).to eq 0
    end

    it "returns an error if row has bad PO number" do
      allow(cf).to receive(:path).and_return "file.xlsx"
      handler = described_class.new cf
      row_1[0] = "123"
      expect(handler).to receive(:foreach).with(cf, skip_headers: true).and_yield(row_1, 1)
      expect(handler.process_excel(cf)[:fixable]).to eq ["PO number has wrong format at row 2!"]
      expect(CommercialInvoice.count).to eq 0
    end

    it "returns an error if row has bad HTS" do
      allow(cf).to receive(:path).and_return "file.xlsx"
      handler = described_class.new cf
      row_1[3] = "123"
      expect(handler).to receive(:foreach).with(cf, skip_headers: true).and_yield(row_1, 1)
      expect(handler.process_excel(cf)[:fixable]).to eq ["Tariff number has wrong format at row 2!"]
      expect(CommercialInvoice.count).to eq 0
    end

    it "returns any exceptions thrown by #parse_row!" do
      allow(cf).to receive(:path).and_return "file.xlsx"
      handler = described_class.new cf
      expect(handler).to receive(:foreach).with(cf, skip_headers: true).and_yield(row_1, 1)
      e = StandardError.new "ERROR!!"
      expect(handler).to receive(:parse_row!).and_raise e
      expect(e).to receive(:log_me)
      expect(handler.process_excel(cf)[:unexpected]).to eq ["Unrecoverable errors were encountered while processing this file. These errors have been forwarded to the IT department and will be resolved.", "ERROR!!"]
      expect(CommercialInvoice.count).to eq 0
    end

  end
end