require 'test_helper'

class EntityTypeFieldTest < ActiveSupport::TestCase
  test "Cached entity type ids" do
    expected = []
    ["abd","def"].each do |n|
      et = EntityType.create!(:name=>n,:module_type=>"Product")
      expected << et.id
      et.entity_type_fields.create!(:model_field_uid=>:prod_name)
    end
    found = EntityTypeField.cached_entity_type_ids ModelField.find_by_uid(:prod_name)
    assert expected.size==found.size && (expected-found).empty?, "Expected #{expected}, got #{found}"
  end
end
