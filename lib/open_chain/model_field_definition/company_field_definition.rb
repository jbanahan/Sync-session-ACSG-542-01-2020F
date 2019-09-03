module OpenChain; module ModelFieldDefinition; module CompanyFieldDefinition
  def add_company_fields
    add_fields CoreModule::COMPANY, [
      [1,:cmp_sys_code,:system_code,"System Code",{data_type: :string,
        can_edit_lambda: admin_edit_lambda()
      }],
      [2,:cmp_name,:name,"Name",{data_type: :string}],
      [3,:cmp_carrier,:carrier,"Is Carrier",{data_type: :boolean,
        can_edit_lambda: admin_edit_lambda()
      }],
      [4,:cmp_vendor,:vendor,"Is Vendor",{data_type: :boolean,
        can_edit_lambda: admin_edit_lambda()
      }],
      [5,:cmp_created_at,:created_at,"Create Date",{data_type: :datetime, read_only: true}],
      [6,:cmp_updated_at,:updated_at,"Update Date",{data_type: :datetime, read_only: true}],
      [7,:cmp_locked,:locked,"Is Locked",{data_type: :boolean,
        can_edit_lambda: admin_edit_lambda()
      }],
      [8,:cmp_customer,:customer,"Is Customer",{data_type: :boolean,
        can_edit_lambda: admin_edit_lambda()
      }],
      [9,:cmp_importer,:importer,"Is Importer",{data_type: :boolean,
        can_edit_lambda: admin_edit_lambda()
      }],
      [10,:cmp_alliance,:kewill_customer_number,"Alliance Customer Number",{
        data_type: :string,
        can_view_lambda: lambda {|u| u.company.broker?},
        can_edit_lambda: admin_edit_lambda(),
        qualified_field_name: "(SELECT cm_id.code FROM system_identifiers cm_id WHERE cm_id.system = 'Customs Management' and cm_id.company_id = companies.id)",
        import_lambda: lambda {|obj, data| obj.set_system_identifier("Customs Management", data) }
      }],
      [11,:cmp_broker,:broker,"Is Broker",{data_type: :boolean,
        can_edit_lambda: admin_edit_lambda()
      }],
      [12,:cmp_fenix,:fenix_customer_identifier,"Fenix Customer Number",{
        data_type: :string,
        can_view_lambda: lambda {|u| u.company.broker?},
        can_edit_lambda: admin_edit_lambda(),
        qualified_field_name: "(SELECT f_id.code FROM system_identifiers f_id WHERE f_id.system = 'Fenix' and f_id.company_id = companies.id)",
        import_lambda: lambda {|obj, data| obj.set_system_identifier("Fenix", data) }
      }],
      [13,:cmp_agent,:agent,"Is Agent",{data_type: :boolean,
        can_edit_lambda: admin_edit_lambda()
      }],
      [14,:cmp_factory,:factory,"Is Factory",{data_type: :boolean,
        can_edit_lambda: admin_edit_lambda()
      }],
      [16, :comp_show_buiness_rules, :show_business_rules, "Show Business Rules", {data_type: :boolean, can_edit_lambda: admin_edit_lambda(), can_view_lambda: admin_edit_lambda()}],
      [17,:cmp_enabled_booking_types,:enabled_booking_types,'Enabled Booking Types',{data_type: :string, can_edit_lambda: admin_edit_lambda()}],
      [18,:cmp_slack_channel,:slack_channel,'Slack Channel',{data_type: :string, can_view_lambda: admin_edit_lambda(), can_edit_lambda: admin_edit_lambda()}],
      [19,:cmp_forwarder,:forwarder,"Is Forwarder",{data_type: :boolean,
        can_edit_lambda: admin_edit_lambda()
      }],
      [20, :cmp_ticketing_system_code, :ticketing_system_code, "Ticketing System Code", {data_type: :string, 
        can_edit_lambda: admin_edit_lambda()
      }],
      [21, :cmp_fiscal_reference, :fiscal_reference, "Fiscal Reference", {data_type: :string,
        can_edit_lambda: admin_edit_lambda()
      }],
      [22,:cmp_cargowise,:cargowise_customer_number,"Cargowise Customer Number",{
        data_type: :string,
        can_view_lambda: lambda {|u| u.company.broker?},
        can_edit_lambda: admin_edit_lambda(),
        qualified_field_name: "(SELECT cw_id.code FROM system_identifiers cw_id WHERE cw_id.system = 'Cargowise' and cw_id.company_id = companies.id)",
        import_lambda: lambda {|obj, data| obj.set_system_identifier("Cargowise", data) }
      }],
    ]
    add_fields CoreModule::COMPANY, make_attachment_arrays(100,'cmp',CoreModule::COMPANY)
    add_fields CoreModule::COMPANY, make_business_rule_arrays(200,'cmp','companies','Company')
  end
end; end; end
