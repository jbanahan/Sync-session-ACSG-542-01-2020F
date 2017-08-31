module OpenChain; module CustomHandler; module CustomDefinitionSupport

  #find or create all given custom definitions based on the available_fields
  def prep_custom_defs fields_to_init, available_fields
    custom_definitions = {}
    available_fields.clone
    fields_to_init.each do |code|
      # Clone the instructions so we can modify the read_only value without impacting future runs
      # this prevents weird behavior with multiple calls (like test case runs).
      field_hash = available_fields[code]
      raise "No custom definition setup found for field identifier: #{code}." unless field_hash
      cdi = field_hash.clone
      read_only = cdi[:read_only]
      cdi.delete :read_only
      if cdi
        cust_def = find_custom_definition(cdi, update_cdef_uid: true)
        if !cust_def
          # The lock here is to prevent muliple processes from trying to create the same custom definition at the same time, which 
          # can happen when multiple distinct delayed jobs are running over the same file type at the same time (.ie same parser class).
          Lock.acquire("CustomDefinition", yield_in_transaction: false) do
            # Don't open an unnecessary transation here, all we need is locking across processes, not atomicity
            cust_def = find_custom_definition(cdi, update_cdef_uid: false)
            if cust_def.nil?
              # No new custom definitions should be created without cdef_uid...this should only ever happen in dev if someone forgets to use a cdef
              raise "All new Custom Definitions should contain cdef_uid identifiers. #{cdi[:module_type]} field '#{cdi[:label]}' did not have an identifier."  if cdi[:cdef_uid].blank?
              cust_def = CustomDefinition.create!(cdi)
              cust_def.reset_cache
            end
          end
        end

        custom_definitions[code] = cust_def
      end

      if read_only
        cd = custom_definitions[code]
        fvr = FieldValidatorRule.where(custom_definition_id:cd.id).first_or_initialize(module_type: cd.module_type, model_field_uid:cd.model_field_uid, read_only: (read_only == true))
        if fvr.persisted?
          if !fvr.read_only?
            Lock.with_lock_retry(fvr) { fvr.update_attributes! read_only: true }
          end
        else
          # There's a unique constraint on the model_field_uid, so in the case where we're attempting to create 2 of the same field validator rules here,
          # it'll fail...and the delayed job will just end up running again (which is fine - it's better than what was happening before with several defintions being created)
          fvr.save!
        end
      end
    end
    
    custom_definitions
  end

  def find_custom_definition cdi, update_cdef_uid: false
    cust_def = nil
    if cdi[:cdef_uid]
      cust_def = CustomDefinition.find_by_cdef_uid(cdi[:cdef_uid])
    end
    if !cust_def
      cust_def = CustomDefinition.where(label:cdi[:label],data_type:cdi[:data_type],module_type:cdi[:module_type]).first
      # if we find a custom definition that should have had a UID, add the UID
      if update_cdef_uid && cust_def && cdi[:cdef_uid]
        cust_def.update_attributes(cdef_uid:cdi[:cdef_uid])
      end
    end

    cust_def
  end

end; end; end
