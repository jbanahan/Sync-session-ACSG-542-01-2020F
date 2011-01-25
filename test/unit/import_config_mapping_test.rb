require 'test_helper'

class ImportConfigMappingTest < ActiveSupport::TestCase
  test "find model field" do
    to_find = ModelField.find_by_uid("ord_ord_num")
    icm = ImportConfigMapping.new({:model_field_uid => to_find.uid})
    found = icm.find_model_field
    assert to_find.field_name == found.field_name, "Fields should have been the same, were #{to_find.field_name} and #{found.field_name}"
    assert to_find.model == found.model, "Models should have been the same, were #{to_find.model} and #{found.model}"
  end
end
