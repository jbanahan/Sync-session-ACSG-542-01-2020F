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
      [10,:cmp_alliance,:alliance_customer_number,"Alliance Customer Number",{
        data_type: :string,
        can_view_lambda: lambda {|u| u.company.broker?},
        can_edit_lambda: admin_edit_lambda()
      }],
      [11,:cmp_broker,:broker,"Is Broker",{data_type: :boolean,
        can_edit_lambda: admin_edit_lambda()
      }],
      [12,:cmp_fenix,:fenix_customer_number,"Fenix Customer Number",{
        data_type: :string,
        can_view_lambda: lambda {|u| u.company.broker?},
        can_edit_lambda: admin_edit_lambda()
      }],
      [13,:cmp_agent,:agent,"Is Agent",{data_type: :boolean,
        can_edit_lambda: admin_edit_lambda()
      }],
      [14,:cmp_factory,:factory,"Is Factory",{data_type: :boolean,
        can_edit_lambda: admin_edit_lambda()
      }],
      [15,:cmp_order_view_template,:order_view_template,'Order View Template',{
        data_type: :string,
        can_edit_lambda: admin_edit_lambda(),
        can_view_lambda: admin_edit_lambda()
      }]
    ]
  end
end; end; end
