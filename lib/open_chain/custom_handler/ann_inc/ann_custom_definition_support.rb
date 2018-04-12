require 'open_chain/custom_handler/custom_definition_support'
module OpenChain
  module CustomHandler
    module AnnInc
      module AnnCustomDefinitionSupport
        CUSTOM_DEFINITION_INSTRUCTIONS = {
          :po=>{:label=>"PO Numbers",:data_type=>:text,:read_only=>true,:module_type=>'Product', cdef_uid: :prod_po_number},
          :origin=>{:label=>"Origin Countries",:data_type=>:text,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_origin_countries},
          :import=>{:label=>"Import Countries",:data_type=>:text,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_import_countries},
          :cost=>{:label=>"Unit Costs",:data_type=>:text,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_unit_costs},
          :ac_date=>{:label=>"Earliest AC Date",:data_type=>:date,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_ac_date},
          :ordln_ac_date=>{:label=>"AC Date",:data_type=>:date,:module_type=>'OrderLine',:read_only=>true, cdef_uid: :ordln_ac_date},
          :ord_ac_date=>{:label=>"Earliest Order AC Date",:data_type=>:date,:module_type=>'Order',:read_only=>true, cdef_uid: :ord_ac_date},
          :dept_num=>{:label=>"Merch Dept Number",:data_type=>:string,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_dept_number},
          :dept_name=>{:label=>"Merch Dept Name",:data_type=>:string,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_dept_name},
          :prop_hts=>{:label=>"Proposed HTS",:data_type=>:string,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_hts},
          :prop_long=>{:label=>"Proposed Long Description",:data_type=>:text,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_proposed_long_description},
          :imp_flag=>{:label=>"SAP Import Flag",:data_type=>:boolean,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_import_flag},
          :inco_terms=>{:label=>"INCO Terms",:data_type=>:string,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_inco_terms},
          :season=>{:label=>"Season",:data_type=>:string,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_season},
          :article=>{:label=>"Article Type",:data_type=>:string,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_article_type},
          :approved_long=>{:label=>"Approved Long Description",:data_type=>:text,:module_type=>'Product', cdef_uid: :prod_approved_long_description},
          :first_sap_date=>{:label=>"First SAP Received Date",:data_type=>:date,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_first_sap_date},
          :last_sap_date=>{:label=>"Last SAP Received Date",:data_type=>:date,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_last_sap_date},
          :sap_revised_date=>{:label=>"SAP Revised Date",:data_type=>:date,:module_type=>'Product',:read_only=>true, cdef_uid: :prod_sap_revised_date},
          :related_styles=>{:label=>'Related Styles', :data_type=>:text, :module_type=>"Product", :read_only=>true, cdef_uid: :prod_related_styles},
          :minimum_cost=>{:label=>'Minimum Cost', :data_type=>:decimal, :module_type=>'Classification', :read_only=>true, cdef_uid: :class_minimum_cost},
          :maximum_cost=>{:label=>'Maximum Cost', :data_type=>:decimal, :module_type=>'Classification', :read_only=>true, cdef_uid: :class_maximum_cost},
          :oga_flag=>{:label=>"Other Agency Flag",:data_type=>:boolean,:module_type=>'Classification', cdef_uid: :class_oga_flag},
          :long_desc_override=>{:label=>'Long Description Override',:data_type=>:text,:module_type=>'Classification', cdef_uid: :class_long_description_override},
          :manual_flag=>{:label=>'Manual Entry Processing',:data_type=>:boolean,:module_type=>'Classification', cdef_uid: :class_manual_entry_processing},
          :fta_flag=>{:label=>'FTA Eligible',:data_type=>:boolean,:module_type=>'Classification', cdef_uid: :class_fta_eligible},
          :approved_date=>{:label=>"Approved Date",:data_type=>:date,:module_type=>'Classification', cdef_uid: :class_approved_date},
          :set_qty=>{:label=>'Set Quantity',:data_type=>:integer,:module_type=>'TariffRecord', cdef_uid: :hts_set_quantity},
          :mp_type=>{:label=>'MP Type', :data_type=>:string, :module_type=>'Company', cdef_uid: :cmp_mp_type},
          :ord_docs_required=>{:label=>'Docs Required', :data_type=>:boolean,:module_type=>'Order', cdef_uid: :ord_docs_required},
          :ord_docs_completed_by=>{:label=>'Documents Completed By',:data_type=>:integer,:module_type=>'Order', cdef_uid: :ord_docs_completed_by, :read_only=>true,:is_user=>true},
          :ord_docs_completed_date=>{:label=>'Documents Completed At',:data_type=>:date,:module_type=>'Order', :read_only=>true, cdef_uid: :ord_docs_completed_date},
          :ord_audit_complete_by=>{:label=>'Audit Completed By',:data_type=>:integer,:module_type=>'Order', :read_only=>true, :is_user=>true, cdef_uid: :ord_audit_complete_by},
          :ord_audit_complete_date=>{:label=>'Audit Completed At',:data_type=>:date,:module_type=>'Order', :read_only=>true, cdef_uid: :ord_audit_complete_date},
          :ordln_import_country=>{:label=>'Import Country',:data_type=>:string,:module_type=>'OrderLine', cdef_uid: :ordln_import_country},
          :ord_type=>{:label=>'Order Type',:data_type=>:string,:module_type=>'Order', cdef_uid: :ord_type},
          :dsp_type=>{:label=>'DSP Type',:data_type=>:string,:module_type=>'Company', cdef_uid: :cmp_dsp_type},
          :vend_comments=>{:label=>'Vendor Comments',:data_type=>:text,:module_type=>'Company', cdef_uid: :cmp_vend_comments},
          :dsp_effective_date=>{:label=>'DSP Effective Date',:data_type=>:date,:module_type=>'Company', cdef_uid: :cmp_dsp_effecive_date},
          :ord_cancelled=>{:label=>'Cancelled',:data_type=>:boolean,:module_type=>'Order', cdef_uid: :ord_cancelled},
          :ord_audit_initiated_by=>{:label=>'Audit Initiated By',:data_type=>:integer,:module_type=>'Order',cdef_uid: :ord_audit_initiated_by, :read_only=>true,:is_user=>true},
          :ord_audit_initiated_date=>{:label=>'Audit Initiated At',:data_type=>:date,:module_type=>'Order',:read_only=>true,cdef_uid: :ord_audit_initiated_date},
          :ord_split_order=>{:label=>'Split Order',:data_type=>:boolean,:module_type=>'Order',cdef_uid: :ord_split_order}
        }

        def self.included(base)
          base.extend(::OpenChain::CustomHandler::CustomDefinitionSupport)
          base.extend(ClassMethods)
        end 

        module ClassMethods
          def prep_custom_definitions fields
            prep_custom_defs fields, CUSTOM_DEFINITION_INSTRUCTIONS
          end
        end
      end
    end
  end
end
