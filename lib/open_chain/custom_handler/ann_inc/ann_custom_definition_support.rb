module OpenChain
  module CustomHandler
    module AnnInc
      module AnnCustomDefinitionSupport
        CUSTOM_DEFINITION_INSTRUCTIONS = {
          :po=>{:label=>"PO Numbers",:data_type=>:text,:read_only=>true,:module_type=>'Product'},
          :origin=>{:label=>"Origin Countries",:data_type=>:text,:module_type=>'Product',:read_only=>true},
          :import=>{:label=>"Import Countries",:data_type=>:text,:module_type=>'Product',:read_only=>true},
          :cost=>{:label=>"Unit Costs",:data_type=>:text,:module_type=>'Product',:read_only=>true},
          :ac_date=>{:label=>"Earliest AC Date",:data_type=>:date,:module_type=>'Product',:read_only=>true},
          :dept_num=>{:label=>"Merch Dept Number",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :dept_name=>{:label=>"Merch Dept Name",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :prop_hts=>{:label=>"Proposed HTS",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :prop_long=>{:label=>"Proposed Long Description",:data_type=>:text,:module_type=>'Product',:read_only=>true},
          :oga_flag=>{:label=>"Other Agency Flag",:data_type=>:boolean,:module_type=>'Classification'},
          :imp_flag=>{:label=>"SAP Import Flag",:data_type=>:boolean,:module_type=>'Product',:read_only=>true},
          :inco_terms=>{:label=>"INCO Terms",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :season=>{:label=>"Season",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :article=>{:label=>"Article Type",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :approved_long=>{:label=>"Approved Long Description",:data_type=>:text,:module_type=>'Product'},
          :approved_date=>{:label=>"Approved Date",:data_type=>:date,:module_type=>'Classification'},
          :first_sap_date=>{:label=>"First SAP Received Date",:data_type=>:date,:module_type=>'Product',:read_only=>true},
          :last_sap_date=>{:label=>"Last SAP Received Date",:data_type=>:date,:module_type=>'Product',:read_only=>true},
          :sap_revised_date=>{:label=>"SAP Revised Date",:data_type=>:date,:module_type=>'Product',:read_only=>true},
          :long_desc_override=>{:label=>'Long Description Override',:data_type=>:text,:module_type=>'Classification'},
          :manual_flag=>{:label=>'Manual Entry Processing',:data_type=>:boolean,:module_type=>'Classification'},
          :fta_flag=>{:label=>'FTA Eligible',:data_type=>:boolean,:module_type=>'Classification'},
          :set_qty=>{:label=>'Set Quantity',:data_type=>:integer,:module_type=>'TariffRecord'},
          :related_styles=>{:label=>'Related Styles', :data_type=>:text, :module_type=>"Product", :read_only=>true}
        }
        #find or create all given custom definitions based on the CUSTOM_DEFINITION_INSTRUCTIONS
        def prep_custom_definitions fields
          custom_definitions = {}
          cloned_instructions = CUSTOM_DEFINITION_INSTRUCTIONS.clone
          fields.each do |code|
            # Clone the instructions so we can modify the read_only value without impacting future runs
            # this prevents weird behavior with multiple calls (like test case runs).
            cdi = CUSTOM_DEFINITION_INSTRUCTIONS[code].clone
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
      end
    end
  end
end
