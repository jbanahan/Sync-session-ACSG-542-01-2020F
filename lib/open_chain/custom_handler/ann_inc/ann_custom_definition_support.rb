module OpenChain
  module CustomHandler
    module AnnInc
      module AnnCustomDefinitionSupport
        CUSTOM_DEFINITION_INSTRUCTIONS ||= {
          :po=>{:label=>"PO Numbers",:data_type=>:text,:read_only=>true,:module_type=>'Product'},
          :origin=>{:label=>"Origin Countries",:data_type=>:text,:module_type=>'Product',:read_only=>true},
          :import=>{:label=>"Import Countries",:data_type=>:text,:module_type=>'Product',:read_only=>true},
          :cost=>{:label=>"Unit Costs",:data_type=>:text,:module_type=>'Product',:read_only=>true},
          :ac_date=>{:label=>"Earliest AC Date",:data_type=>:date,:module_type=>'Product',:read_only=>true},
          :dept_num=>{:label=>"Merch Dept Number",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :dept_name=>{:label=>"Merch Dept Name",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :prop_hts=>{:label=>"Proposed HTS",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :prop_long=>{:label=>"Proposed Long Description",:data_type=>:text,:module_type=>'Product',:read_only=>true},
          :oga_flag=>{:label=>"Other Agency Flag",:data_type=>:boolean,:module_type=>'Classification',:read_only=>false},
          :imp_flag=>{:label=>"SAP Import Flag",:data_type=>:boolean,:module_type=>'Product',:read_only=>true},
          :inco_terms=>{:label=>"INCO Terms",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :missy=>{:label=>"Missy Style",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :petite=>{:label=>"Petite Style",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :tall=>{:label=>"Tall Style",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :season=>{:label=>"Season",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :article=>{:label=>"Article Type",:data_type=>:string,:module_type=>'Product',:read_only=>true},
          :approved_long=>{:label=>"Approved Long Description",:data_type=>:text,:module_type=>'Product',:read_only=>false},
          :approved_date=>{:label=>"Approved Date",:data_type=>:date,:module_type=>'Classification',:read_only=>false},
          :first_sap_date=>{:label=>"First SAP Received Date",:data_type=>:date,:module_type=>'Product',:read_only=>true},
          :last_sap_date=>{:label=>"Last SAP Received Date",:data_type=>:date,:module_type=>'Product',:read_only=>true},
          :long_desc_override=>{:label=>'Long Description Override',:data_type=>:text,:module_type=>'Classification',:read_only=>false},
          :manual_flag=>{:label=>'Manual Entry Processing',:data_type=>:boolean,:module_type=>'Classification',:read_only=>false},
          :fta_flag=>{:label=>'FTA Eligible',:data_type=>:boolean,:module_type=>'Classification',:read_only=>false},
          :set_qty=>{:label=>'Set Quantity',:data_type=>:integer,:module_type=>'TariffRecord',:read_only=>false}
        }
        #find or create all given custom definitions based on the CUSTOM_DEFINITION_INSTRUCTIONS
        def prep_custom_definitions fields
          custom_definitions = {}
          fields.each do |code|
            cdi = CUSTOM_DEFINITION_INSTRUCTIONS[code]
            custom_definitions[code] = CustomDefinition.where(cdi).first_or_create! if cdi
          end
          custom_definitions
        end
      end
    end
  end
end
