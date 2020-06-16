module OpenChain; module CustomHandler; module CustomDefinitionSupport

  # find or create all given custom definitions based on the available_fields
  def prep_custom_defs fields_to_init, available_fields
    # The overwhelmingly vast majority of time, the custom definitions are going to already exist, so if we can load them all with a single
    # query, that will save us time over querying for each custom definition one by one
    custom_definitions = existing_custom_definitions(fields_to_init, available_fields)
    return custom_definitions if fields_to_init.length == custom_definitions.size

    fields_to_create = Set.new
    fields_to_init.each do |field|
      fields_to_create << field if custom_definitions[field].nil?
    end

    ModelField.disable_reloads do
      fields_to_create.each do |code|
        # Clone the instructions so we can modify the read_only value without impacting future runs
        # this prevents weird behavior with multiple calls (like test case runs).
        field_hash = available_fields[code]
        validate_custom_definition_instruction_hash(code, field_hash)

        cdi = field_hash.clone
        read_only = cdi.delete :read_only

        # The lock here is to prevent muliple processes from trying to create the same custom definition at the same time, which
        # can happen when multiple distinct delayed jobs are running over the same file type at the same time (.ie same parser class).
        Lock.acquire("CustomDefinition-#{cdi[:cdef_uid]}", yield_in_transaction: false) do
          # Don't open an unnecessary transaction here, all we need is locking across processes, not atomicity
          cust_def = CustomDefinition.create!(cdi)
          custom_definitions[code] = cust_def

          if read_only
            FieldValidatorRule.create! custom_definition_id: cust_def.id, module_type: cust_def.module_type, model_field_uid: cust_def.model_field_uid, read_only: true
          end
        end
      end
    end

    custom_definitions
  end

  def existing_custom_definitions fields_to_init, available_fields
    # Need to store a reference back to the key used for this definition in the setup hash, so we can re-associate it with the CustomDefinition found
    cdef_uids = {}
    fields_to_init.each do |field_key|
      cd = available_fields[field_key]
      validate_custom_definition_instruction_hash(field_key, cd)

      cdef_uids[cd[:cdef_uid].to_sym] = field_key.to_sym
    end

    cdefs = {}
    if cdef_uids.length > 0
      CustomDefinition.where(cdef_uid: cdef_uids.keys).each do |cd|
        cdefs[cdef_uids[cd.cdef_uid.to_sym]] = cd
      end
    end
    cdefs
  end

  def validate_custom_definition_instruction_hash field_key, cdi
    raise "No custom definition setup found for field identifier: #{field_key}." unless cdi
    # No new custom definitions should be created without a cdef_uid...this should only ever happen in dev if someone forgets to use a cdef
    raise "All new Custom Definitions should contain cdef_uid identifiers. #{cdi[:module_type]} field '#{cdi[:label]}' did not have an identifier."  if cdi[:cdef_uid].blank?
  end

end; end; end
