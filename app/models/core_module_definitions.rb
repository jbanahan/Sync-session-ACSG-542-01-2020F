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
    :children => [SecurityFilingLine],
    :child_lambdas => {SecurityFilingLine => lambda {|parent| parent.security_filing_lines}},
    :child_joins => {SecurityFilingLine => "LEFT OUTER JOIN security_filing_lines ON security_filings.id = security_filing_lines.security_filing_id"},
    :default_search_columns => [:sf_transaction_number],
    :enabled_lambda => lambda {MasterSetup.get.security_filing_enabled?},
    :key_model_field_uids => [:sf_transaction_number],
    :quicksearch_fields => [:sf_transaction_number,:sf_entry_numbers,:sf_entry_reference_numbers,:sf_po_numbers,:sf_master_bill_of_lading,:sf_container_numbers,:sf_house_bills_of_lading, :sf_host_system_file_number],
    :module_chain => [SecurityFiling, SecurityFilingLine]
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
     :children => [OrderLine],
     :child_lambdas => {OrderLine => lambda {|parent| parent.order_lines}},
     :child_joins => {OrderLine => "LEFT OUTER JOIN order_lines ON orders.id = order_lines.order_id"},
     :default_search_columns => [:ord_ord_num,:ord_ord_date,:ord_ven_name,:ordln_puid,:ordln_ordered_qty],
     :unique_id_field_name => :ord_ord_num,
     :object_from_piece_set_lambda => lambda {|ps|
       o_line = ps.order_line
       o_line.nil? ? nil : o_line.order
     },
     :enabled_lambda => lambda { MasterSetup.get.order_enabled? },
     :key_model_field_uids => [:ord_ord_num],
     :quicksearch_fields => [:ord_ord_num, :ord_cust_ord_no],
     :module_chain => [Order, OrderLine]
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
   {:children=>[ShipmentLine, BookingLine],
    :child_lambdas => {ShipmentLine => lambda {|p| p.shipment_lines}, BookingLine => lambda {|p| p.booking_lines}},
    :child_joins => {ShipmentLine => "LEFT OUTER JOIN shipment_lines on shipments.id = shipment_lines.shipment_id", BookingLine => "LEFT OUTER JOIN booking_lines on shipments.id = booking_lines.shipment_id"},
    :default_search_columns => [:shp_ref,:shp_mode,:shp_ven_name,:shp_car_name],
    :unique_id_field_name=>:shp_ref,
    :object_from_piece_set_lambda => lambda {|ps| ps.shipment_line.nil? ? nil : ps.shipment_line.shipment},
    :enabled_lambda => lambda { MasterSetup.get.shipment_enabled? },
    :key_model_field_uids => [:shp_ref],
    :quicksearch_fields => [:shp_ref,:shp_master_bill_of_lading,:shp_house_bill_of_lading,:shp_booking_number, :shp_importer_reference],
    :module_chain => [Shipment, ShipmentLine, BookingLine]
    })
  SALE_LINE = CoreModule.new("SalesOrderLine","Sale Line",{
    :show_field_prefix=>true,
    :unique_id_field_name=>:soln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.sales_order_line},
    :enabled_lambda => lambda { MasterSetup.get.sales_order_enabled? },
    :key_model_field_uids => [:soln_line_number]
    })
  SALE = CoreModule.new("SalesOrder","Sale",
    {:children => [SalesOrderLine],
      :child_lambdas => {SalesOrderLine => lambda {|parent| parent.sales_order_lines}},
      :child_joins => {SalesOrderLine => "LEFT OUTER JOIN sales_order_lines ON sales_orders.id = sales_order_lines.sales_order_id"},
      :default_search_columns => [:sale_order_number,:sale_order_date,:sale_cust_name],
      :unique_id_field_name=>:sale_order_number,
      :object_from_piece_set_lambda => lambda {|ps| ps.sales_order_line.nil? ? nil : ps.sales_order_line.sales_order},
      :enabled_lambda => lambda { MasterSetup.get.sales_order_enabled? },
      :key_model_field_uids => [:sale_order_number],
      :quicksearch_fields => [:sale_order_number],
      :module_chain => [SalesOrder, SalesOrderLine]
    })
  DELIVERY_LINE = CoreModule.new("DeliveryLine","Delivery Line",{
    :show_field_prefix=>true,
    :unique_id_field_name=>:delln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.delivery_line},
    :enabled_lambda => lambda { MasterSetup.get.delivery_enabled? },
    :key_model_field_uids => [:delln_line_number]
    })
  DELIVERY = CoreModule.new("Delivery","Delivery",
    {:children=>[DeliveryLine],
    :child_lambdas => {DeliveryLine => lambda {|p| p.delivery_lines}},
    :child_joins => {DeliveryLine => "LEFT OUTER JOIN delivery_lines on deliveries.id = delivery_lines.delivery_id"},
    :default_search_columns => [:del_ref,:del_mode,:del_car_name,:del_cust_name],
    :unique_id_field_name=>:del_ref,
    :object_from_piece_set_lambda => lambda {|ps| ps.delivery_line.nil? ? nil : ps.delivery_line.delivery},
    :enabled_lambda => lambda { MasterSetup.get.delivery_enabled? },
    :key_model_field_uids => [:del_ref],
    :module_chain => [Delivery, DeliveryLine]
   })
  PLANT_VARIANT_ASSIGNMENT = CoreModule.new("PlantVariantAssignment","Plant Variant Assignment",{
    :show_field_prefix=>true,
    :unique_id_field_name=>:pva_assignment_id,
    :enabled_lambda=>lambda {MasterSetup.get.variant_enabled?},
    :key_model_field_uids=>[:pva_assignment_id],
    :key_attribute_field_uid=>:pva_assignment_id
    })
  VARIANT = CoreModule.new("Variant","Variant",{
    :children=>[PlantVariantAssignment],
    :child_lambdas=>{PlantVariantAssignment=>lambda {|v| v.plant_variant_assignments}},
    :changed_at_parents_lambda=>lambda {|c| c.product.nil? ? [] : [c.product] },
    :enabled_lambda=>lambda {MasterSetup.get.variant_enabled?},
    :show_field_prefix=>false,
    :unique_id_field_name=>:var_identifier,
    :key_model_field_uids => [:var_identifier],
    :key_attribute_field_uid => :var_identifier
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
       :children => [TariffRecord],
       :child_lambdas => {TariffRecord => lambda {|p| p.tariff_records}},
       :child_joins => {TariffRecord => "LEFT OUTER JOIN tariff_records ON classifications.id = tariff_records.classification_id"},
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
       :children => [Classification,Variant],
       :child_lambdas => {
          Classification => lambda {|p| p.classifications},
          Variant => lambda {|p| p.variants}
       },
       :child_joins => {
          Classification => "LEFT OUTER JOIN classifications ON products.id = classifications.product_id",
          Variant => "LEFT OUTER JOIN variants ON products.id = variants.product_id"
        },
       :default_search_columns => [:prod_uid,:prod_name,:prod_first_hts],
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
       :quicksearch_fields => [:prod_uid,:prod_name],
       :quicksearch_extra_fields => [lambda do
          # This is here SOLELY for the case where we're running the migration to actually create
          # the show_quicksearch field (since this code is referenced from an initializer and will load
          # when migrations run)
          if Country.new.respond_to?(:quicksearch_show?)
            Country.select("id").show_quicksearch.order(:classification_rank, :name).map{ |c| "*fhts_1_#{c.id}".to_sym }
          else
            []
          end
       end],
       :module_chain => [Product, Classification, TariffRecord]
   })
  BROKER_INVOICE_LINE = CoreModule.new("BrokerInvoiceLine","Broker Invoice Line",{
       :changed_at_parents_lambda => lambda {|p| p.broker_invoice.nil? ? [] : [p.broker_invoice]},
       :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
       :unique_id_field_name=>:bi_line_charge_code,
       :key_model_field_uids=>[:bi_line_charge_code],
       :show_field_prefix=>true,
   })
  BROKER_INVOICE = CoreModule.new("BrokerInvoice","Broker Invoice",{
      :default_search_columns => [:bi_brok_ref,:bi_suffix,:bi_invoice_date,:bi_invoice_total],
      :unique_id_field_name => :bi_suffix,
      :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
      :key_model_field_uids=>[:bi_brok_ref,:bi_suffix],
      :children => [BrokerInvoiceLine],
      :child_lambdas => {BrokerInvoiceLine => lambda {|i| i.broker_invoice_lines}},
      :child_joins => {BrokerInvoiceLine => "LEFT OUTER JOIN broker_invoice_lines on broker_invoices.id = broker_invoice_lines.broker_invoice_id"},
      :quicksearch_fields => [:bi_invoice_number, {model_field_uid: :bi_brok_ref, joins: [:entry]}],
      :module_chain => [BrokerInvoice, BrokerInvoiceLine]
  })
  COMMERCIAL_INVOICE_LACEY = CoreModule.new("CommercialInvoiceLaceyComponent","Lacey Component",{
       :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
       :show_field_prefix => true,
       :unique_id_field_name=>:lcy_line_number,
       :key_model_field_uids=>[:lcy_line_number]
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
     :children => [CommercialInvoiceTariff],
     :child_lambdas => {CommercialInvoiceTariff=>lambda {|i| i.commercial_invoice_tariffs}},
     :child_joins => {CommercialInvoiceTariff=> "LEFT OUTER JOIN commercial_invoice_tariffs on commercial_invoice_lines.id = commercial_invoice_tariffs.commercial_invoice_line_id"}
  })
  COMMERCIAL_INVOICE = CoreModule.new("CommercialInvoice","Invoice",{
      :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
      :unique_id_field_name => :ci_invoice_number,
      :show_field_prefix=>true,
      :key_model_field_uids=>[:ci_invoice_number],
      :children => [CommercialInvoiceLine],
      :child_lambdas => {CommercialInvoiceLine=> lambda {|i| i.commercial_invoice_lines}},
      :child_joins => {CommercialInvoiceLine => "LEFT OUTER JOIN commercial_invoice_lines on commercial_invoices.id = commercial_invoice_lines.commercial_invoice_id"}
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
       :children => [CommercialInvoice],
       :child_lambdas => {
          # Attachment is purposefully left out here, there is no way to restore those due to the way paperclip functions behind the scenes..
          # if the record is gone, then the data representing it on S3 is also gone - there is no restoring it.  Also, the s3 path is composed using
          # the attachment id, so trying to restore deleted attachments would also not work due to the ids misaligning.
          # If we do true snapshot restores for entries (which I don't think we ever should since VFI Track is not the datasource of record for
          # entries) we will have to make a custom way for entry to deal with attachments - poentially just retaining the attachments.
          CommercialInvoice => lambda {|ent| ent.commercial_invoices},
          BrokerInvoice => lambda {|ent| ent.broker_invoices },
          Container => lambda {|ent| ent.containers },
          EntryComment => lambda {|ent| ent.entry_comments }
       },
       :child_joins => {CommercialInvoice => "LEFT OUTER JOIN commercial_invoices on entries.id = commercial_invoices.entry_id"},
       :quicksearch_fields => [:ent_brok_ref,:ent_entry_num,:ent_po_numbers,:ent_customer_references,:ent_mbols,:ent_container_nums,:ent_cargo_control_number,:ent_hbols,:ent_commercial_invoice_numbers],
       :quicksearch_extra_fields => [:ent_cust_num, :ent_release_cert_message, :ent_fda_message],
       :quicksearch_sort_by_mf => :ent_file_logged_date,
       :logical_key_lambda => lambda {|obj| "#{obj.source_system}_#{obj.broker_reference}"},
       :module_chain => [Entry, CommercialInvoice, CommercialInvoiceLine, CommercialInvoiceTariff],
       :snapshot_descriptor => SnapshotDescriptor.for(Entry,
          entry_comments: {type: EntryComment},
          commercial_invoices: {type: CommercialInvoice, children: {
            commercial_invoice_lines: {type: CommercialInvoiceLine, children: {
                commercial_invoice_tariffs: {type: CommercialInvoiceTariff, children: {
                    commercial_invoice_lacey_components: {type: CommercialInvoiceLaceyComponent}
                  }}
              }}
          }},
          containers: {type: Container},
          broker_invoices: {type: BrokerInvoice, children: {
            broker_invoice_lines: {type: BrokerInvoiceLine}
          }},
          attachments: {type: Attachment}
       )
   })

  # ENTRY_COMMENT core module is present solely for use in snapshotting, it is not meant to be used
  # as a module.  The only thing set up for it is model fields.
  # Entry Comment has no field that is really suitable for use in key_model_field_uids or in unique_id_field,
  # as such comments won't work with snapshot diffs at the moment - diffs aren't accessible from entries so
  # that's not a big deal.
  ENTRY_COMMENT = CoreModule.new("EntryComment", "Entry Note", {})

  OFFICIAL_TARIFF = CoreModule.new("OfficialTariff","HTS Regulation",{
       :default_search_columns=>[:ot_hts_code,:ot_cntry_iso,:ot_full_desc,:ot_common_rate],
       :quicksearch_fields=> [:ot_hts_code,:ot_full_desc],
       :quicksearch_extra_fields => [:ot_cntry_name]
   })
  PLANT_PRODUCT_GROUP_ASSIGNMENT = CoreModule.new('PlantProductGroupAssignment','Plant Product Group Assignment',
    unique_id_field_name: :ppga_pg_name,
    default_search_columns:[:ppga_pg_name],
    key_model_field_uids: [:ppga_pg_name],
    show_field_prefix: true)
  PLANT = CoreModule.new("Plant","Plant",
    default_search_columns: [:plant_name],
    unique_id_field_name: :plant_name,
    show_field_prefix: true,
    key_model_field_uids: [:plant_name],
    children: [PlantProductGroupAssignment],
    child_lambdas: {PlantProductGroupAssignment => lambda {|p| p.plant_product_group_assignments}},
    child_joins: {PlantProductGroupAssignment => "LEFT OUTER JOIN plant_product_group_assignments ON plants.id = plant_product_group_assignments.plant_id"},
    available_addresses_lambda: lambda {|plant| plant.company ? plant.company.addresses.order(:name, :city, :line_1) : [] }
  )
  # NOTE: Since we're setting up VENDOR as a full-blown core module based search, it means other variants of Company itself cannot have one, unless further changes are made
  # to the searching classes in quicksearch_controller, api_core_module_base, application_controller, search_query, search_query_controller_helper (possibly others).
  COMPANY = CoreModule.new("Company","Vendor",
    default_search_columns: [:cmp_name,:cmp_sys_code],
    unique_id_field_name: :cmp_sys_code,
    key_model_field_uids: :cmp_sys_code,
    children: [Plant],
    child_lambdas: {
      Plant => lambda {|c| c.plants},
      Address => lambda {|c| c.addresses}
    },
    child_joins: {Plant => "LEFT OUTER JOIN plants plants ON companies.id = plants.company_id"},
    edit_path_proc: Proc.new {|obj| nil},
    view_path_proc: Proc.new {|obj| vendor_path(obj)},
    quicksearch_lambda: lambda {|user, scope| scope.where(Company.search_where(user))},
    enabled_lambda: lambda { MasterSetup.get.vendor_management_enabled? },
    quicksearch_fields: [:cmp_name],
    available_addresses_lambda: lambda {|company| company.addresses.order(:name, :city, :line_1) },
    module_chain: [Company, Plant, PlantProductGroupAssignment],
    snapshot_descriptor: SnapshotDescriptor.for(Company,
      plants: {
        type:Plant,
        children: {
          plant_product_group_assignments:{
            type: PlantProductGroupAssignment
          }
        }
      },
      addresses: {type:Address}
    )
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

  SUMMARY_STATEMENT = CoreModule.new("SummaryStatement", "Summary Statement", {
    default_search_columns: [:sum_statement_num],
    :unique_id_field_name => :sum_statement_num,
    key_model_field_uids: [:sum_statement_num],
    children: [BrokerInvoice],
    child_lambdas: {BrokerInvoice => lambda {|stat| stat.broker_invoices}},
    child_joins: {BrokerInvoice => "LEFT OUTER JOIN broker_invoices on summary_statements.id = broker_invoices.summary_statement_id"},
    quicksearch_fields: [:sum_statement_num],
    quicksearch_sort_by_mf: :sum_statement_num,
    enabled_lambda: lambda { MasterSetup.get.broker_invoice_enabled? },
    module_chain: [SummaryStatement, BrokerInvoice, BrokerInvoiceLine]
  })

  VFI_INVOICE = CoreModule.new("VfiInvoice", "Vfi Invoice", {
    default_search_columns: [:vi_invoice_number, :vi_invoice_date, :vi_invoice_total],
    :unique_id_field_name => :vi_invoice_number,
    key_model_field_uids: [:vi_invoice_number],
    children: [VfiInvoiceLine],
    child_lambdas: {VfiInvoiceLine => lambda {|i| i.vfi_invoice_lines}},
    child_joins: {VfiInvoiceLine => "LEFT OUTER JOIN vfi_invoice_lines on vfi_invoices.id = vfi_invoice_lines.vfi_invoice_id"},
    quicksearch_fields: [:vi_invoice_number],
    quicksearch_sort_by_mf: :vi_invoice_number,
    enabled_lambda: lambda { MasterSetup.get.vfi_invoice_enabled? },
    module_chain: [VfiInvoice, VfiInvoiceLine]
  })

  VFI_INVOICE_LINE = CoreModule.new("VfiInvoiceLine","Vfi Invoice Line",{
    :changed_at_parents_lambda => lambda {|p| p.vfi_invoice.nil? ? [] : [p.vfi_invoice]},
    :enabled_lambda => lambda { CoreModule::VFI_INVOICE.enabled? },
    :unique_id_field_name=>:vi_line_number,
    :key_model_field_uids=>[:vi_line_number],
    :show_field_prefix=>true
   })

  PRODUCT_VENDOR_ASSIGNMENT = CoreModule.new("ProductVendorAssignment","Product Vendor Assignment", {
    default_search_columns: [:pva_ven_name, :pva_puid, :pva_pname],
    key_model_field_uids: [:pva_ven_name, :pva_puid]
  })

  # ATTACHMENT core module is present solely for use in snapshotting, it is not meant to be used
  # as a module.  The only thing set up for it is model fields.
  # Attachment has no field that is really suitable for use in key_model_field_uids or in unique_id_field,
  # as such attachments won't work with snapshot diffs at the moment - diffs aren't accessible from entries so
  # that's not a big deal.
  ATTACHMENT = CoreModule.new("Attachment", "Attachment", {})
  ADDRESS = CoreModule.new("Address","Address",{
    unique_id_field_name: :add_sys_code,
    enabled_lambda: lambda {true}
  })
end
