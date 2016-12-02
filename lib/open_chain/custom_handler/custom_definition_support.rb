module OpenChain; module CustomHandler; module CustomDefinitionSupport
  #find or create all given custom definitions based on the available_fields
  def prep_custom_defs fields_to_init, available_fields
    custom_definitions = {}
    available_fields.clone
    fields_to_init.each do |code|
      # Clone the instructions so we can modify the read_only value without impacting future runs
      # this prevents weird behavior with multiple calls (like test case runs).
      cdi = available_fields[code].clone
      read_only = cdi[:read_only]
      cdi.delete :read_only
      if cdi
        cust_def = nil
        if cdi[:cdef_uid]
          cust_def = CustomDefinition.find_by_cdef_uid(cdi[:cdef_uid])
        end
        if !cust_def
          cust_def = CustomDefinition.where(label:cdi[:label],data_type:cdi[:data_type],module_type:cdi[:module_type]).first
          # if we find a custom definition that should have had a UID, add the UID
          if cust_def && cdi[:cdef_uid]
            cust_def.update_attributes(cdef_uid:cdi[:cdef_uid])
          end
        end
        if !cust_def
          cust_def = CustomDefinition.create!(cdi)
          cust_def.reset_cache
        end
        custom_definitions[code] = cust_def
      end
      if read_only
        fvr = FieldValidatorRule.where(custom_definition_id:custom_definitions[code].id,module_type:cdi[:module_type],model_field_uid:"*cf_#{custom_definitions[code].id}").first_or_create! read_only: (read_only === true)
        unless fvr.read_only?
          fvr.read_only = true
          fvr.save!
        end
      end
    end
    custom_definitions
  end
end; end; end
