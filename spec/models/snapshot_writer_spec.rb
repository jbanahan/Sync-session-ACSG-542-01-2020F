require 'spec_helper'

describe SnapshotWriter do
  let (:descriptor) {
    SnapshotDescriptor.for(Entry, {
        commercial_invoices: {
          type: CommercialInvoice,
          children: {
            commercial_invoice_lines: {
              type: CommercialInvoiceLine
            }
          }
        },
        broker_invoices: {
          type: BrokerInvoice,
          children: {
            broker_invoice_lines: {
              type: BrokerInvoiceLine
            }
          }
        }
      })
  }

  describe "entity_json" do
    let (:entry) {
      Factory(:entry, broker_reference: "ABC", arrival_date: Time.zone.now, total_fees: BigDecimal.new("1.50"), export_date: Time.zone.now.to_date, paperless_release: true, import_country: Factory(:country))
    }

    it "uses given descriptor and generates snapshot" do
      json = subject.entity_json descriptor, entry
      h = ActiveSupport::JSON.decode json

      expect(h['entity']).not_to be_nil
      h = h['entity']
      expect(h['core_module']).to eq "Entry"
      expect(h['record_id']).to eq entry.id
      expect(h['model_fields']).not_to be_nil
      expect(h['children']).to be_nil
      
      mf_h = h['model_fields']
      # Make sure we have the right number of fields -- then just test one for each 
      # datatype
      count = 0
      CoreModule::ENTRY.model_fields {|mf| !mf.history_ignore? }.values.each do |mf|
        v = mf.process_export entry, nil, true
        next if v.nil?
        count += 1
      end

      expect(mf_h.keys.size).to eq count
      
      expect(mf_h['ent_brok_ref']).to eq "ABC"
      expect(mf_h['ent_arrival_date']).to eq entry.arrival_date.iso8601
      expect(mf_h['ent_total_fees']).to eq "1.5"
      expect(mf_h['ent_export_date']).to eq entry.export_date.iso8601
      expect(mf_h['ent_paperless_release']).to eq true
    end

    it "handles custom fields" do
      # Only need to do one custom field...really this is mostly pointless too since the access to model fields
      # is done through the core_module interface.  It's important enough though that I do want to make sure
      # it's convered in the snapshots
      cd = CustomDefinition.create! module_type: "Entry", label: "Test", data_type: "string"
      entry.update_custom_value! cd, "Testing"

      json = subject.entity_json descriptor, entry
      h = ActiveSupport::JSON.decode json

      expect(h['entity']['model_fields'][cd.model_field_uid]).to eq "Testing"
    end

    it "skips fields marked as history_ignore" do
      json = subject.entity_json descriptor, entry
      h = ActiveSupport::JSON.decode json

      expect(h['entity']['model_fields']['ent_cntry_name']).to be_nil
    end

    context "with children" do
      let (:invoice) {
        Factory(:commercial_invoice, entry: entry, invoice_number: "INV")
      }

      let (:invoice_2) {
        Factory(:commercial_invoice, entry: entry, invoice_number: "INV2")
      }

      let (:broker_invoice) {
        Factory(:broker_invoice, entry: entry, invoice_number: "BROK")
      }

      before :each do
        invoice
        invoice_2
        broker_invoice
        entry.reload
      end

      it "handles children entities" do
        json = subject.entity_json descriptor, entry
        h = ActiveSupport::JSON.decode(json)['entity']

        expect(h['children']).not_to be_nil
        expect(h['children'].length).to eq 3

        expect(h['children'].first['entity']['core_module']).to eq "CommercialInvoice"
        expect(h['children'].first['entity']['record_id']).to eq invoice.id
        expect(h['children'].first['entity']['model_fields']['ci_invoice_number']).to eq "INV"
        expect(h['children'].first['entity']['children']).to be_nil

        expect(h['children'].second['entity']['core_module']).to eq "CommercialInvoice"
        expect(h['children'].second['entity']['record_id']).to eq invoice_2.id
        expect(h['children'].second['entity']['model_fields']['ci_invoice_number']).to eq "INV2"
        expect(h['children'].second['entity']['children']).to be_nil

        expect(h['children'].third['entity']['core_module']).to eq "BrokerInvoice"
        expect(h['children'].third['entity']['record_id']).to eq broker_invoice.id
        expect(h['children'].third['entity']['model_fields']['bi_invoice_number']).to eq "BROK"
        expect(h['children'].third['entity']['children']).to be_nil
      end

      it "raises an error if the given association for the child is bad" do
        descriptor = SnapshotDescriptor.for(Entry, {commercial_in: {type: CommercialInvoice}})
        expect {subject.entity_json descriptor, entry}.to raise_error "No association named commercial_in found in Entry."
      end

      it "raises an error if association name is not given by descriptor" do
        descriptor = SnapshotDescriptor.new(Entry, children: [SnapshotDescriptor.new(CommercialInvoice)])
        expect {subject.entity_json descriptor, entry}.to raise_error "No association name found for Entry class' child CommercialInvoice."
      end

      context "with grandchildren" do
        let (:invoice_line) {
          Factory(:commercial_invoice_line, commercial_invoice: invoice, po_number: "PO")
        }

        let (:broker_invoice_line) {
          Factory(:broker_invoice_line, broker_invoice: broker_invoice)
        }

        before :each do
          invoice_line
          broker_invoice_line
        end

        it "handles grandchildren" do
          json = subject.entity_json descriptor, entry
          h = ActiveSupport::JSON.decode(json)['entity']

          expect(h['children'].first['entity']['children']).not_to be_nil
          expect(h['children'].first['entity']['children'].length).to eq 1
          expect(h['children'].first['entity']['children'].first['entity']['record_id']).to eq invoice_line.id
          expect(h['children'].first['entity']['children'].first['entity']['model_fields']['cil_po_number']).to eq "PO"

          expect(h['children'].second['entity']['children']).to be_nil

          expect(h['children'].third['entity']['children']).not_to be_nil
          expect(h['children'].third['entity']['children'].length).to eq 1
          expect(h['children'].third['entity']['children'].first['entity']['record_id']).to eq broker_invoice_line.id
          expect(h['children'].third['entity']['children'].first['entity']['model_fields']['bi_line_charge_code']).to eq broker_invoice_line.charge_code
        end
      end
    end
  end

end