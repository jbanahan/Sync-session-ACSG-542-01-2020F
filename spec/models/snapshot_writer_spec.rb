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
      FactoryBot(:entry, broker_reference: "ABC", arrival_date: ActiveSupport::TimeZone["UTC"].now, total_fees: BigDecimal.new("1.50"), export_date: Time.zone.now.to_date, paperless_release: true, import_country: FactoryBot(:country))
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
      CoreModule::ENTRY.model_fields {|mf| !mf.history_ignore? }.each_value do |mf|
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
        FactoryBot(:commercial_invoice, entry: entry, invoice_number: "INV")
      }

      let (:invoice_2) {
        FactoryBot(:commercial_invoice, entry: entry, invoice_number: "INV2")
      }

      let (:broker_invoice) {
        FactoryBot(:broker_invoice, entry: entry, invoice_number: "BROK")
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
          FactoryBot(:commercial_invoice_line, commercial_invoice: invoice, po_number: "PO")
        }

        let (:broker_invoice_line) {
          FactoryBot(:broker_invoice_line, broker_invoice: broker_invoice)
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

    context "with linked core module's descriptor" do
      let (:descriptor_repository) {
        { Folder => CoreModule::FOLDER.snapshot_descriptor }
      }
      let (:linked_descriptor) {
        SnapshotDescriptor.for(Entry, {
          folders: {descriptor: Folder }
        }, descriptor_repository: descriptor_repository )
      }

      let (:user) {
        FactoryBot(:user)
      }

      let (:entry) {
        e = FactoryBot(:entry, broker_reference: "ABC")
        folder = e.folders.create! name: "Folder", created_by: user
        folder.comments.create! subject: "Comment", user: user
        folder.attachments.create! attached_file_name: "Filename.txt"

        e
      }

      it "creates snapshot with fields from linked core module descriptor" do
        json = subject.entity_json linked_descriptor, entry

        h = ActiveSupport::JSON.decode(json)['entity']
        expect(h['record_id']).to eq entry.id

        folder_child = h['children'].first['entity']
        expect(folder_child).not_to be_nil

        folder = entry.folders.first
        expect(folder_child['record_id']).to eq folder.id
        expect(folder_child['model_fields']['fld_name']).to eq folder.name

        # The order the children are built in the json is defined in the snapshot descriptor - See CoreModuleDefinitions for folder's order
        folder_attachment = folder.attachments.first
        attachment_child = folder_child['children'].first['entity']
        expect(attachment_child['record_id']).to eq folder_attachment.id
        expect(attachment_child['model_fields']['att_file_name']).to eq folder_attachment.attached_file_name

        folder_comment = folder.comments.first
        comment_child = folder_child['children'].second['entity']
        expect(comment_child['record_id']).to eq folder_comment.id
        expect(comment_child['model_fields']['cmt_subject']).to eq "Comment"
      end
    end
  end

  shared_examples 'SnapshotWriter#field_value' do
    let (:entry) { Entry.new broker_reference: "12345", release_date: ActiveSupport::TimeZone["UTC"].parse("2017-02-24 12:00"), duty_due_date: Date.new(2017, 2, 23), master_bills_of_lading: "A\n B", total_fees: BigDecimal("10.50"), paperless_release: true, pay_type: 1}

    {ent_brok_ref: "12345", ent_release_date: Time.zone.parse("2017-02-24 12:00"), ent_duty_due_date: Date.new(2017, 2, 23), ent_mbols: "A\n B", ent_total_fees: BigDecimal("10.50"), ent_paperless_release: true,  ent_pay_type: 1, ent_cust_num: nil}.each_pair do |k, v|
      it "returns process_export value for object and field #{k}" do
        expect(subject.field_value entry, ModelField.find_by_uid(k)).to eq v
      end
    end

    context "using json_string option" do
      {ent_brok_ref: "12345", ent_release_date: "2017-02-24T12:00:00Z", ent_duty_due_date: "2017-02-23", ent_mbols: "A\\n B", ent_total_fees: "10.5", ent_paperless_release: "true",  ent_pay_type: "1", ent_cust_num: nil}.each_pair do |k, v|
        it "returns process_export value for object and field #{k}" do
          expect(subject.field_value entry, ModelField.find_by_uid(k), json_string: true).to eq v
        end
      end
    end

    it "converts all datetime values to UTC timezone" do
      expect(subject.field_value Entry.new(release_date: ActiveSupport::TimeZone["America/New_York"].parse("2017-02-24 12:00")), ModelField.find_by_uid(:ent_release_date)).to eq "2017-02-24T17:00:00Z"
    end
  end

  describe "field_value" do
    it_behaves_like "SnapshotWriter#field_value"
  end

  describe "self.field_value" do
    subject {described_class}

    it_behaves_like "SnapshotWriter#field_value"
  end

end