require_relative '../model_field_generator/full_model_field_generator'

module OpenChain; module ModelFieldDefinition
  class ModelFieldDefiner
    include OpenChain::ModelFieldGenerator::FullModelFieldGenerator

    def add_fields(descriptor_array)
      new_fields = descriptor_array.each_with_index.map do |m,i|
        options = {default_label: m[3]}.merge (m[4] || {})

        ModelField.new(i,m[1],core_module,m[2],options)
      end
      ModelField.add_model_fields(core_module, new_fields)
    end

    def add_all_fields
      add_fields fields
    end

    def fields
      []
    end

    def self.add_all_fields!
      subclasses.each do |d|
        d.new.add_all_fields
      end
    end
  end
end; end