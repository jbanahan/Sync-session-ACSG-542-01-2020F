require 'spec_helper'

describe EntitySnapshot do

  describe "diff" do
    before :each do
      @u = Factory(:user)
    end

    it "should return empty diff for identical snapshots" do
      ol = Factory(:order_line)
      o = ol.order
      s = EntitySnapshot.create_from_entity o, @u
      s2 = EntitySnapshot.create_from_entity o, @u
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
      o = Factory(:order)
      old_order_number = o.order_number
      new_order_number = "#{o.order_number}X"

      s = EntitySnapshot.create_from_entity o, @u
      o.update_attributes(order_number:new_order_number)
      s2 = EntitySnapshot.create_from_entity o, @u
      diff = s2.diff s
      
      expect(diff.model_fields_changed['ord_ord_num']).to eq [old_order_number,new_order_number]
    end
    it "should reflect added child" do
      o = Factory(:order)
      s = EntitySnapshot.create_from_entity o, @u
      ol = Factory(:order_line,order:o)
      o.reload
      s2 = EntitySnapshot.create_from_entity o, @u
      diff = s2.diff s
      
      expect(diff.children_added.size).to eq 1
      ca = diff.children_added.first
      expect(ca.record_id).to eq ol.id
      expect(ca.model_fields_changed['ordln_line_number'][1]).to eq ol.line_number
    end
    it "should reflect deleted child" do
      ol = Factory(:order_line)
      o = ol.order
      s = EntitySnapshot.create_from_entity o, @u
      ol.destroy
      o.reload
      s2 = EntitySnapshot.create_from_entity o, @u
      diff = s2.diff s

      expect(diff.children_deleted.size).to eq 1
      cd = diff.children_deleted.first
      expect(cd.record_id).to eq ol.id
      expect(cd.model_fields_changed['ordln_line_number'][0]).to eq ol.line_number
    end
    it "should reflect field changed in child" do
      ol = Factory(:order_line)
      old_line_number = ol.line_number
      new_line_number = old_line_number + 1
      o = ol.order
      s = EntitySnapshot.create_from_entity o, @u
      ol.update_attributes(line_number:new_line_number)
      o.reload
      s2 = EntitySnapshot.create_from_entity o, @u
      diff = s2.diff s
      
      expect(diff.children_in_both.size).to eq 1
      cib = diff.children_in_both.first
      expect(cib.model_fields_changed['ordln_line_number']).to eq [old_line_number,new_line_number]
    end
    it "should reflect child with new id and same logical key as update not add/delete" do
      ol = Factory(:order_line,hts:'123456')
      line_number = ol.line_number
      o = ol.order
      s = EntitySnapshot.create_from_entity o, @u
      ol.destroy
      ol = Factory(:order_line,order:o,line_number:line_number,hts:'654321')
      o.reload
      s2 = EntitySnapshot.create_from_entity o, @u
      diff = s2.diff s
      
      expect(diff.children_in_both.size).to eq 1
      cib = diff.children_in_both.first
      expect(cib.model_fields_changed['ordln_hts']).to eq ['123456'.hts_format,'654321'.hts_format]
    end
  end
  describe "restore" do
    before :each do 
      ModelField.reload
      #not worrying about permissions
      allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)
      allow_any_instance_of(Classification).to receive(:can_edit?).and_return(true)
      allow_any_instance_of(TariffRecord).to receive(:can_edit?).and_return(true)

      @u = Factory(:user)
      @p = Factory(:product,:name=>'nm',:unique_identifier=>'uid')
      @tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:product=>@p))
      @first_snapshot = @p.create_snapshot @u
    end
    it "should replace base object properties" do
      @p.update_attributes(:name=>'n2')
      restored = @first_snapshot.restore(@u)
      expect(restored.id).to eq(@p.id)
      expect(restored.name).to eq('nm')
    end
    it "should erase base object properties that have been added" do
      @p.update_attributes(:unit_of_measure=>'EA')
      restored = @first_snapshot.restore(@u)
      expect(restored.id).to eq(@p.id)
      expect(restored.unit_of_measure).to be_blank
    end
    it "should insert base object properties that have been removed" do
      @p.update_attributes(:name=>nil)
      restored = @first_snapshot.restore(@u)
      expect(restored.id).to eq(@p.id)
      expect(restored.name).to eq('nm')
    end
    it "should leave base object properties that haven't changed alone" do
      @p.update_attributes(:unit_of_measure=>'EA')
      restored = @first_snapshot.restore(@u)
      expect(restored.id).to eq(@p.id)
      expect(restored.name).to eq('nm')
    end
    it "should update last_updated_by_id" do
      other_user = Factory(:user)
      restored = @first_snapshot.restore(other_user)
      expect(restored.last_updated_by_id).to eq(other_user.id)
    end
    it "should not restore if user does not have permission" do
      @p.update_attributes! last_updated_by: @u
      allow_any_instance_of(Product).to receive(:can_edit?).and_return(false)
      @p.update_attributes(:name=>'n2')
      other_user = Factory(:user)
      restored = @first_snapshot.restore(@u)
      expect(restored.last_updated_by_id).to eq(@u.id)
      expect(restored.name).to eq('n2')
    end

    context "custom_values" do
      context "with standard custom field" do
        
        before :each do 
          @cd = Factory(:custom_definition,:module_type=>'Product',:data_type=>'string')
          ModelField.reload
          @p.update_custom_value! @cd, 'x'
          @first_snapshot = @p.create_snapshot @u
        end

        it "should replace custom fields" do
          @p.update_custom_value! @cd, 'y'
          restored = @first_snapshot.restore(@u)
          expect(restored.get_custom_value(@cd).value).to eq('x')
        end
        it "should erase custom fields that have been added" do
          cd2 = Factory(:custom_definition,:module_type=>'Product',:data_type=>'string')
          @p.update_custom_value! cd2, 'y'
          restored = @first_snapshot.restore(@u)
          expect(restored.get_custom_value(cd2).value).to be_blank
        end
        it "should insert custom fields that have been removed" do
           @p.get_custom_value(@cd).destroy 
          restored = @first_snapshot.restore(@u)
          expect(restored.get_custom_value(@cd).value).to eq('x')
        end
        it "should leave custom fields that haven't changed alone" do
          restored = @first_snapshot.restore(@u)
          expect(restored.get_custom_value(@cd).value).to eq('x')
        end
      end
      
      context "with special custom fields" do
        it "handles user custom value fields" do
          user_def = Factory(:custom_definition, label: "Tested By", module_type: "Product", data_type: 'integer', is_user: true)
          ModelField.reload
          @p.update_custom_value! user_def, @u
          snapshot = @p.create_snapshot @u
          user2 = Factory(:user)
          @p.update_custom_value! user_def, user2
          snapshot.restore @u
          @p.reload
          expect(@p.custom_value(user_def)).to eq @u.id
        end

        it "handles address fields" do
          addr_def = Factory(:custom_definition, label: "Testing Address", module_type: "Product", data_type: 'integer', is_address: true)
          ModelField.reload

          address = Factory(:full_address)
          address_2 = Factory(:full_address)

          @p.update_custom_value! addr_def, address
          snapshot = @p.create_snapshot @u
          @p.update_custom_value! addr_def, address_2

          snapshot.restore @u
          @p.reload
          expect(@p.custom_value(addr_def)).to eq address.id
        end
      end
      
    end

    context "children" do
      it "should add children that were removed" do
        @p.classifications.first.destroy
        restored = @first_snapshot.restore @u
        expect(restored.classifications.first.tariff_records.first.hts_1).to eq('1234567890')
      end
      it "should remove children that didn't exist" do
        p = Factory(:product)
        es = p.create_snapshot @u
        Factory(:tariff_record,:classification=>(Factory(:classification,:product=>p)))
        p.reload
        expect(p.classifications.first.tariff_records.first).not_to be_nil
        es.restore @u
        p.reload
        expect(p.classifications.first).to be_nil
      end
      it "should replace values in children that changed" do
        @tr.update_attributes(:hts_1=>'1234')
        @first_snapshot.restore @u
        expect(TariffRecord.find(@tr.id).hts_1).to eq('1234567890')
      end
      it "should replace custom values for children that changed" do
        cd = Factory(:custom_definition,:module_type=>"Classification",:data_type=>"string")
        @tr.classification.update_custom_value! cd, 'x'
        @first_snapshot = @p.create_snapshot @u
        @tr.classification.update_custom_value! cd, 'y'
        restored = @first_snapshot.restore @u
        expect(restored.classifications.first.get_custom_value(cd).value).to eq('x')
      end

      it "should skip child records with blank record ids" do
        j = @first_snapshot.snapshot_json
        j['entity']['children'][0]['entity']['record_id'] = nil
        @first_snapshot.snapshot = j.to_json
        restored = @first_snapshot.restore @u
        expect(restored.classifications.size).to eq 0
      end
    end

    it "retrieves snapshot data from snapshot field if it is not null" do
      first_snapshot = @first_snapshot.snapshot_json
      @first_snapshot.update_attributes! snapshot: ActiveSupport::JSON.encode(first_snapshot)
      expect(EntitySnapshot).not_to receive(:retrieve_snapshot_data_from_s3)

      restored = @first_snapshot.restore (@u)
      expect(restored).to eq @p
      expect(restored.name).to eq "nm"
    end
  end

  describe "bucket_name" do
    it "should append env.system_code.snapshots.vfitrack.net" do
      env = Rails.env
      MasterSetup.get.update_attributes(system_code:'syscode')
      expect(EntitySnapshot.bucket_name).to eq "#{env}.syscode.snapshots.vfitrack.net"
    end
    it "should raise error if longer than 63 characters (AWS limit)" do
      MasterSetup.get.update_attributes(system_code:'123456789012345678901234567890123456789012345678901234567890')
      expect{EntitySnapshot.bucket_name}.to raise_error(/Bucket name too long/)
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
      expect(OpenChain::S3).to receive(:create_bucket!).with(@bn,versioning: true)
      described_class.create_bucket_if_needed!
    end
  end

  describe "create_from_entity" do
    it "should write S3 file at logical path" do
      expected_path = '/my/path'
      expected_bucket = 'bucket'
      expected_version = 'ABC123'
      expected_json = '{"a":"b"}'
      ent = Factory(:entry)
      u = Factory(:user)
      allow(CoreModule::ENTRY).to receive(:entity_json).and_return(expected_json)

      expect(described_class).to receive(:s3_path).and_return(expected_path)
      expect(described_class).to receive(:bucket_name).and_return(expected_bucket)

      s3_obj = double('S3Obj')
      s3_bucket = double("S3Bucket")
      allow(s3_obj).to receive(:bucket).and_return s3_bucket
      allow(s3_bucket).to receive(:name).and_return expected_bucket
      allow(s3_obj).to receive(:key).and_return expected_path

      version_obj = double('ObjectVersion')
      allow(version_obj).to receive(:version_id).and_return(expected_version)
      
      expect(OpenChain::S3).to receive(:upload_data).
        with(expected_bucket,expected_path,expected_json).
        and_return([s3_obj,version_obj])

      es = EntitySnapshot.create_from_entity(ent,u)
      expect(es.bucket).to eq expected_bucket
      expect(es.doc_path).to eq expected_path
      expect(es.version).to eq expected_version
      expect(es.compared_at).to be_nil
    end

    it "should call EntityCompare.handle_snapshot with snapshot" do
      allow_any_instance_of(described_class).to receive(:write_s3)
      expect(OpenChain::EntityCompare::EntityComparator).to receive(:handle_snapshot)

      ent = Factory(:entry)
      u = Factory(:user)
      es = EntitySnapshot.create_from_entity(ent,u)
    end
  end

  describe "expected_s3_path" do
    it "should be core module / recordable.id" do
      ent = Factory(:entry)
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
      expect(OpenChain::S3).to receive(:get_versioned_data) do |bucket, path, version, io|
        expect(bucket).to eq "bucket"
        expect(path).to eq "test/doc-1.json"
        expect(version).to eq "1"

        io.write "Testing"
      end

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
end
