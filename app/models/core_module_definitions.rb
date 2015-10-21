module CoreModuleDefinitions
  SECURITY_FILING_LINE = CoreModule.new("SecurityFilingLine","Security Line", {
       :show_field_prefix=>true,
       :unique_id_field_name=>:sfln_line_number,
       :object_from_piece_set_lambda => lambda {|ps| ps.security_filing_line},
       :enabled_lambda => lambda {MasterSetup.get.security_filing_enabled?},
       :key_model_field_uids=>[:sfln_line_number]
   })
  SECURITY_FILING = CoreModule.new("SecurityFiling","Security Filing",{
    :unique_id_field_name=>:sf_transaction_number,
    :object_from_piece_set_lambda => lambda {|ps|
      s_line = ps.security_filing_line
      s_line.nil? ? nil : s_line.security_filing
    },
    :children => [SECURITY_FILING_LINE],
    :child_lambdas => {SECURITY_FILING_LINE => lambda {|parent| parent.security_filing_lines}},
    :child_joins => {SECURITY_FILING_LINE => "LEFT OUTER JOIN security_filing_lines ON security_filings.id = security_filing_lines.security_filing_id"},
    :default_search_columns => [:sf_transaction_number],
    :enabled_lambda => lambda {MasterSetup.get.security_filing_enabled?},
    :key_model_field_uids => [:sf_transaction_number],
    :quicksearch_fields => [:sf_transaction_number,:sf_entry_numbers,:sf_entry_reference_numbers,:sf_po_numbers,:sf_master_bill_of_lading,:sf_container_numbers,:sf_house_bills_of_lading, :sf_host_system_file_number]
  })
  ORDER_LINE = CoreModule.new("OrderLine","Order Line",{
      :show_field_prefix=>true,
      :unique_id_field_name=>:ordln_line_number,
      :object_from_piece_set_lambda => lambda {|ps| ps.order_line},
      :enabled_lambda => lambda { MasterSetup.get.order_enabled? },
      :key_model_field_uids => [:ordln_line_number]
  })
  ORDER = CoreModule.new("Order","Order",
    {:file_formatable=>true,
     :children => [ORDER_LINE],
     :child_lambdas => {ORDER_LINE => lambda {|parent| parent.order_lines}},
     :child_joins => {ORDER_LINE => "LEFT OUTER JOIN order_lines ON orders.id = order_lines.order_id"},
     :default_search_columns => [:ord_ord_num,:ord_ord_date,:ord_ven_name,:ordln_puid,:ordln_ordered_qty],
     :unique_id_field_name => :ord_ord_num,
     :object_from_piece_set_lambda => lambda {|ps|
       o_line = ps.order_line
       o_line.nil? ? nil : o_line.order
     },
     :enabled_lambda => lambda { MasterSetup.get.order_enabled? },
     :key_model_field_uids => [:ord_ord_num],
     :quicksearch_fields => [:ord_ord_num, :ord_cust_ord_no]
    })
  CONTAINER = CoreModule.new("Container", "Container", {
       show_field_prefix: false,
       unique_id_field_name: :con_num,
       object_from_piece_set_lambda: lambda {|ps| ps.shipment_line.nil? ? nil : ps.shipment_line.container},
       enabled_lambda: lambda {MasterSetup.get.shipment_enabled?},
       key_model_field_uids: [:con_uid]
   })
  CARTON_SET = CoreModule.new("CartonSet","Carton Set",{
        show_field_prefix: false,
        unique_id_field_name: :cs_starting_carton,
        object_from_piece_set_lambda: lambda {|ps|
          return nil if ps.shipment_line.nil?
          ps.shipment_line.carton_set.nil? ? nil : ps.shipment_line.carton_set
        },
        enabled_lambda: lambda {MasterSetup.get.shipment_enabled?},
        key_model_field_uids: [:cs_starting_carton]
    })
  SHIPMENT_LINE = CoreModule.new("ShipmentLine", "Shipment Line",{
      :show_field_prefix=>true,
      :unique_id_field_name=>:shpln_line_number,
      :object_from_piece_set_lambda => lambda {|ps| ps.shipment_line},
      :enabled_lambda => lambda { MasterSetup.get.shipment_enabled? },
      :key_model_field_uids => [:shpln_line_number]
  })
  BOOKING_LINE = CoreModule.new('BookingLine', 'Booking Line',
    :show_field_prefix=>true,
    :unique_id_field_name=>:bkln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.booking_line},
    :enabled_lambda => lambda { MasterSetup.get.shipment_enabled? },
    :key_model_field_uids => [:bkln_line_number]
  )
  SHIPMENT = CoreModule.new("Shipment","Shipment",
   {:children=>[SHIPMENT_LINE, BOOKING_LINE],
    :child_lambdas => {SHIPMENT_LINE => lambda {|p| p.shipment_lines}, BOOKING_LINE => lambda {|p| p.booking_lines}},
    :child_joins => {SHIPMENT_LINE => "LEFT OUTER JOIN shipment_lines on shipments.id = shipment_lines.shipment_id", BOOKING_LINE => "LEFT OUTER JOIN booking_lines on shipments.id = booking_lines.shipment_id"},
    :default_search_columns => [:shp_ref,:shp_mode,:shp_ven_name,:shp_car_name],
    :unique_id_field_name=>:shp_ref,
    :object_from_piece_set_lambda => lambda {|ps| ps.shipment_line.nil? ? nil : ps.shipment_line.shipment},
    :enabled_lambda => lambda { MasterSetup.get.shipment_enabled? },
    :key_model_field_uids => [:shp_ref],
    :quicksearch_fields => [:shp_ref,:shp_master_bill_of_lading,:shp_house_bill_of_lading,:shp_booking_number]
    })
  SALE_LINE = CoreModule.new("SalesOrderLine","Sale Line",{
    :show_field_prefix=>true,
    :unique_id_field_name=>:soln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.sales_order_line},
    :enabled_lambda => lambda { MasterSetup.get.sales_order_enabled? },
    :key_model_field_uids => [:soln_line_number]
    })
  SALE = CoreModule.new("SalesOrder","Sale",
    {:children => [SALE_LINE],
      :child_lambdas => {SALE_LINE => lambda {|parent| parent.sales_order_lines}},
      :child_joins => {SALE_LINE => "LEFT OUTER JOIN sales_order_lines ON sales_orders.id = sales_order_lines.sales_order_id"},
      :default_search_columns => [:sale_order_number,:sale_order_date,:sale_cust_name],
      :unique_id_field_name=>:sale_order_number,
      :object_from_piece_set_lambda => lambda {|ps| ps.sales_order_line.nil? ? nil : ps.sales_order_line.sales_order},
      :enabled_lambda => lambda { MasterSetup.get.sales_order_enabled? },
      :key_model_field_uids => [:sale_order_number],
      :quicksearch_fields => [:sale_order_number]
    })
  DELIVERY_LINE = CoreModule.new("DeliveryLine","Delivery Line",{
    :show_field_prefix=>true,
    :unique_id_field_name=>:delln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.delivery_line},
    :enabled_lambda => lambda { MasterSetup.get.delivery_enabled? },
    :key_model_field_uids => [:delln_line_number]
    })
  DELIVERY = CoreModule.new("Delivery","Delivery",
    {:children=>[DELIVERY_LINE],
    :child_lambdas => {DELIVERY_LINE => lambda {|p| p.delivery_lines}},
    :child_joins => {DELIVERY_LINE => "LEFT OUTER JOIN delivery_lines on deliveries.id = delivery_lines.delivery_id"},
    :default_search_columns => [:del_ref,:del_mode,:del_car_name,:del_cust_name],
    :unique_id_field_name=>:del_ref,
    :object_from_piece_set_lambda => lambda {|ps| ps.delivery_line.nil? ? nil : ps.delivery_line.delivery},
    :enabled_lambda => lambda { MasterSetup.get.delivery_enabled? },
    :key_model_field_uids => [:del_ref]
   })
  TARIFF = CoreModule.new("TariffRecord","Tariff",{
     :changed_at_parents_lambda=>lambda {|tr|
       r = []
       c = tr.classification
       unless c.nil?
         p = c.product
         r << p unless p.nil?
       end
       r
     },
     :show_field_prefix=>true,
     :unique_id_field_name=>:hts_line_number,
     :enabled_lambda => lambda { MasterSetup.get.classification_enabled? },
     :key_model_field_uids => [:hts_line_number]
  })
  CLASSIFICATION = CoreModule.new("Classification","Classification",{
       :children => [TARIFF],
       :child_lambdas => {TARIFF => lambda {|p| p.tariff_records}},
       :child_joins => {TARIFF => "LEFT OUTER JOIN tariff_records ON classifications.id = tariff_records.classification_id"},
       :changed_at_parents_lambda=>lambda {|c| c.product.nil? ? [] : [c.product] },
       :show_field_prefix=>true,
       :unique_id_field_name=>:class_cntry_iso,
       :enabled_lambda => lambda { MasterSetup.get.classification_enabled? },
       :key_model_field_uids => [:class_cntry_name,:class_cntry_iso],
       :key_attribute_field_uid => :class_cntry_id
   })
  PRODUCT = CoreModule.new("Product","Product",{
               :statusable=>true,
               :file_formatable=>true,
               :worksheetable=>true,
               :children => [CLASSIFICATION],
               :child_lambdas => {CLASSIFICATION => lambda {|p| p.classifications}},
               :child_joins => {CLASSIFICATION => "LEFT OUTER JOIN classifications ON products.id = classifications.product_id"},
               :default_search_columns => [:prod_uid,:prod_name,:prod_first_hts,:prod_ven_name],
               :bulk_actions_lambda => lambda {|current_user|
                 bulk_actions = {}
                 bulk_actions["Edit"]='bulk_edit_products_path' if current_user.edit_products? || current_user.edit_classifications?
                 bulk_actions["Classify"]={:path=>'/products/bulk_classify.json',:callback=>'BulkActions.submitBulkClassify',:ajax_callback=>'BulkActions.handleBulkClassify'} if current_user.edit_classifications?
                 bulk_actions["Instant Classify"]='show_bulk_instant_classify_products_path' if current_user.edit_classifications? && !InstantClassification.scoped.empty?
                 bulk_actions
               },
               :changed_at_parents_lambda=>lambda {|p| [p]},#only update self
               :business_logic_validations=>lambda {|p|
                 c = p.errors[:base].size
                 p.validate_tariff_numbers
                 c==p.errors[:base].size
               },
               :unique_id_field_name=>:prod_uid,
               :key_model_field_uids => [:prod_uid],
               :quicksearch_fields => [:prod_uid,:prod_name]
   })
  BROKER_INVOICE_LINE = CoreModule.new("BrokerInvoiceLine","Broker Invoice Line",{
       :changed_at_parents_labmda => lambda {|p| p.broker_invoice.nil? ? [] : [p.broker_invoice]},
       :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
       :unique_id_field_name=>:bi_line_charge_code,
       :key_model_field_uids=>[:bi_line_charge_code]
   })
  BROKER_INVOICE = CoreModule.new("BrokerInvoice","Broker Invoice",{
      :default_search_columns => [:bi_brok_ref,:bi_suffix,:bi_invoice_date,:bi_invoice_total],
      :unique_id_field_name => :bi_suffix,
      :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
      :key_model_field_uids=>[:bi_brok_ref,:bi_suffix],
      :children => [BROKER_INVOICE_LINE],
      :child_lambdas => {BROKER_INVOICE_LINE => lambda {|i| i.broker_invoice_lines}},
      :child_joins => {BROKER_INVOICE_LINE => "LEFT OUTER JOIN broker_invoice_lines on broker_invoices.id = broker_invoice_lines.broker_invoice_id"},
      :quicksearch_fields => [:bi_invoice_number, {model_field_uid: :bi_brok_ref, joins: [:entry]}]
  })
  COMMERCIAL_INVOICE_TARIFF = CoreModule.new("CommercialInvoiceTariff","Invoice Tariff",{
       :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
       :show_field_prefix => true,
       :unique_id_field_name=>:cit_hts_code,
       :key_model_field_uids=>[:cit_hts_code]
   })
  COMMERCIAL_INVOICE_LINE = CoreModule.new("CommercialInvoiceLine","Invoice Line",{
     :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
     :show_field_prefix=>true,
     :unique_id_field_name=>:cil_line_number,
     :key_model_field_uids=>[:cil_line_number],
     :children => [COMMERCIAL_INVOICE_TARIFF],
     :child_lambdas => {COMMERCIAL_INVOICE_TARIFF=>lambda {|i| i.commercial_invoice_tariffs}},
     :child_joins => {COMMERCIAL_INVOICE_TARIFF=> "LEFT OUTER JOIN commercial_invoice_tariffs on commercial_invoice_lines.id = commercial_invoice_tariffs.commercial_invoice_line_id"}
  })
  COMMERCIAL_INVOICE = CoreModule.new("CommercialInvoice","Invoice",{
      :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
      :unique_id_field_name => :invoice_number,
      :show_field_prefix=>true,
      :key_model_field_uids=>[:invoice_number],
      :children => [COMMERCIAL_INVOICE_LINE],
      :child_lambdas => {COMMERCIAL_INVOICE_LINE=> lambda {|i| i.commercial_invoice_lines}},
      :child_joins => {COMMERCIAL_INVOICE_LINE => "LEFT OUTER JOIN commercial_invoice_lines on commercial_invoices.id = commercial_invoice_lines.commercial_invoice_id"}
  })
  ENTRY = CoreModule.new("Entry","Entry",{
       :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
       :default_search_columns => [:ent_brok_ref,:ent_entry_num,:ent_release_date],
       :unique_id_field_name=>:ent_brok_ref,
       :key_model_field_uids=>[:ent_brok_ref],
       :bulk_actions_lambda => lambda {|current_user|
         bulk_actions = {}
         bulk_actions["Update Images"] = "bulk_get_images_entries_path" if current_user.company.master? && current_user.view_entries?
         bulk_actions["Update Entries"] = "bulk_request_entry_data_entries_path" if current_user.sys_admin?
         bulk_actions
       },
       :children => [COMMERCIAL_INVOICE],
       :child_lambdas => {COMMERCIAL_INVOICE => lambda {|ent| ent.commercial_invoices}},
       :child_joins => {COMMERCIAL_INVOICE => "LEFT OUTER JOIN commercial_invoices on entries.id = commercial_invoices.entry_id"},
       :quicksearch_fields => [:ent_brok_ref,:ent_entry_num,:ent_po_numbers,:ent_customer_references,:ent_mbols,:ent_container_nums,:ent_cargo_control_number,:ent_hbols,:ent_commercial_invoice_numbers],
       :quicksearch_sort_by_mf => :ent_file_logged_date,
       :logical_key_lambda => lambda {|obj| "#{obj.source_system}_#{obj.broker_reference}"}
   })
  OFFICIAL_TARIFF = CoreModule.new("OfficialTariff","HTS Regulation",:default_search_columns=>[:ot_hts_code,:ot_cntry_iso,:ot_full_desc,:ot_common_rate], :quicksearch_fields=> [:ot_hts_code,:ot_full_desc])
  PLANT_PRODUCT_GROUP_ASSIGNMENT = CoreModule.new('PlantProductGroupAssignment','Plant Product Group Assignment',default_search_columns:[:ppga_pg_name], show_field_prefix: true)
  PLANT = CoreModule.new("Plant","Plant",
    default_search_columns: [:plant_name],
    unique_id_field_name: :plant_name,
    show_field_prefix: true,
    key_model_field_uids: [:plant_name],
    children: [PLANT_PRODUCT_GROUP_ASSIGNMENT],
    child_lambdas: {PLANT_PRODUCT_GROUP_ASSIGNMENT => lambda {|p| p.plant_product_group_assignments}},
    child_joins: {PLANT_PRODUCT_GROUP_ASSIGNMENT => "LEFT OUTER JOIN plant_product_group_assignments ON plants.id = plant_product_group_assignments.plant_id"},
    available_addresses_lambda: lambda {|plant| plant.company ? plant.company.addresses.order(:name, :city, :line_1) : [] }
  )
  # NOTE: Since we're setting up VENDOR as a full-blown core module based search, it means other variants of Company itself cannot have one, unless further changes are made
  # to the searching classes in quicksearch_controller, api_core_module_base, application_controller, search_query, search_query_controller_helper (possibly others).
  COMPANY = CoreModule.new("Company","Vendor",
    default_search_columns: [:cmp_name,:cmp_sys_code],
    unique_id_field_name: :cmp_sys_code,
    key_model_field_uids: :cmp_sys_code,
    children: [PLANT],
    child_lambdas: {PLANT => lambda {|c| c.plants}},
    child_joins: {PLANT => "LEFT OUTER JOIN plants plants ON companies.id = plants.company_id"},
    edit_path_proc: Proc.new {|obj| nil},
    view_path_proc: Proc.new {|obj| vendor_path(obj)},
    quicksearch_lambda: lambda {|user, scope| scope.where(Company.search_where(user))},
    enabled_lambda: lambda { MasterSetup.get.vendor_management_enabled? },
    quicksearch_fields: [:cmp_name],
    available_addresses_lambda: lambda {|company| company.addresses.order(:name, :city, :line_1) }
  )

  DRAWBACK_CLAIM = CoreModule.new("DrawbackClaim", "Drawback Claim",
     default_search_columns: [:dc_name, :dc_imp_name, :dc_exports_start_date, :dc_exports_end_date],
     unique_id_field_name: :dc_name,
     key_model_field_uids: [:dc_name],
     children: [],
     child_lambdas: {},
     child_joins: {},
     enabled_lambda: lambda { MasterSetup.get.drawback_enabled? }
  )
end