describe EntitySnapshot, :snapshot do

  let (:user) { create(:user) }

  describe "diff" do

    it "should return empty diff for identical snapshots" do
      ol = create(:order_line)
      o = ol.order
      s = EntitySnapshot.create_from_entity o, user
      s2 = EntitySnapshot.create_from_entity o, user
      diff = s2.diff s
      expect(diff.record_id).to eq o.id
      expect(diff.core_module).to eq 'Order'
      expect(diff.model_fields_changed).to be_empty
      expect(diff.children_added).to be_empty
      expect(diff.children_deleted).to be_empty

      cib = diff.children_in_both
      expect(cib.size).to eq 1
      expect(cib.first.record_id).to eq ol.id
      expect(cib.first.model_fields_changed).to be_empty
    end
    it "should reflect changed field" do
      o = create(:order)
      old_order_number = o.order_number
      new_order_number = "#{o.order_number}X"

      s = EntitySnapshot.create_from_entity o, user
      o.update_attributes(order_number:new_order_number)
      s2 = EntitySnapshot.create_from_entity o, user
      diff = s2.diff s

      expect(diff.model_fields_changed['ord_ord_num']).to eq [old_order_number, new_order_number]
    end
    it "should reflect added child" do
      o = create(:order)
      s = EntitySnapshot.create_from_entity o, user
      ol = create(:order_line, order:o)
      o.reload
      s2 = EntitySnapshot.create_from_entity o, user
      diff = s2.diff s

      expect(diff.children_added.size).to eq 1
      ca = diff.children_added.first
      expect(ca.record_id).to eq ol.id
      expect(ca.model_fields_changed['ordln_line_number'][1]).to eq ol.line_number
    end
    it "should reflect deleted child" do
      ol = create(:order_line)
      o = ol.order
      s = EntitySnapshot.create_from_entity o, user
      ol.destroy
      o.reload
      s2 = EntitySnapshot.create_from_entity o, user
      diff = s2.diff s

      expect(diff.children_deleted.size).to eq 1
      cd = diff.children_deleted.first
      expect(cd.record_id).to eq ol.id
      expect(cd.model_fields_changed['ordln_line_number'][0]).to eq ol.line_number
    end
    it "should reflect field changed in child" do
      ol = create(:order_line)
      old_line_number = ol.line_number
      new_line_number = old_line_number + 1
      o = ol.order
      s = EntitySnapshot.create_from_entity o, user
      ol.update_attributes(line_number:new_line_number)
      o.reload
      s2 = EntitySnapshot.create_from_entity o, user
      diff = s2.diff s

      expect(diff.children_in_both.size).to eq 1
      cib = diff.children_in_both.first
      expect(cib.model_fields_changed['ordln_line_number']).to eq [old_line_number, new_line_number]
    end
    it "should reflect child with new id and same logical key as update not add/delete" do
      ol = create(:order_line, hts:'123456')
      line_number = ol.line_number
      o = ol.order
      s = EntitySnapshot.create_from_entity o, user
      ol.destroy
      ol = create(:order_line, order:o, line_number:line_number, hts:'654321')
      o.reload
      s2 = EntitySnapshot.create_from_entity o, user
      diff = s2.diff s

      expect(diff.children_in_both.size).to eq 1
      cib = diff.children_in_both.first
      expect(cib.model_fields_changed['ordln_hts']).to eq ['123456'.hts_format, '654321'.hts_format]
    end

    it "returns datetimes as date time objects (not strings)" do
      e = Entry.new release_date: Time.zone.parse("2017-04-01 12:00")
      s1 = EntitySnapshot.create_from_entity e, user

      e.release_date = Time.zone.parse("2017-04-01 16:00")
      s2 = EntitySnapshot.create_from_entity e, user

      diff = s2.diff s1
      expect(diff.model_fields_changed["ent_release_date"]).to eq [Time.zone.parse("2017-04-01 12:00"), Time.zone.parse("2017-04-01 16:00") ]
    end

    it "does not identify blank string changed to/from nil as a diff" do
      o = create(:order)
      s1 = EntitySnapshot.create_from_entity o, user

      o.customer_order_number = ""
      s2 = EntitySnapshot.create_from_entity o, user

      diff = s2.diff s1
      expect(diff.model_fields_changed.size).to eq 0
    end
  end

  describe "restore" do
    before :each do
      ModelField.reload
      # not worrying about permissions
      allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)

      @p = create(:product, :name=>'nm', :unique_identifier=>'uid')
      @tr = create(:tariff_record, :hts_1=>'1234567890', :classification=>create(:classification, :product=>@p))
      @first_snapshot = @p.create_snapshot user
    end
    it "should replace base object properties" do
      @p.update_attributes(:name=>'n2')
      restored = @first_snapshot.restore(user)
      expect(restored.id).to eq(@p.id)
      expect(restored.name).to eq('nm')
    end
    it "should erase base object properties that have been added" do
      @p.update_attributes(:unit_of_measure=>'EA')
      restored = @first_snapshot.restore(user)
      expect(restored.id).to eq(@p.id)
      expect(restored.unit_of_measure).to be_blank
    end
    it "should insert base object properties that have been removed" do
      @p.update_attributes(:name=>nil)
      restored = @first_snapshot.restore(user)
      expect(restored.id).to eq(@p.id)
      expect(restored.name).to eq('nm')
    end
    it "should leave base object properties that haven't changed alone" do
      @p.update_attributes(:unit_of_measure=>'EA')
      restored = @first_snapshot.restore(user)
      expect(restored.id).to eq(@p.id)
      expect(restored.name).to eq('nm')
    end
    it "should update last_updated_by_id" do
      other_user = create(:user)
      restored = @first_snapshot.restore(other_user)
      expect(restored.last_updated_by_id).to eq(other_user.id)
    end
    it "should not restore if user does not have permission" do
      @p.update_attributes! last_updated_by: user
      allow_any_instance_of(Product).to receive(:can_edit?).and_return(false)
      @p.update_attributes(:name=>'n2')
      other_user = create(:user)
      restored = @first_snapshot.restore(user)
      expect(restored.last_updated_by_id).to eq(user.id)
      expect(restored.name).to eq('n2')
    end

    context "custom_values" do
      context "with standard custom field" do

        before :each do
          @cd = create(:custom_definition, :module_type=>'Product', :data_type=>'string')
          ModelField.reload
          @p.update_custom_value! @cd, 'x'
          @first_snapshot = @p.create_snapshot user
        end

        it "should replace custom fields" do
          @p.update_custom_value! @cd, 'y'
          restored = @first_snapshot.restore(user)
          expect(restored.get_custom_value(@cd).value).to eq('x')
        end
        it "should erase custom fields that have been added" do
          cd2 = create(:custom_definition, :module_type=>'Product', :data_type=>'string')
          @p.update_custom_value! cd2, 'y'
          restored = @first_snapshot.restore(user)
          expect(restored.get_custom_value(cd2).value).to be_blank
        end
        it "should insert custom fields that have been removed" do
           @p.get_custom_value(@cd).destroy
          restored = @first_snapshot.restore(user)
          expect(restored.get_custom_value(@cd).value).to eq('x')
        end
        it "should leave custom fields that haven't changed alone" do
          restored = @first_snapshot.restore(user)
          expect(restored.get_custom_value(@cd).value).to eq('x')
        end
      end

      context "with special custom fields" do
        it "handles user custom value fields" do
          user_def = create(:custom_definition, label: "Tested By", module_type: "Product", data_type: 'integer', is_user: true)
          ModelField.reload
          @p.update_custom_value! user_def, user
          snapshot = @p.create_snapshot user
          user2 = create(:user)
          @p.update_custom_value! user_def, user2
          snapshot.restore user
          @p.reload
          expect(@p.custom_value(user_def)).to eq user.id
        end

        it "handles address fields" do
          addr_def = create(:custom_definition, label: "Testing Address", module_type: "Product", data_type: 'integer', is_address: true)
          ModelField.reload

          address = create(:full_address)
          address_2 = create(:full_address)

          @p.update_custom_value! addr_def, address
          snapshot = @p.create_snapshot user
          @p.update_custom_value! addr_def, address_2

          snapshot.restore user
          @p.reload
          expect(@p.custom_value(addr_def)).to eq address.id
        end
      end

    end

    context "children" do
      it "should add children that were removed" do
        @p.classifications.first.destroy
        restored = @first_snapshot.restore user
        expect(restored.classifications.first.tariff_records.first.hts_1).to eq('1234567890')
      end
      it "should remove children that didn't exist" do
        p = create(:product)
        es = p.create_snapshot user
        create(:tariff_record, :classification=>(create(:classification, :product=>p)))
        p.reload
        expect(p.classifications.first.tariff_records.first).not_to be_nil
        es.restore user
        p.reload
        expect(p.classifications.first).to be_nil
      end
      it "should replace values in children that changed" do
        @tr.update_attributes(:hts_1=>'1234')
        @first_snapshot.restore user
        expect(TariffRecord.find(@tr.id).hts_1).to eq('1234567890')
      end
      it "should replace custom values for children that changed" do
        cd = create(:custom_definition, :module_type=>"Classification", :data_type=>"string")
        @tr.classification.update_custom_value! cd, 'x'
        @first_snapshot = @p.create_snapshot user
        @tr.classification.update_custom_value! cd, 'y'
        restored = @first_snapshot.restore user
        expect(restored.classifications.first.get_custom_value(cd).value).to eq('x')
      end

      it "should skip child records with blank record ids" do
        j = @first_snapshot.snapshot_json
        j['entity']['children'][0]['entity']['record_id'] = nil
        @first_snapshot.snapshot = j.to_json
        restored = @first_snapshot.restore user
        expect(restored.classifications.size).to eq 0
      end
    end

    it "retrieves snapshot data from snapshot field if it is not null" do
      first_snapshot = @first_snapshot.snapshot_json
      @first_snapshot.update_attributes! snapshot: ActiveSupport::JSON.encode(first_snapshot)
      expect(EntitySnapshot).not_to receive(:retrieve_snapshot_data_from_s3)

      restored = @first_snapshot.restore (user)
      expect(restored).to eq @p
      expect(restored.name).to eq "nm"
    end
  end

  describe "bucket_name" do
    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:system_code).and_return 'syscode'
      ms
    }
    it "should append env.system_code.snapshots.vfitrack.net" do
      env = Rails.env
      expect(EntitySnapshot.bucket_name).to eq "#{env}.syscode.snapshots.vfitrack.net"
    end
    it "should raise error if longer than 63 characters (AWS limit)" do
      allow(master_setup).to receive(:system_code).and_return '123456789012345678901234567890123456789012345678901234567890'
      expect {EntitySnapshot.bucket_name}.to raise_error(/Bucket name too long/)
    end
  end
  describe "create_bucket_if_needed" do
    before :each do
      @bn = 'bucketname'
      allow(EntitySnapshot).to receive(:bucket_name).and_return(@bn)
    end
    it "should find existing bucket" do
      expect(OpenChain::S3).to receive(:bucket_exists?).with(@bn).and_return true
      expect(OpenChain::S3).not_to receive(:create_bucket!)
      described_class.create_bucket_if_needed!
    end
    it "should create bucket with versioning turned on" do
      expect(OpenChain::S3).to receive(:bucket_exists?).with(@bn).and_return false
      expect(OpenChain::S3).to receive(:create_bucket!).with(@bn, versioning: true)
      described_class.create_bucket_if_needed!
    end
  end

  describe "create_from_entity" do
    it "should write S3 file at logical path" do
      expected_path = '/my/path'
      expected_bucket = 'bucket'
      expected_version = 'ABC123'
      expected_json = '{"a":"b"}'
      ent = create(:entry)
      u = create(:user)
      allow(CoreModule::ENTRY).to receive(:entity_json).and_return(expected_json)
      expect(described_class).to receive(:write_to_s3).with(expected_json, ent).and_return({bucket: expected_bucket, key: expected_path, version: expected_version})

      es = EntitySnapshot.create_from_entity(ent, u)
      expect(es.bucket).to eq expected_bucket
      expect(es.doc_path).to eq expected_path
      expect(es.version).to eq expected_version
      expect(es.compared_at).to be_nil
      expect(es.change_record_id).to be_nil
      expect(es.imported_file_id).to be_nil
      expect(es.context).to be_nil
    end

    it "should include imported file and context if provided" do
      expected_path = '/my/path'
      expected_bucket = 'bucket'
      expected_version = 'ABC123'
      expected_json = '{"a":"b"}'
      ent = create(:entry)
      u = create(:user)
      imp = create(:imported_file)
      cont = '21st Century Capitalism'
      allow(CoreModule::ENTRY).to receive(:entity_json).and_return(expected_json)
      expect(described_class).to receive(:write_to_s3).with(expected_json, ent).and_return({bucket: expected_bucket, key: expected_path, version: expected_version})

      es = EntitySnapshot.create_from_entity(ent, u, imp, cont)
      expect(es.bucket).to eq expected_bucket
      expect(es.doc_path).to eq expected_path
      expect(es.version).to eq expected_version
      expect(es.compared_at).to be_nil
      expect(es.change_record_id).to be_nil
      expect(es.imported_file_id).to eq imp.id
      expect(es.context).to eq cont
    end

    it "should call EntityCompare.handle_snapshot with snapshot" do
      allow_any_instance_of(described_class).to receive(:write_s3)
      expect(OpenChain::EntityCompare::EntityComparator).to receive(:handle_snapshot)

      ent = create(:entry)
      u = create(:user)
      es = EntitySnapshot.create_from_entity(ent, u)
    end

    context "with business validations" do
      let! (:bvt) {
        bvt = create(:business_validation_template, module_type: "Entry")
        bvt.search_criterions.create!(model_field_uid:'ent_cust_num', operator:'eq', value:'12345')
        bvt.business_validation_rules.create!( name: "Name", description: "Description", type:'ValidationRuleFieldFormat', rule_attributes_json:{model_field_uid:'ent_entry_num', regex:'X'}.to_json)
        bvt.reload
      }
      let (:entry) { create(:entry, customer_number: "12345") }
      let (:user) { create(:user) }

      it "runs business validations" do
        EntitySnapshot.create_from_entity entry, user
        expect(entry.business_rules("Fail").length).to eq 1
      end
    end

    it "writes snapshot failure when uploads to s3 fail" do
      expect_any_instance_of(described_class).to receive(:write_s3) do |inst, json|
        raise Exception, "Error"
      end
      expect(OpenChain::EntityCompare::EntityComparator).not_to receive(:handle_snapshot)

      ent = create(:entry)
      u = create(:user)
      es = EntitySnapshot.create_from_entity(ent, u)

      failure = EntitySnapshotFailure.where(snapshot_id: es.id, snapshot_type: "EntitySnapshot").first
      expect(failure.snapshot_json).to eq described_class.snapshot_writer.entity_json(ent)
    end
  end

  describe "expected_s3_path" do
    it "should be core module / recordable.id" do
      ent = create(:entry)
      es = EntitySnapshot.new
      es.recordable = ent
      expect(es.expected_s3_path).to eq "entry/#{ent.id}.json"
    end
  end

  describe "retrieve_snapshot_data_from_s3" do
    let (:snapshot) {
      EntitySnapshot.new bucket: "bucket", doc_path: "test/doc-1.json", version: "1"
    }

    it "retrieves versioned data for snapshot" do
      expect(OpenChain::S3).to receive(:get_versioned_data).with("bucket", "test/doc-1.json", "1").and_return "Testing"

      expect(EntitySnapshot.retrieve_snapshot_data_from_s3 snapshot).to eq "Testing"
    end
  end

  describe "snapshot_json" do
    let (:json) {  }

    before :each do
      allow(EntitySnapshot).to receive(:retrieve_snapshot_data_from_s3).and_return json
    end

    it "retrieves snapshot from s3" do
      s = EntitySnapshot.new doc_path: "path/to/file.txt"
      expect(EntitySnapshot).to receive(:retrieve_snapshot_data_from_s3).with(s).and_return '{"OK": "OK"}'
      expect(s.snapshot_json).to eq({"OK" => "OK"})
    end

    it "retrieves snapshot from snapshot attribute" do
      s = EntitySnapshot.new snapshot: '{"OK": ""}'
      expect(EntitySnapshot).not_to receive(:retrieve_snapshot_data_from_s3)
      expect(s.snapshot_json).to eq({"OK"=> ""})
    end

    it "returns raw json" do
      s = EntitySnapshot.new doc_path: "path/to/file.txt"
      expect(EntitySnapshot).to receive(:retrieve_snapshot_data_from_s3).with(s).and_return '{"OK": "OK"}'
      expect(s.snapshot_json(true)).to eq '{"OK": "OK"}'
    end

    it "returns nil if json is blank" do
      s = EntitySnapshot.new doc_path: "path/to/file.txt"
      expect(EntitySnapshot).to receive(:retrieve_snapshot_data_from_s3).with(s).and_return '     '
      expect(s.snapshot_json(true)).to be_nil
    end
  end

  describe "store_snapshot_json" do
    let (:snapshot) { EntitySnapshot.new recordable: create(:entry), user: create(:user)}

    it "writes snapshot json data to s3" do
      expect(snapshot).to receive(:write_s3).with "json"

      expect(described_class.store_snapshot_json snapshot, "json").to eq true
    end

    it "creates a snapshot failure record if write fails" do
      snapshot.save!
      expect(snapshot).to receive(:write_s3).and_raise Exception, "Failed"

      expect(described_class.store_snapshot_json snapshot, "json").to eq false

      failure = EntitySnapshotFailure.where(snapshot_id: snapshot.id).first
      expect(failure).not_to be_nil
      expect(failure.snapshot_json).to eq "json"
    end

    it "does not save failure record if instructed not to" do
      snapshot.save!
      expect(snapshot).to receive(:write_s3).and_raise Exception, "Failed"

      expect(described_class.store_snapshot_json snapshot, "json", record_failure: false).to eq false

      expect(EntitySnapshotFailure.where(snapshot_id: snapshot.id).first).to be_nil
    end
  end

  describe "s3_integration_file_context?" do
    it "identifies context by having date followed by /home/ubuntu" do
      subject.context = "2017-04/12/system/parser/file.txt"
      expect(subject.s3_integration_file_context?).to eq true
    end

    it "identifies anything else as not being an integration file" do
      subject.context = "Some Parser"
      expect(subject.s3_integration_file_context?).to eq false
    end
  end

  describe "s3_integration_file_context_download_link" do
    subject {  EntitySnapshot.new context: "2017-04/12/system/parser/file.txt" }

    it "generates an s3 link" do
      expect(OpenChain::S3).to receive(:url_for).with(OpenChain::S3.integration_bucket_name, "2017-04/12/system/parser/file.txt").and_return "url"
      expect(subject.s3_integration_file_context_download_link).to eq "url"
    end

    it "returns blank if context isn't an s3 object" do
      subject.context = "context"
      expect(subject.s3_integration_file_context_download_link).to eq ""
    end
  end

  describe "snapshot_download_link" do

    subject {  EntitySnapshot.new bucket: 'bucket', doc_path: "path/to/file.txt", version: "version" }

    it "generates a link to download the snapshot json" do
      expect(OpenChain::S3).to receive(:url_for).with("bucket", "path/to/file.txt", 1.minute, version: "version").and_return "url"
      expect(subject.snapshot_download_link).to eq "url"
    end
  end

  describe "delete_from_s3" do
    subject { EntitySnapshot.new bucket: "bucket", doc_path: "key", version: "version" }

    before :each do
      allow(subject.class).to receive(:bucket_name).and_return "bucket"
    end

    it "deletes a snapshot from s3" do
      expect(OpenChain::S3).to receive(:delete).with("bucket", "key", "version")
      subject.delete_from_s3
    end

    it "no-ops if bucket is blank" do
      subject.bucket = ""
      expect(OpenChain::S3).not_to receive(:delete)
      subject.delete_from_s3
    end

    it "no-ops if doc_path is blank" do
      subject.doc_path = ""
      expect(OpenChain::S3).not_to receive(:delete)
      subject.delete_from_s3
    end

    it "calls delete_from_s3 in destroy callback" do
      subject.recordable = create(:entry)
      subject.user = create(:user)
      subject.save!

      expect(subject).to receive(:delete_from_s3)
      subject.destroy
    end

    it "does not delete from s3 if bucket doesn't match system's bucket" do
      expect(subject.class).to receive(:bucket_name).and_return "notmybucket"
      expect(OpenChain::S3).not_to receive(:delete)

      subject.delete_from_s3
    end
  end

  describe "cleansed_context" do
    it "strips any file paths from context if it looks like an integration file context" do
      subject.context = "2019-09/01/path/to/file.txt"
      expect(subject.cleansed_context).to eq "file.txt"
    end

    it "returns full context if context is not integration file" do
      subject.context = "This is a test"
      expect(subject.cleansed_context).to eq "This is a test"
    end
  end


  describe "ESDiff" do
    let (:product) { create(:product) }

    subject { EntitySnapshot::ESDiff.new }

    before :each do
      subject.record_id = product.id
      subject.core_module = CoreModule::PRODUCT.class_name
    end

    describe "core_module_instance" do
      it "returns core module for ESDiff" do
        expect(subject.core_module_instance).to eq CoreModule::PRODUCT
      end

      it "returns nil if bad core module set" do
        subject.core_module = "NotACoreModule"
        expect(subject.core_module_instance).to be_nil
      end

      it "returns nil if no core module set" do
        subject.core_module = nil
        expect(subject.core_module_instance).to be_nil
      end
    end

    describe "record" do
      it "finds the object that was diffed" do
        expect(subject.record).to eq product
      end

      it "returns nil if core module is blank" do
        subject.core_module = nil
        expect(subject.record).to be_nil
      end

      it "returns nil if invalid core module is used" do
        subject.core_module = "NotAProduct"
        expect(subject.record).to be_nil
      end

      it "returns nil if non-existent record_id is present" do
        subject.record_id = -1
        expect(subject.record).to be_nil
      end
    end
  end
end
