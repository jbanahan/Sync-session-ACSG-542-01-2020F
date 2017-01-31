require 'spec_helper'

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
end
