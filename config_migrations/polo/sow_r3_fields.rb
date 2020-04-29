module ConfigMigrations; module Polo; class SowR3Fields

  def up
    migrate_custom_fields
  end

  def down
    rollback_custom_fields
  end

  def migrate_custom_fields
    puts "Creating custom fields"
    ActiveRecord::Base.transaction do
      # Rename the existing "Knit / Woven?" field to "Material Group (Deprecated)"
      material_group = CustomDefinition.where(label: "Knit / Woven?", data_type: "string", module_type: "Product").first
      if material_group
        material_group.label = "Material Group (Deprecated)"
        material_group.save!
      end

      # There's something about custom definitions and the activerecord scoping involved when creating them via first_or_create! that causes
      # the call to not work right and bomb due to bad ids being utilized in the foreign keys, so don't use that
      if CustomDefinition.where(label: "Knit / Woven", data_type: "string", module_type: "Product").first.nil?
        knit_woven = CustomDefinition.create!(label: "Knit / Woven", data_type: "string", module_type: "Product")
        FieldValidatorRule.where(model_field_uid: knit_woven.model_field_uid, module_type: "Product", one_of: "Knit\nWoven", read_only: false).first_or_create!
      end

      if CustomDefinition.where(label: "Allocation Category", data_type: "string", module_type: "Product").first.nil?
        allocation_category = CustomDefinition.create!(label: "Allocation Category", data_type: "string", module_type: "Product")
        FieldValidatorRule.where(model_field_uid: allocation_category.model_field_uid, module_type: "Product", one_of: "BJT\nCTS\nFUR\nNCT\nSPE\nSTR\nWOD", read_only: false).first_or_create!
      end
    end
  end

  def rollback_custom_fields
    puts "Rolling back custom fields"
    ActiveRecord::Base.transaction do
      knit_woven = CustomDefinition.where(label: "Knit / Woven", data_type: "string", module_type: "Product").first
      knit_woven.destroy if knit_woven

      allocation_category = CustomDefinition.where(label: "Allocation Category", data_type: "string", module_type: "Product").first
      allocation_category.destroy if allocation_category

      # Rename the existing "Material Group (Deprecated)" field to "Knit / Woven?"
      # Do this last, since it will set the updated_at which will then trigger a full ModelField reload
      knit_woven = CustomDefinition.where(label: "Material Group (Deprecated)", data_type: "string", module_type: "Product").first
      if knit_woven
        knit_woven.label = "Knit / Woven?"
        knit_woven.save!
      end
    end
  end
end; end; end