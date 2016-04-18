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
      OpenChain::S3.should_receive(:get_versioned_data).with('b','k','v').and_return json
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
      OpenChain::S3.should_receive(:get_versioned_data).with('b','k','v').and_return "       "
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
end
