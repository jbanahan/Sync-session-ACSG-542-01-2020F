describe OpenChain::EntityCompare::ComparatorHelper do
  subject {
    Class.new do
      include OpenChain::EntityCompare::ComparatorHelper
    end.new
  }
  describe '#get_json_hash' do
    it "should get data from S3" do
      h = {'a'=>'b'}
      json = h.to_json
      expect(OpenChain::S3).to receive(:get_versioned_data).with('b','k','v').and_return json
      expect(subject.get_json_hash('b','k','v')).to eq h
    end

    it "returns blank hash if bucket is blank" do
      expect(subject.get_json_hash('','k','v')).to eq({})
    end

    it "returns blank hash if key is blank" do
      expect(subject.get_json_hash('b','','v')).to eq({})
    end

    it "returns blank hash if version is blank" do
      expect(subject.get_json_hash('b','k','')).to eq({})
    end

    it "returns blank if data is blank" do
      expect(OpenChain::S3).to receive(:get_versioned_data).with('b','k','v').and_return "       "
      expect(subject.get_json_hash('b','k','v')).to eq({})
    end
  end

  describe "parse_time" do
    it "parses time from utc to eastern" do
      expect(subject.parse_time("2016-04-08 8:44")).to eq ActiveSupport::TimeZone['America/New_York'].parse("2016-04-08 4:44")
    end

    it "parses time using given timezones" do
       expect(subject.parse_time("2016-04-08 8:44", input_timezone: 'America/New_York', output_timezone: 'America/Chicago')).to eq ActiveSupport::TimeZone['America/Chicago'].parse("2016-04-08 7:44")
    end

    it "returns nil if time is blank" do
      expect(subject.parse_time("   ")).to be_nil
    end 
  end


  describe "json_child_entities" do
    let (:parent_a) {
      {"core_module" => "Parent", "model_fields"=> {"test" => "Parent-A"},
        "children" => [
          {'entity' => {"core_module" => "Child", "model_fields"=> {"test" => "Child-A"}}},
          {'entity' => {"core_module" => "Child", "model_fields"=> {"test" => "Child-B"}}},
          {'entity' => {"core_module" => "Pet", "model_fields"=> {"test" => "Pet-A"}}}
        ]}
    }

    let (:parent_b) {
      {"core_module" => "Parent", "model_fields"=> {"test" => "Parent-B"},
        "children" => [
          {'entity' => {"core_module" => "Child", "model_fields"=> {"test" => "Child-C"}}},
          {'entity' => {"core_module" => "Child", "model_fields"=> {"test" => "Child-D"}}},
        ]}
    }

    let (:json) {
      {'entity' => {
          'core_module' => "GrandParent",
          'children' => [
            {'entity' => parent_a},
            {'entity' => parent_b},
            {'entity' => {"core_module" => "Pet", "model_fields"=> {"test" => "Pet-C"}}}
          ]
        }
      }
    }

    it "returns first tier child entities" do
      result = subject.json_child_entities json, "Parent"

      expect(result.length).to eq 2
      expect(result.first).to eq(parent_a)
      expect(result.second).to eq(parent_b)
    end

    it "returns grandchildren" do
      result = subject.json_child_entities json, "Parent", "Child"

      expect(result.length).to eq 4
      expect(result[0]).to eq({"core_module" => "Child", "model_fields"=> {"test" => "Child-A"}})
      expect(result[1]).to eq({"core_module" => "Child", "model_fields"=> {"test" => "Child-B"}})
      expect(result[2]).to eq({"core_module" => "Child", "model_fields"=> {"test" => "Child-C"}})
      expect(result[3]).to eq({"core_module" => "Child", "model_fields"=> {"test" => "Child-D"}})
    end

    it "yields results if block given" do
      results = []
      subject.json_child_entities(json, "Pet") do |result|
        results << result
      end

      expect(results.length).to eq 1
      expect(results[0]).to eq( {"core_module" => "Pet", "model_fields"=> {"test" => "Pet-C"}} )
    end
  end

  describe "mf" do
    it "extracts a model field value from an entity hash" do
      expect(subject.mf({"core_module" => "Child", "model_fields"=> {"test" => "Child-A"}}, "test")).to eq "Child-A"
    end

    it "extracts a model field value from a wrapped entity hash" do 
      expect(subject.mf({"entity" => {"core_module" => "Child", "model_fields"=> {"test" => "Child-A"}}}, "test")).to eq "Child-A"
    end

    it "returns nil if model field is not present" do
      expect(subject.mf({"core_module" => "Child", "model_fields"=> {"test" => "Child-A"}}, "testing")).to be_nil
    end

    it "allows for symbol to be used as field name value" do
      expect(subject.mf({"core_module" => "Child", "model_fields"=> {"test" => "Child-A"}}, :test)).to eq "Child-A"
    end

    it "allows for custom definition to be used to obtain field value" do
      cd = instance_double(CustomDefinition)
      expect(cd).to receive(:model_field_uid).and_return "test"

      expect(subject.mf({"core_module" => "Child", "model_fields"=> {"test" => "Child-A"}}, cd)).to eq "Child-A"
    end

    it "coerces value to model field's given datatype" do
      # All the coercions are tested elsewhere, just make sure this works if enabled.
      expect(subject.mf({"entity" => {"core_module" => "Child", "model_fields"=> {"ent_duty_due_date" => "2017-01-11"}}}, "ent_duty_due_date")).to eq Date.new(2017, 1, 11)
    end

    it "does not coerce if instructed" do
      expect(subject.mf({"entity" => {"core_module" => "Child", "model_fields"=> {"ent_duty_due_date" => "2017-01-11"}}}, "ent_duty_due_date", coerce: false)).to eq "2017-01-11"
    end
  end

  describe "find_entity_object" do
    let (:entry) { Factory(:entry) }
    let (:json) { {"core_module" => "Entry", "record_id" => entry.id } }

    it "retrieves core module object specified by snapshot json" do
      expect(subject.find_entity_object(json)).to eq entry
    end

    it "finds wrapped objects" do
      expect(subject.find_entity_object({"entity" => json})).to eq entry
    end

    it "returns nil if record is not found" do
      json['record_id'] = -1
      expect(subject.find_entity_object(json)).to be_nil
    end
  end

  describe "coerce_model_field_value" do
    it "converts date values" do
      expect(subject.coerce_model_field_value "ent_duty_due_date", "2017-01-11").to eq Date.new(2017, 1, 11)
    end

    it "handles blank date values" do
      expect(subject.coerce_model_field_value "ent_duty_due_date", "").to be_nil
    end

    it "converts date time values" do
      # Make sure it handles time zone conversion too
      Time.use_zone("America/Chicago") do 
        expect(subject.coerce_model_field_value "ent_arrival_date", "2017-01-11T10:42:48Z").to eq ActiveSupport::TimeZone["America/Chicago"].parse "2017-01-11T04:42:48"
      end
    end

    it "handles blank datetime values" do
      expect(subject.coerce_model_field_value "ent_arrival_date", "").to be_nil
    end

    it "converts decimal values" do
      expect(subject.coerce_model_field_value "ent_total_duty", "128.123").to eq BigDecimal("128.123")
    end

    it "handles blank decimal values" do
      expect(subject.coerce_model_field_value "ent_total_duty", "").to be_nil
    end

    it "handles string values" do
      r = "REF"
      # We shouldn't be changing the object if it's a string
      expect(subject.coerce_model_field_value "ent_brok_ref", r).to be r
    end

    it "handles boolean values" do
      expect(subject.coerce_model_field_value "ent_paperless_release", true).to be true
    end

    it "handles integer values" do
      expect(subject.coerce_model_field_value "ent_ci_line_count", 10).to be 10
    end

    it "handles missing model fields" do
      r = "1234"
      expect(subject.coerce_model_field_value "notafield", r).to be r
    end
  end

  describe "changed_fields" do
    let(:snapshot) {
      {
      "entity" => {
        "core_module" => "Shipment",
        "model_fields" => {
          "shp_ref" => "7ABC2FGA",
          "shp_booking_number" => "BOOKINGNUMBER",
          "shp_cargo_ready_date" => "2018-04-01 12:00",
          "shp_booking_received_date" => "2018-04-02 12:00",
          "shp_booking_approved_date" => "2018-04-03 12:00",
          "shp_booking_confirmed_date" => "2018-04-04 12:00",
          "shp_booking_cutoff_date" => "2018-04-05 12:00"
          }
        }
      }
    }

    let (:changed_snapshot) {
      {
      "entity" => {
        "core_module" => "Shipment",
        "model_fields" => {
          "shp_ref" => "7ABC2FGA-X",
          "shp_booking_number" => "BOOKINGNUMBER",
          "shp_cargo_ready_date" => "2018-04-02 12:00",
          "shp_booking_received_date" => "2018-04-02 12:00",
          "shp_booking_approved_date" => "2018-04-03 12:00",
          "shp_booking_confirmed_date" => "2018-04-04 12:00",
          "shp_booking_cutoff_date" => "2018-04-05 12:00"
          }
        }
      }
    }

    it "returns all changed values requested" do
      fields = subject.changed_fields snapshot, changed_snapshot, [:shp_ref, :shp_cargo_ready_date, :shp_booking_received_date, :shp_booking_number, 
        :shp_booking_approved_date, :shp_booking_confirmed_date, :shp_booking_cutoff_date]

      expect(fields.size).to eq 2
      expect(fields).to eq({shp_ref: "7ABC2FGA-X", shp_cargo_ready_date: Date.new(2018, 4, 2)})
    end

    it "returns blank hash if nothing changed" do
      fields = subject.changed_fields snapshot, snapshot, [:shp_ref, :shp_cargo_ready_date, :shp_booking_received_date, :shp_booking_number, 
        :shp_booking_approved_date, :shp_booking_confirmed_date, :shp_booking_cutoff_date]
      expect(fields).to eq({})
    end
  end

  describe "any_changed_fields?" do
    let(:snapshot) {
      {
      "entity" => {
        "core_module" => "Shipment",
        "model_fields" => {
          "shp_ref" => "7ABC2FGA",
          "shp_booking_number" => "BOOKINGNUMBER",
          "shp_cargo_ready_date" => "2018-04-01 12:00",
          "shp_booking_received_date" => "2018-04-02 12:00",
          "shp_booking_approved_date" => "2018-04-03 12:00",
          "shp_booking_confirmed_date" => "2018-04-04 12:00",
          "shp_booking_cutoff_date" => "2018-04-05 12:00"
          }
        }
      }
    }

    it "returns true if snapshot values changed" do
      changed = snapshot.deep_dup
      changed["entity"]["model_fields"]["shp_ref"] = "CHANGE"
      expect(subject.any_changed_fields?(snapshot, changed, [:shp_ref, :shp_cargo_ready_date, :shp_booking_received_date, :shp_booking_number, 
        :shp_booking_approved_date, :shp_booking_confirmed_date, :shp_booking_cutoff_date])).to eq true
    end

    it "returns false if all fields are the same" do
      expect(subject.any_changed_fields?(snapshot, snapshot, [:shp_ref, :shp_cargo_ready_date, :shp_booking_received_date, :shp_booking_number, 
        :shp_booking_approved_date, :shp_booking_confirmed_date, :shp_booking_cutoff_date])).to eq false
    end
  end

  describe "json_entity_type_and_id" do 
    let(:snapshot) {
      {
        "entity" => {
          "core_module" => "Shipment",
          "record_id" => 1
        }
      }
    }

    it "extracts the core module name and record id from a snapshot hash" do
      expect(subject.json_entity_type_and_id snapshot).to eq ["Shipment", 1]
    end

    it "handles unwrap entity hashes" do
      expect(subject.json_entity_type_and_id snapshot["entity"]).to eq ["Shipment", 1]
    end
  end

  describe "any_value_changed?" do
    let (:old_hash) {
      {
        "entity" => {
          "model_fields" => {
            "string" => "value",
            "boolean" => true,
            "date" => Date.new(2018, 4, 1)
          }
        }
      }
    }

    let (:new_hash) {
      {
        "entity" => {
          "model_fields" => {
            "string" => "value2",
            "boolean" => false,
            "date" => Date.new(2018, 5, 1)
          }
        }
      }
    }

    it "returns true if a specific value in a snapshot changed" do
      expect(subject.any_value_changed? old_hash, new_hash, ["string"]).to eq true
    end

    it "returns false if nothing changed" do
      expect(subject.any_value_changed? old_hash, old_hash, ["string"]).to eq false
    end

    it "returns true if only one of the given model fields changed" do
      new_hash["entity"]["model_fields"]["string"] = "value"
      expect(subject.any_value_changed? old_hash, new_hash, ["string", "boolean"]).to eq true
    end

    it "returns false if both values are missing from the hash" do
      expect(subject.any_value_changed? old_hash, old_hash, ["missing"]).to eq false
    end
  end

  describe "any_root_value_changed?" do
    let (:old_hash) {
      {
        "entity" => {
          "model_fields" => {
            "string" => "value",
            "boolean" => true,
            "date" => Date.new(2018, 4, 1)
          }
        }
      }
    }

    let (:new_hash) {
      {
        "entity" => {
          "model_fields" => {
            "string" => "value2",
            "boolean" => false,
            "date" => Date.new(2018, 5, 1)
          }
        }
      }
    }

    it "detects changes in hashes using any_value_changed?" do
      expect(subject).to receive(:get_json_hash).with("ob", "ok", "ov").and_return old_hash
      expect(subject).to receive(:get_json_hash).with("nb", "nk", "nv").and_return new_hash
      expect(subject).to receive(:any_value_changed?).with(old_hash, new_hash, ["value"]).and_return true

      expect(subject.any_root_value_changed? "ob", "ok", "ov", "nb", "nk", "nv", ["value"]).to eq true
    end
  end

  describe "find_entity_object_by_snapshot_values" do
    let(:snapshot) {
      {
      "entity" => {
        "core_module" => "Shipment",
        "model_fields" => {
          "shp_ref" => "7ABC2FGA",
          "shp_booking_number" => "BOOKINGNUMBER",
          "shp_cargo_ready_date" => "2018-04-01 12:00",
          "shp_booking_received_date" => "2018-04-02 12:00",
          "shp_booking_approved_date" => "2018-04-03 12:00",
          "shp_booking_confirmed_date" => "2018-04-04 12:00",
          "shp_booking_cutoff_date" => "2018-04-05 12:00"
          }
        }
      }
    }

    it "uses data present in snapshot to construct query to find object" do
      s = Shipment.create! reference: "7ABC2FGA", booking_number: "BOOKINGNUMBER"

      expect(subject.find_entity_object_by_snapshot_values(snapshot, reference: :shp_ref, booking_number: :shp_booking_number)).to eq s
    end

    it "returns nil if no fields are passed" do
      expect(subject.find_entity_object_by_snapshot_values(snapshot)).to be_nil
    end

    it "returns nil if no object is found" do
      Shipment.create! reference: "7ABC2FGA", booking_number: "ANOTHERBOOKINGNUMBER"      
      expect(subject.find_entity_object_by_snapshot_values(snapshot, reference: :shp_ref, booking_number: :shp_booking_number)).to be_nil
    end
  end
  
end
