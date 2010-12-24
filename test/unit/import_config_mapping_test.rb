require 'test_helper'

class ImportConfigMappingTest < ActiveSupport::TestCase
  test "find model field" do
    to_find = ImportConfig.find_model_field :order, :order_number
    icm = ImportConfigMapping.new({:model_field_uid => to_find.uid})
    found = icm.find_model_field
    assert to_find.field == found.field, "Fields should have been the same, were #{to_find.field} and #{found.field}"
    assert to_find.model == found.model, "Models should have been the same, were #{to_find.model} and #{found.model}"
  end
end
