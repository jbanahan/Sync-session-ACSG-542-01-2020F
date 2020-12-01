describe OpenChain::CustomHandler::LumberLiquidators::LumberSupplementalInvoiceSender do

  describe "run_schedulable" do
    let (:synced_entry) {
      entry = FactoryBot(:entry)
      entry.sync_records.create! trading_partner: OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport.sync_code, sent_at: Time.zone.now
      entry
    }

    let (:invoice) { FactoryBot(:broker_invoice, entry: synced_entry, customer_number: "LUMBER", source_system: "Alliance", invoice_number:"123456A", suffix: "A", invoice_date: Date.new(2016, 3, 21)) }
    let (:first_invoice) { FactoryBot(:broker_invoice, entry: synced_entry, customer_number: "LUMBER", invoice_number:"123456", invoice_date: Date.new(2016, 3, 21)) }
    let (:synced_invoice) {
      i = FactoryBot(:broker_invoice, entry: synced_entry, customer_number: "LUMBER", invoice_number:"123456B", suffix: "B", invoice_date: Date.new(2016, 3, 21))
      i.sync_records.create! trading_partner: "LL SUPPLEMENTAL", sent_at: Time.zone.now
      i
    }
    let (:not_lumber_invoice) { FactoryBot(:broker_invoice, entry: synced_entry, customer_number: "NOTLUMBER", invoice_number:"987654A", suffix: "A", invoice_date: Date.new(2016, 3, 21)) }

    before :each do
      invoice
      first_invoice
      synced_invoice
      not_lumber_invoice
      stub_master_setup
    end

    it "sends supplemental lumber invoices that have not been synced yet" do
      described_class.run_schedulable

      invoice.reload
      expect(invoice.sync_records.length).to eq 1
      sr = invoice.sync_records.first
      expect(sr.sent_at).to be_within(1.minute).of Time.zone.now
      expect(sr.confirmed_at).to be_within(2.minute).of Time.zone.now
      expect(sr.trading_partner).to eq "LL SUPPLEMENTAL"

      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["otwap@lumberliquidators.com"]
      expect(m.bcc).to eq ["payments@vandegriftinc.com"]
      expect(m.subject).to eq "Supplemental Invoice 123456A"
      expect(m.body.raw_source).to include "Attached is the supplemental invoice # 123456A."

      wb = Spreadsheet.open(StringIO.new(m.attachments["VFI Supplemental Invoice 123456A.xls"].read))
      sheet = wb.worksheet "123456A"
      # Just make sure the sheet has the correct invoice number in it, in the expected
      # location.  Everything else about the sheet is tested in the spec for the summary page's module
      expect(sheet.row(4)[0]).to eq "123456A"
    end

    it "does not send invoices that were included on the cost file" do
      invoice.sync_records.create! trading_partner: OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport.sync_code, sent_at: Time.zone.now
      described_class.run_schedulable
      invoice.reload
      expect(invoice.sync_records.map(&:trading_partner)).not_to include "LL SUPPLEMENTAL"
    end

    it "does not send invoices where a cost file has not been created" do
      invoice.entry.sync_records.destroy_all
      described_class.run_schedulable
      invoice.reload
      expect(invoice.sync_records.map(&:trading_partner)).not_to include "LL SUPPLEMENTAL"
    end

    it "does not send invoices for entries with failed business rules" do
      invoice.entry.business_validation_results.create! state: "Fail"

      described_class.run_schedulable
      invoice.reload
      expect(invoice.sync_records.length).to eq 0
      expect(ActionMailer::Base.deliveries.length).to eq 0
    end
  end
end