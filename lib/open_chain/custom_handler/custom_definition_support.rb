module OpenChain; module CustomHandler; module CustomDefinitionSupport
  #find or create all given custom definitions based on the available_fields
  def prep_custom_defs fields_to_init, available_fields
    custom_definitions = {}
    cloned_instructions = available_fields.clone
    fields_to_init.each do |code|
      # Clone the instructions so we can modify the read_only value without impacting future runs
      # this prevents weird behavior with multiple calls (like test case runs).
      cdi = available_fields[code].clone
      read_only = cdi[:read_only]
      cdi.delete :read_only
      custom_definitions[code] = CustomDefinition.where(cdi).first_or_create! if cdi
      if read_only
        fvr = FieldValidatorRule.where(custom_definition_id:custom_definitions[code].id,module_type:cdi[:module_type],model_field_uid:"*cf_#{custom_definitions[code].id}").first_or_create!
        unless fvr.read_only?
          fvr.read_only = true
          fvr.save!
        end
      end
    end
    custom_definitions
  end
end; end; end
