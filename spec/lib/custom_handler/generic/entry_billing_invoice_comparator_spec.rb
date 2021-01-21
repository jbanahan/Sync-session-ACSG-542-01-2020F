describe OpenChain::CustomHandler::Generic::EntryBillingInvoiceComparator do

  describe "accept?" do
    let (:entry) do
      e = Factory(:entry, customer_number: "KRAANG")
      e.broker_invoices.build
      e
    end

    let (:snapshot) { EntitySnapshot.new recordable: entry }

    it "accepts entry of group member customer with broker invoices" do
      make_xref
      expect(described_class.accept?(snapshot)).to eq true
    end

    def make_xref
      DataCrossReference.create!(cross_reference_type: DataCrossReference::BILLING_INVOICE_CUSTOMERS, key: "KRAANG")
    end

    it "rejects entry of group member customer without broker invoices" do
      make_xref
      entry.broker_invoices.destroy_all

      expect(described_class.accept?(snapshot)).to eq false
    end

    it "rejects entry of non-group member customer with broker invoices" do
      expect(described_class.accept?(snapshot)).to eq false
    end

    it "rejects non-entry" do
      expect(described_class.accept?(EntitySnapshot.new(recordable: BrokerInvoice.new))).to eq false
    end
  end

  describe "compare" do
    it "generates XMLs for broker invoices added to an updated entry" do
      entry = Factory(:entry)
      bi_1 = entry.broker_invoices.create! invoice_number: "ABC"
      bi_2 = entry.broker_invoices.create! invoice_number: "DEF"
      bi_3 = entry.broker_invoices.create! invoice_number: "GHI"

      old_snapshot =
        {
          "entity" => {
            "core_module" => "Entry",
            "children" => [
              {
                "entity" => {
                  "core_module" => "BrokerInvoice",
                  "record_id" => bi_1.id
                }
              }
            ]
          }
        }

      new_snapshot =
        {
          "entity" => {
            "core_module" => "Entry",
            "children" => [
              {
                "entity" => {
                  "core_module" => "BrokerInvoice",
                  "record_id" => bi_1.id
                }
              },
              {
                "entity" => {
                  "core_module" => "BrokerInvoice",
                  "record_id" => bi_2.id
                }
              },
              {
                "entity" => {
                  "core_module" => "BrokerInvoice",
                  "record_id" => bi_3.id
                }
              }
            ]
          }
        }

      expect_any_instance_of(described_class).to receive(:get_json_hash).with("old_bucket", "old_path", "old_version").and_return old_snapshot
      expect_any_instance_of(described_class).to receive(:get_json_hash).with("new_bucket", "new_path", "new_version").and_return new_snapshot
      generator = instance_double("generator")
      expect_any_instance_of(described_class).to receive(:generator).twice.and_return(generator)
      expect(generator).to receive(:generate_and_send).with(bi_2)
      expect(generator).to receive(:generate_and_send).with(bi_3)
      expect(generator).not_to receive(:generate_and_send).with(bi_1)

      described_class.compare nil, entry.id, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version"
    end

    it "generates XML for the broker invoice on a new entry" do
      entry = Factory(:entry)
      bi = entry.broker_invoices.create! invoice_number: "ABC"

      new_snapshot =
        {
          "entity" => {
            "core_module" => "Entry",
            "children" => [
              {
                "entity" => {
                  "core_module" => "BrokerInvoice",
                  "record_id" => bi.id
                }
              }
            ]
          }
        }

      expect_any_instance_of(described_class).to receive(:get_json_hash).with("old_bucket", "old_path", "old_version").and_return({})
      expect_any_instance_of(described_class).to receive(:get_json_hash).with("new_bucket", "new_path", "new_version").and_return new_snapshot
      generator = instance_double("generator")
      expect_any_instance_of(described_class).to receive(:generator).and_return(generator)
      expect(generator).to receive(:generate_and_send).with(bi)

      described_class.compare nil, entry.id, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version"
    end
  end

end