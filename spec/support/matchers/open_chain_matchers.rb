#Make sure the given model field uid is in the model field set
RSpec::Matchers.define :be_a_model_field_uid do
  match do |field|
    ModelField.find_by_uid field
  end
end
