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
      #was ord_rule_state
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
      [18,:ord_product_category,:product_category,'Product Category',{data_type: :string}],
      [19,:ord_payment_terms,:terms_of_payment,'Terms of Payment', {data_type: :string}],
      [20,:ord_currency,:currency,'Currency',{data_type: :string}],
      [21,:ord_total_cost,:total_cost,'Total Cost',{
        data_type: :decimal,
        read_only: true,
        export_lambda: lambda {|obj|
          obj.order_lines.inject(0) {|init,ol| init + ol.total_cost}
        },
        qualified_field_name: "(SELECT SUM(#{OrderLine::TOTAL_COST_SUBQUERY}) FROM order_lines WHERE order_lines.order_id = orders.id)"
      }],
      [22,:ord_ship_to_count,:ship_to_count,'Ship To Count', {data_type: :integer,
        read_only: true,
        export_lambda: lambda {|obj| obj.order_lines.collect {|ol| ol.ship_to_id}.uniq.length},
        qualified_field_name: "(SELECT COUNT(DISTINCT ship_to_id) FROM order_lines WHERE order_lines.order_id = orders.id)"
      }],
      [23,:ord_tppsr_db_id,:tpp_survey_response_id,'TPP Certification DB ID',{data_type: :integer}],
      [24,:ord_tppsr_name,:name,'TPP Certification Name', {
        data_type: :string,
        export_lambda: lambda { |obj|
          return "" unless obj.tpp_survey_response
          return obj.tpp_survey_response.long_name
        },
        qualified_field_name: "(SELECT CONCAT(surveys.name,IF(length(survey_responses.subtitle)>0,CONCAT(' - ',survey_responses.subtitle),'')) FROM survey_responses INNER JOIN surveys ON survey_responses.survey_id = surveys.id WHERE survey_responses.id = orders.tpp_survey_response_id)",
        read_only: true
      }],
    ]
    add_fields CoreModule::ORDER, make_vendor_arrays(100,"ord","orders")
    add_fields CoreModule::ORDER, make_ship_to_arrays(200,"ord","orders")
    add_fields CoreModule::ORDER, make_division_arrays(300,"ord","orders")
    add_fields CoreModule::ORDER, make_master_setup_array(400,"ord")
    add_fields CoreModule::ORDER, make_importer_arrays(500,"ord","orders")
    add_fields CoreModule::ORDER, make_agent_arrays(600,'ord','orders')
    add_fields CoreModule::ORDER, make_factory_arrays(700,'ord','orders')
    add_fields CoreModule::ORDER, make_business_rule_arrays(800,'ord','orders','Order')
    add_fields CoreModule::ORDER, make_ship_from_arrays(900,'ord','orders')
    add_fields CoreModule::ORDER, make_address_arrays(1000,"ord",'orders','order_from')
    add_fields CoreModule::ORDER, make_comment_arrays(1100,"ord","Order")
  end
end; end; end
