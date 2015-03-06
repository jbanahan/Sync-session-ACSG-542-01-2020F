module OpenChain; module ModelFieldDefinition; module OrderFieldDefinition
  def add_order_fields
    add_fields CoreModule::ORDER, [
      [1,:ord_ord_num,:order_number,"Order Number"],
      [2,:ord_ord_date,:order_date,"Order Date",{:data_type=>:date}],
      [3,:ord_ms_state,:state,"Milestone State",{:data_type=>:string,
        :import_lambda => lambda {|o,d| return "Milestone State was ignored. (read only)"},
        :export_lambda => lambda {|obj| obj.worst_milestone_state },
        :qualified_field_name => %{(SELECT milestone_forecast_sets.state as ms_state
            FROM milestone_forecast_sets
            INNER JOIN piece_sets on piece_sets.id = milestone_forecast_sets.piece_set_id
            INNER JOIN order_lines on order_lines.id = piece_sets.order_line_id
            WHERE order_lines.order_id = orders.id
            ORDER BY FIELD(milestone_forecast_sets.state,'Achieved','Pending','Unplanned','Missed','Trouble','Overdue') DESC LIMIT 1)}
      },],
      [4,:ord_cust_ord_no, :customer_order_number, "Customer Order Number"],
      [5,:ord_last_exported_from_source,:last_exported_from_source,"System Extract Date",{:data_type=>:datetime}],
      [6,:ord_mode, :mode, "Mode of Transport",{:data_type=>:string}],
      [7,:ord_rule_state,:rule_state,"Business Rule State",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Business Rule State ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rules_state },
        :qualified_field_name=> "(select state
          from business_validation_results bvr
          where bvr.validatable_type = 'Order' and bvr.validatable_id = orders.id
          order by (
          case bvr.state
              when 'Fail' then 0
              when 'Review' then 1
              when 'Pass' then 2
              when 'Skipped' then 3
              else 4
          end
          )
          limit 1)"
      }],
      [8,:ord_revised_date,:last_revised_date, 'Last Revised Date',{data_type: :date}],
      [9,:ord_approval_status,:approval_status,'Approval Status'],
      [10,:ord_window_start,:ship_window_start,'Ship Window Start Date',{data_type: :date}],
      [11,:ord_window_end,:ship_window_end,'Ship Window End Date',{data_type: :date}],
      [12,:ord_first_exp_del,:first_expected_delivery_date,'First Expected Delivery Date',{data_type: :date}],
      [13,:ord_fob_point,:fob_point,'FOB Point',{data_type: :string}],
      [14,:ord_closed_at,:closed_at,'Closed At',{data_type: :datetime}],
      [15,:ord_closed_by,:username,"Closed By", {
        :import_lambda => lambda {|a,b| return "Closed By cannot be set by import, ignored."},
        :export_lambda => lambda {|obj|
          obj.closed_by.blank? ? "" : obj.closed_by.username
        },
        :qualified_field_name => "(SELECT username FROM users where users.id = orders.closed_by_id)",
        :data_type=>:string
      }],
      [16,:ord_season,:season,'Season',{data_type: :string}],
      [17,:ord_terms,:terms_of_sale,'Terms of Sale',{data_type: :string}],
      [18,:ord_product_category,:product_category,'Product Category',{data_type: :string}]
    ]
    add_fields CoreModule::ORDER, make_vendor_arrays(100,"ord","orders")
    add_fields CoreModule::ORDER, make_ship_to_arrays(200,"ord","orders")
    add_fields CoreModule::ORDER, make_division_arrays(300,"ord","orders")
    add_fields CoreModule::ORDER, make_master_setup_array(400,"ord")
    add_fields CoreModule::ORDER, make_importer_arrays(500,"ord","orders")
    add_fields CoreModule::ORDER, make_agent_arrays(600,'ord','orders')
    add_fields CoreModule::ORDER, make_factory_arrays(700,'ord','orders')
  end
end; end; end
