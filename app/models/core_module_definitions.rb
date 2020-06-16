# This contains definitions for every module in the system
# Each module must contain keys for the following options:
#
# unique_id_field_name - Used to identify the model field name to use if a message should be written about the object.  For instance, the history
# screen utilizes it as a dynamic way to determine how to identify the object who's history is being shown.
#
# key_model_field_uids - Used to identify the model field name(s) that uniquely identifies the module.
#
# quicksearch_fields - Fields to execute search over via the quicksearch functionaliy.
#          - * Only required for "top level" modules (.ie parent level ones)
#
# module_chain - An array defining the chain of parent -> child modules that define the module's data structure
#          - * Only required for top-level modules
#
# default_search_columns - Used when constructing a new advanced search, the model field uids used will constitute the columns for a new "Default" search
#          - * Only required for top-level modules
#
# children - an Array of direct child classes of the core module object you're defining that make up its core module chain
#          - * Only required if the module actually has children
#
# child_lambdas - a Hash containing keys for each class mentioned in the `children` array, and values as lambdas providing the means to access the child object ActiveRecord relations given the parent object
#          - * Only required if the module actually has children
#
# child_joins - a Hash containing keys for each class mentioned in the `children` array, the values provide SQL join clauses used to construct search queries, joining the child to the parent
#          - * Only required if the module actually has children
#

# OPTIONAL KEYS:
#
# snapshot_descriptor - By default, the snapshot consists solely of the modules defined by module_chain.  If you need anythign beyond that, you must compose a snapshot descriptor.
#
# enabled_lambda - A lambda that will be used to determine at start up if the module is accessible on the running instance.  If not supplied, module will default to being enabled.
#
# show_field_prefix - Whether to display the module class as a field prefix on searches.  Should generally only be true for child level modules/classes.
#
# changed_at_parents_lambda - Used in a few places to indicate a change to the child module should push a change to the parents.  An array, each value returned by the lambda will have it's changed_at value set.
#
# object_from_piece_set_lambda - Given a piece set object, extract the a module object from it.  Only required for classes accessible through piece sets.
#
# entity_json_lambda - Don't use
#
# business_logic_validations - A lambda that can be used to apply validations on an object that is uploaded via a worksheet through the Import Files functionality.
#
# view_path_proc - A Proc that will define the URL to use to edit the object, will always be used in a context where path helpers are available.  Defaults to using standard helpers.
#
# edit_path_proc - See view_path_proc
#
# quicksearch_lambda - Provide scoping for quicksearch, used to limit results to values the user can see.  Only required if the class does not already define a Class level search_secure(User, Class) methods.
#
# quicksearch_extra_fields - Extra field values to show in the quick search results (values here will NOT be searched by)
#
# quicksearch_sort_by_mf - The model field values will be sorted by (in descending order).  Defaults to created_at.
#
# available_addresses_lambda - A lambda that will return all addresses linked to the module.  Referenced in a html field helper - do not use.
#
# logical_key_lambda - Returns the string representation of a module object's logical key.  Defaults to using the model field defined in the key unique_id_field_name
#

module CoreModuleDefinitions

  # This is used solely as a way to provide "state" between the snapshot descriptor creations as a way to
  # not have to redefine the snapshot structure of something like Folder, that can appear
  # on every core object.
  DESCRIPTOR_REPOSITORY ||= {}

  COMMENT = CoreModule.new("Comment", "Comment", {unique_id_field_name: :cmt_unique_identifier, destroy_snapshots: false})
  GROUP = CoreModule.new("Group", "Group", {unique_id_field_name: :grp_unique_identifier, destroy_snapshots: false})
  FOLDER = CoreModule.new("Folder", "Folder", {
    logical_key_lambda: lambda { |obj|
      # We need to find the parent of the folder, and then use the logical key from it, then add in the folder name after that,
      # otherwise there's no real way to know which folder is being referenced (and this is used from comment event publishing)
      parent_key = ""
      base_obj = obj.base_object
      if base_obj
        cm = CoreModule.find_by_object base_obj

        if cm
          parent_key = "#{cm.label} #{cm.logical_key(base_obj)}"
        end
      end

      key = parent_key.blank? ? "" : "#{parent_key} / "
      key + obj.name
    },
    snapshot_descriptor: SnapshotDescriptor.for(Folder, {
        attachments: { type: Attachment },
        comments: { type: Comment },
        groups: { type: Group }
      }, descriptor_repository: DESCRIPTOR_REPOSITORY
    ),
    unique_id_field_name: :fld_unique_identifier,
    destroy_snapshots: false
  })

  SECURITY_FILING_LINE = CoreModule.new("SecurityFilingLine", "Security Line", {
       :show_field_prefix=>true,
       :unique_id_field_name=>:sfln_line_number,
       :object_from_piece_set_lambda => lambda {|ps| ps.security_filing_line},
       :enabled_lambda => lambda {MasterSetup.get.security_filing_enabled?},
       :key_model_field_uids=>[:sfln_line_number],
       :destroy_snapshots => false,
       :module_chain => [SecurityFilingLine]
   })
  SECURITY_FILING = CoreModule.new("SecurityFiling", "Security Filing", {
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
    :quicksearch_fields => [:sf_transaction_number, :sf_entry_numbers, :sf_entry_reference_numbers, :sf_po_numbers, :sf_master_bill_of_lading, :sf_container_numbers, :sf_house_bills_of_lading, :sf_host_system_file_number],
    :module_chain => [SecurityFiling, SecurityFilingLine],
    :bulk_actions_lambda => lambda {|current_user|
      bulk_actions = {}
      bulk_actions["Send to Test"]={:path=>'/security_filings/bulk_send_last_integration_file_to_test.json', font_icon:'fa fa-share-square'} if current_user.sys_admin? && !MasterSetup.get.send_test_files_to_instance.blank?
      bulk_actions
    }
  })
  ORDER_LINE = CoreModule.new("OrderLine", "Order Line", {
      :show_field_prefix=>true,
      :unique_id_field_name=>:ordln_line_number,
      :object_from_piece_set_lambda => lambda {|ps| ps.order_line},
      :enabled_lambda => lambda { MasterSetup.get.order_enabled? },
      :key_model_field_uids => [:ordln_line_number],
      :module_chain => [OrderLine],
      :destroy_snapshots => false
  })
  ORDER = CoreModule.new("Order", "Order",
    {:file_formatable=>true,
     :children => [OrderLine],
     :child_lambdas => {OrderLine => lambda {|parent| parent.order_lines}},
     :child_joins => {OrderLine => "LEFT OUTER JOIN order_lines ON orders.id = order_lines.order_id"},
     :default_search_columns => [:ord_ord_num, :ord_ord_date, :ord_ven_name, :ordln_puid, :ordln_ordered_qty],
     :unique_id_field_name => :ord_ord_num,
     :object_from_piece_set_lambda => lambda {|ps|
       o_line = ps.order_line
       o_line.nil? ? nil : o_line.order
     },
     :enabled_lambda => lambda { MasterSetup.get.order_enabled? },
     :key_model_field_uids => [:ord_ord_num],
     :quicksearch_fields => [:ord_ord_num, :ord_cust_ord_no],
     :module_chain => [Order, OrderLine],
     snapshot_descriptor: SnapshotDescriptor.for(Order, {
        order_lines: {type: OrderLine },
        folders: { descriptor: Folder }
      }, descriptor_repository: DESCRIPTOR_REPOSITORY
     ),
     :bulk_actions_lambda => lambda {|current_user|
       bulk_actions = {}
       bulk_actions["Comment"]={:path=>'/comments/bulk_count.json', :ajax_callback=>'BulkActions.handleBulkComment', font_icon:'fa fa-sticky-note'} if current_user.comment_orders?
       bulk_actions["Update"]={:path=>'/orders/bulk_update_fields.json', :ajax_callback=>'BulkActions.handleBulkOrderUpdate', font_icon:'fa fa-pencil-square-o'} if current_user.edit_orders?
       bulk_actions["Send To SAP"] = "bulk_send_to_sap_orders_path" if MasterSetup.get.custom_feature?("Bulk Send Order To SAP")
       bulk_actions["Send to Test"]={:path=>'/orders/bulk_send_last_integration_file_to_test.json', font_icon:'fa fa-share-square'} if current_user.sys_admin? && !MasterSetup.get.send_test_files_to_instance.blank?
       bulk_actions
     }
    })
  CONTAINER = CoreModule.new("Container", "Container", {
       show_field_prefix: false,
       unique_id_field_name: :con_num,
       object_from_piece_set_lambda: lambda {|ps| ps.shipment_line.nil? ? nil : ps.shipment_line.container},
       enabled_lambda: lambda {MasterSetup.get.shipment_enabled?},
       key_model_field_uids: [:con_uid],
       destroy_snapshots: false
   })
  CARTON_SET = CoreModule.new("CartonSet", "Carton Set", {
        show_field_prefix: false,
        unique_id_field_name: :cs_starting_carton,
        object_from_piece_set_lambda: lambda {|ps|
          return nil if ps.shipment_line.nil?
          ps.shipment_line.carton_set.nil? ? nil : ps.shipment_line.carton_set
        },
        enabled_lambda: lambda {MasterSetup.get.shipment_enabled?},
        key_model_field_uids: [:cs_starting_carton],
        destroy_snapshots: false
    })
  SHIPMENT_LINE = CoreModule.new("ShipmentLine", "Shipment Line", {
      :show_field_prefix=>true,
      :unique_id_field_name=>:shpln_line_number,
      :object_from_piece_set_lambda => lambda {|ps| ps.shipment_line},
      :enabled_lambda => lambda { MasterSetup.get.shipment_enabled? },
      :key_model_field_uids => [:shpln_line_number],
      :module_chain => [ShipmentLine],
      :destroy_snapshots => false
  })
  BOOKING_LINE = CoreModule.new('BookingLine', 'Booking Line',
    :show_field_prefix=>true,
    :unique_id_field_name=>:bkln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.booking_line},
    :enabled_lambda => lambda { MasterSetup.get.shipment_enabled? },
    :key_model_field_uids => [:bkln_line_number],
    :module_chain => [BookingLine],
    :destroy_snapshots => false
  )
  SHIPMENT = CoreModule.new("Shipment", "Shipment",
   {:children=>[ShipmentLine, BookingLine],
    :child_lambdas => {ShipmentLine => lambda {|p| p.shipment_lines}, BookingLine => lambda {|p| p.booking_lines}},
    :child_joins => {ShipmentLine => "LEFT OUTER JOIN shipment_lines on shipments.id = shipment_lines.shipment_id", BookingLine => "LEFT OUTER JOIN booking_lines on shipments.id = booking_lines.shipment_id"},
    :default_search_columns => [:shp_ref, :shp_mode, :shp_ven_name, :shp_car_name],
    :unique_id_field_name=>:shp_ref,
    :object_from_piece_set_lambda => lambda {|ps| ps.shipment_line.nil? ? nil : ps.shipment_line.shipment},
    :enabled_lambda => lambda { MasterSetup.get.shipment_enabled? },
    :key_model_field_uids => [:shp_ref],
    :quicksearch_fields => [:shp_ref, :shp_master_bill_of_lading, :shp_house_bill_of_lading, :shp_booking_number, :shp_importer_reference, :shp_shipped_orders, :shp_booked_orders, :shp_container_numbers],
    :module_chain => [Shipment, ModuleChain::SiblingModules.new(ShipmentLine, BookingLine)],
    :bulk_actions_lambda => lambda {|current_user|
      bulk_actions = {}
      bulk_actions["Send to Test"]={:path=>'/shipments/bulk_send_last_integration_file_to_test.json', font_icon:'fa fa-share-square'} if current_user.sys_admin? && !MasterSetup.get.send_test_files_to_instance.blank?
      bulk_actions
    },
    snapshot_descriptor: SnapshotDescriptor.for(Shipment, {
        shipment_lines: {type: ShipmentLine},
        booking_lines: {type: BookingLine},
        containers: {type: Container},
        attachments: {type: Attachment},
        comments: { type: Comment },
        folders: { descriptor: Folder }
    }, descriptor_repository: DESCRIPTOR_REPOSITORY
    )})
  SALE_LINE = CoreModule.new("SalesOrderLine", "Sale Line", {
    :show_field_prefix=>true,
    :unique_id_field_name=>:soln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.sales_order_line},
    :enabled_lambda => lambda { MasterSetup.get.sales_order_enabled? },
    :key_model_field_uids => [:soln_line_number],
    :destroy_snapshots => false,
    :module_chain => [SalesOrderLine]
    })
  SALE = CoreModule.new("SalesOrder", "Sale",
    {:children => [SalesOrderLine],
      :child_lambdas => {SalesOrderLine => lambda {|parent| parent.sales_order_lines}},
      :child_joins => {SalesOrderLine => "LEFT OUTER JOIN sales_order_lines ON sales_orders.id = sales_order_lines.sales_order_id"},
      :default_search_columns => [:sale_order_number, :sale_order_date, :sale_cust_name],
      :unique_id_field_name=>:sale_order_number,
      :object_from_piece_set_lambda => lambda {|ps| ps.sales_order_line.nil? ? nil : ps.sales_order_line.sales_order},
      :enabled_lambda => lambda { MasterSetup.get.sales_order_enabled? },
      :key_model_field_uids => [:sale_order_number],
      :quicksearch_fields => [:sale_order_number],
      :module_chain => [SalesOrder, SalesOrderLine]
    })
  DELIVERY_LINE = CoreModule.new("DeliveryLine", "Delivery Line", {
    :show_field_prefix=>true,
    :unique_id_field_name=>:delln_line_number,
    :object_from_piece_set_lambda => lambda {|ps| ps.delivery_line},
    :enabled_lambda => lambda { MasterSetup.get.delivery_enabled? },
    :key_model_field_uids => [:delln_line_number],
    :destroy_snapshots => false,
    :module_chain => [DeliveryLine]
    })
  DELIVERY = CoreModule.new("Delivery", "Delivery",
    {:children=>[DeliveryLine],
    :child_lambdas => {DeliveryLine => lambda {|p| p.delivery_lines}},
    :child_joins => {DeliveryLine => "LEFT OUTER JOIN delivery_lines on deliveries.id = delivery_lines.delivery_id"},
    :default_search_columns => [:del_ref, :del_mode, :del_car_name, :del_cust_name],
    :unique_id_field_name=>:del_ref,
    :object_from_piece_set_lambda => lambda {|ps| ps.delivery_line.nil? ? nil : ps.delivery_line.delivery},
    :enabled_lambda => lambda { MasterSetup.get.delivery_enabled? },
    :key_model_field_uids => [:del_ref],
    :module_chain => [Delivery, DeliveryLine]
   })
  PLANT_VARIANT_ASSIGNMENT = CoreModule.new("PlantVariantAssignment", "Plant Variant Assignment", {
    :show_field_prefix=>true,
    :unique_id_field_name=>:pva_assignment_id,
    :enabled_lambda=>lambda {MasterSetup.get.variant_enabled?},
    :key_model_field_uids=>[:pva_assignment_id],
    :key_attribute_field_uid=>:pva_assignment_id,
    :destroy_snapshots => false
    })
  VARIANT = CoreModule.new("Variant", "Variant", {
    :children=>[PlantVariantAssignment],
    :child_lambdas=>{PlantVariantAssignment=>lambda {|v| v.plant_variant_assignments}},
    :changed_at_parents_lambda=>lambda {|c| c.product.nil? ? [] : [c.product] },
    :enabled_lambda=>lambda {MasterSetup.get.variant_enabled?},
    :show_field_prefix=>false,
    :unique_id_field_name=>:var_identifier,
    :key_model_field_uids => [:var_identifier],
    :key_attribute_field_uid => :var_identifier,
    :destroy_snapshots => false
    })
  TARIFF = CoreModule.new("TariffRecord", "Tariff", {
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
     :key_model_field_uids => [:hts_line_number],
     :module_chain => [TariffRecord],
     :destroy_snapshots => false
  })
  CLASSIFICATION = CoreModule.new("Classification", "Classification", {
       :children => [TariffRecord],
       :child_lambdas => {TariffRecord => lambda {|p| p.tariff_records}},
       :child_joins => {TariffRecord => "LEFT OUTER JOIN tariff_records ON classifications.id = tariff_records.classification_id"},
       :changed_at_parents_lambda=>lambda {|c| c.product.nil? ? [] : [c.product] },
       :show_field_prefix=>true,
       :unique_id_field_name=>:class_cntry_iso,
       :enabled_lambda => lambda { MasterSetup.get.classification_enabled? },
       :key_model_field_uids => [:class_cntry_name, :class_cntry_iso],
       :key_attribute_field_uid => :class_cntry_id,
       :module_chain => [Classification, TariffRecord],
       :destroy_snapshots => false
   })
  PRODUCT = CoreModule.new("Product", "Product", {
       :restorable => true,
       :statusable=>true,
       :file_formatable=>true,
       :worksheetable=>true,
       :children => [Classification, Variant],
       :child_lambdas => {
          Classification => lambda {|p| p.classifications},
          Variant => lambda {|p| p.variants}
       },
       :child_joins => {
          Classification => "LEFT OUTER JOIN classifications ON products.id = classifications.product_id",
          Variant => "LEFT OUTER JOIN variants ON products.id = variants.product_id"
        },
       :default_search_columns => [:prod_uid, :prod_name, :prod_first_hts],
       :bulk_actions_lambda => lambda {|current_user|
         bulk_actions = {}
         bulk_actions["Edit"]='bulk_edit_products_path' if current_user.edit_products? || current_user.edit_classifications?
         bulk_actions["Classify"]={:path=>'/products/bulk_classify.json', :callback=>'BulkActions.submitBulkClassify', :ajax_callback=>'BulkActions.handleBulkClassify'} if current_user.edit_classifications?
         bulk_actions["Instant Classify"]='show_bulk_instant_classify_products_path' if current_user.edit_classifications? && !InstantClassification.all.empty?
         bulk_actions["Send to Test"]={:path=>'/products/bulk_send_last_integration_file_to_test.json', font_icon:'fa fa-share-square'} if current_user.sys_admin? && !MasterSetup.get.send_test_files_to_instance.blank?
         bulk_actions
       },
       :changed_at_parents_lambda=>lambda {|p| [p]}, # only update self
       :business_logic_validations=>lambda {|p|
         c = p.errors[:base].size
         p.validate_tariff_numbers
         c==p.errors[:base].size
       },
       :unique_id_field_name=>:prod_uid,
       :key_model_field_uids => [:prod_uid],
       :quicksearch_fields => [:prod_uid, :prod_name],
       :quicksearch_extra_fields => [lambda do
          # This is here SOLELY for the case where we're running the migration to actually create
          # the show_quicksearch field (since this code is referenced from an initializer and will load
          # when migrations run)
          if Country.new.respond_to?(:quicksearch_show?)
            Country.select("id").show_quicksearch.order(:classification_rank, :name).map { |c| "*fhts_1_#{c.id}".to_sym }
          else
            []
          end
       end],
       :module_chain => [Product, Classification, TariffRecord],
       :snapshot_descriptor => SnapshotDescriptor.for(Product,
          classifications: {type: Classification, children: {
            tariff_records: {type: TariffRecord}
          }},
          product_rate_overrides: {type: ProductRateOverride},
          variants: {type: Variant},
          attachments: {type: Attachment}
       )
   })
  BROKER_INVOICE_LINE = CoreModule.new("BrokerInvoiceLine", "Broker Invoice Line", {
       :changed_at_parents_lambda => lambda {|p| p.broker_invoice.nil? ? [] : [p.broker_invoice]},
       :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
       :unique_id_field_name=>:bi_line_charge_code,
       :key_model_field_uids=>[:bi_line_charge_code],
       :show_field_prefix=>true,
       :destroy_snapshots => false
   })
  BROKER_INVOICE = CoreModule.new("BrokerInvoice", "Broker Invoice", {
      :default_search_columns => [:bi_brok_ref, :bi_suffix, :bi_invoice_date, :bi_invoice_total],
      :unique_id_field_name => :bi_suffix,
      :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
      :key_model_field_uids=>[:bi_brok_ref, :bi_suffix],
      :children => [BrokerInvoiceLine],
      :child_lambdas => {BrokerInvoiceLine => lambda {|i| i.broker_invoice_lines}},
      :child_joins => {BrokerInvoiceLine => "LEFT OUTER JOIN broker_invoice_lines on broker_invoices.id = broker_invoice_lines.broker_invoice_id"},
      :quicksearch_fields => [:bi_invoice_number, {model_field_uid: :bi_brok_ref, joins: [:entry]}],
      :module_chain => [BrokerInvoice, BrokerInvoiceLine],
      :bulk_actions_lambda => lambda {|current_user|
        bulk_actions = {}
        bulk_actions["Send to Test"]={:path=>'/broker_invoices/bulk_send_last_integration_file_to_test.json', font_icon:'fa fa-share-square'} if current_user.sys_admin? && !MasterSetup.get.send_test_files_to_instance.blank?
        bulk_actions
      },
      :destroy_snapshots => false
  })
  COMMERCIAL_INVOICE_LACEY = CoreModule.new("CommercialInvoiceLaceyComponent", "Lacey Component", {
       :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
       :show_field_prefix => true,
       :unique_id_field_name=>:lcy_line_number,
       :key_model_field_uids=>[:lcy_line_number],
       :destroy_snapshots => false
   })
  COMMERCIAL_INVOICE_TARIFF = CoreModule.new("CommercialInvoiceTariff", "Invoice Tariff", {
       :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
       :show_field_prefix => true,
       :unique_id_field_name=>:cit_hts_code,
       :key_model_field_uids=>[:cit_hts_code],
       :module_chain => [CommercialInvoiceTariff],
       :destroy_snapshots => false
   })
  COMMERCIAL_INVOICE_LINE = CoreModule.new("CommercialInvoiceLine", "Invoice Line", {
     :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
     :show_field_prefix=>true,
     :unique_id_field_name=>:cil_line_number,
     :key_model_field_uids=>[:cil_line_number],
     :children => [CommercialInvoiceTariff],
     :child_lambdas => {CommercialInvoiceTariff=>lambda {|i| i.commercial_invoice_tariffs}},
     :child_joins => {CommercialInvoiceTariff=> "LEFT OUTER JOIN commercial_invoice_tariffs on commercial_invoice_lines.id = commercial_invoice_tariffs.commercial_invoice_line_id"},
     :module_chain => [CommercialInvoiceLine, CommercialInvoiceTariff],
     :destroy_snapshots => false
  })
  COMMERCIAL_INVOICE = CoreModule.new("CommercialInvoice", "Invoice", {
      :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
      :unique_id_field_name => :ci_invoice_number,
      :show_field_prefix=>true,
      :key_model_field_uids=>[:ci_invoice_number],
      :children => [CommercialInvoiceLine],
      :child_lambdas => {CommercialInvoiceLine=> lambda {|i| i.commercial_invoice_lines}},
      :child_joins => {CommercialInvoiceLine => "LEFT OUTER JOIN commercial_invoice_lines on commercial_invoices.id = commercial_invoice_lines.commercial_invoice_id"},
      :module_chain => [CommercialInvoice, CommercialInvoiceLine, CommercialInvoiceTariff]
  })
  ENTRY = CoreModule.new("Entry", "Entry", {
       :enabled_lambda => lambda {MasterSetup.get.entry_enabled?},
       :default_search_columns => [:ent_brok_ref, :ent_entry_num, :ent_release_date],
       :unique_id_field_name=>:ent_brok_ref,
       :key_model_field_uids=>[:ent_brok_ref],
       :bulk_actions_lambda => lambda {|current_user|
         bulk_actions = {}
         bulk_actions["Update Images"] = "bulk_get_images_entries_path" if current_user.company.master? && current_user.view_entries?
         bulk_actions["Update Entries"] = "bulk_request_entry_data_entries_path" if current_user.sys_admin?
         bulk_actions["Send to Test"]={:path=>'/entries/bulk_send_last_integration_file_to_test.json', font_icon:'fa fa-share-square'} if current_user.sys_admin? && !MasterSetup.get.send_test_files_to_instance.blank?
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
          EntryComment => lambda {|ent| ent.entry_comments },
          EntryException => lambda {|ent| ent.entry_exceptions }
       },
       :child_joins => {CommercialInvoice => "LEFT OUTER JOIN commercial_invoices on entries.id = commercial_invoices.entry_id"},
       :quicksearch_fields => [:ent_brok_ref, :ent_entry_num, :ent_po_numbers, :ent_customer_references, :ent_mbols, :ent_container_nums, :ent_cargo_control_number, :ent_hbols, :ent_commercial_invoice_numbers],
       :quicksearch_extra_fields => [:ent_cust_num, :ent_release_cert_message, :ent_fda_message, :ent_filed_date, :ent_first_release_received_date, :ent_release_date],
       :quicksearch_sort_by_mf => :ent_file_logged_date,
       :logical_key_lambda => lambda {|obj| "#{obj.source_system}_#{obj.broker_reference}"},
       :module_chain => [Entry, CommercialInvoice, CommercialInvoiceLine, CommercialInvoiceTariff],
       :snapshot_descriptor => SnapshotDescriptor.for(Entry, {
          entry_comments: {type: EntryComment},
          commercial_invoices: {type: CommercialInvoice, children: {
            commercial_invoice_lines: {type: CommercialInvoiceLine, children: {
                commercial_invoice_tariffs: {type: CommercialInvoiceTariff, children: {
                    commercial_invoice_lacey_components: {type: CommercialInvoiceLaceyComponent},
                    pga_summaries: {type: PgaSummary}
                }}
              }}
          }},
          containers: {type: Container},
          entry_exceptions: {type: EntryException},
          broker_invoices: {type: BrokerInvoice, children: {
            broker_invoice_lines: {type: BrokerInvoiceLine}
          }},
          attachments: {type: Attachment}
        }, descriptor_repository: DESCRIPTOR_REPOSITORY
       )
   })

  # ENTRY_COMMENT core module is present solely for use in snapshotting, it is not meant to be used
  # as a module.  The only thing set up for it is model fields.
  # Entry Comment has no field that is really suitable for use in key_model_field_uids or in unique_id_field,
  # as such comments won't work with snapshot diffs at the moment - diffs aren't accessible from entries so
  # that's not a big deal.
  ENTRY_COMMENT = CoreModule.new("EntryComment", "Entry Note", {:destroy_snapshots => false})

  OFFICIAL_TARIFF = CoreModule.new("OfficialTariff", "HTS Regulation", {
       :default_search_columns=>[:ot_hts_code, :ot_cntry_iso, :ot_full_desc, :ot_common_rate],
       :quicksearch_fields=> [:ot_hts_code, :ot_full_desc],
       :quicksearch_extra_fields => [:ot_cntry_name],
       :destroy_snapshots => false
   })
  PLANT_PRODUCT_GROUP_ASSIGNMENT = CoreModule.new('PlantProductGroupAssignment', 'Plant Product Group Assignment',
    unique_id_field_name: :ppga_pg_name,
    default_search_columns:[:ppga_pg_name],
    key_model_field_uids: [:ppga_pg_name],
    show_field_prefix: true,
    destroy_snapshots: false,
    module_chain: [PlantProductGroupAssignment]
    )

  PLANT = CoreModule.new("Plant", "Plant",
    default_search_columns: [:plant_name],
    unique_id_field_name: :plant_name,
    show_field_prefix: true,
    key_model_field_uids: [:plant_name],
    children: [PlantProductGroupAssignment],
    child_lambdas: {PlantProductGroupAssignment => lambda {|p| p.plant_product_group_assignments}},
    child_joins: {PlantProductGroupAssignment => "LEFT OUTER JOIN plant_product_group_assignments ON plants.id = plant_product_group_assignments.plant_id"},
    available_addresses_lambda: lambda {|plant| plant.company ? plant.company.addresses.order(:name, :city, :line_1) : [] },
    module_chain: [Plant, PlantProductGroupAssignment]
  )

  # NOTE: Since we're setting up VENDOR as a full-blown core module based search, it means other variants of Company itself cannot have one, unless further changes are made
  # to the searching classes in quicksearch_controller, api_core_module_base, application_controller, search_query, search_query_controller_helper (possibly others).
  COMPANY = CoreModule.new("Company", "Vendor",
    default_search_columns: [:cmp_name, :cmp_sys_code],
    unique_id_field_name: :cmp_sys_code,
    key_model_field_uids: [:cmp_sys_code],
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
    quicksearch_fields: [:cmp_name, :cmp_sys_code],
    available_addresses_lambda: lambda {|company| company.addresses.order(:name, :city, :line_1) },
    module_chain: [Company, Plant, PlantProductGroupAssignment],
    snapshot_descriptor: SnapshotDescriptor.for(Company, {
        plants: {
          type:Plant,
          children: {
            plant_product_group_assignments:{
              type: PlantProductGroupAssignment
            }
          }
        },
        addresses: {type:Address}
      }, descriptor_repository: DESCRIPTOR_REPOSITORY
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

  VFI_INVOICE_LINE = CoreModule.new("VfiInvoiceLine", "Vfi Invoice Line", {
    :changed_at_parents_lambda => lambda {|p| p.vfi_invoice.nil? ? [] : [p.vfi_invoice]},
    :enabled_lambda => lambda { CoreModule::VFI_INVOICE.enabled? },
    :unique_id_field_name=>:vi_line_number,
    :key_model_field_uids=>[:vi_line_number],
    :show_field_prefix=>true,
    :destroy_snapshots => false,
    :module_chain => [VfiInvoiceLine]
   })

  PRODUCT_VENDOR_ASSIGNMENT = CoreModule.new("ProductVendorAssignment", "Product Vendor Assignment", {
    default_search_columns: [:prodven_ven_name, :prodven_puid, :prodven_pname],
    key_model_field_uids: [:prodven_ven_name, :prodven_puid]
  })

  # ATTACHMENT core module is present solely for use in snapshotting, it is not meant to be used
  # as a module.  The only thing set up for it is model fields.
  # Attachment has no field that is really suitable for use in key_model_field_uids or in unique_id_field,
  # as such attachments won't work with snapshot diffs at the moment - diffs aren't accessible from entries so
  # that's not a big deal.
  ATTACHMENT = CoreModule.new("Attachment", "Attachment", {unique_id_field_name: :att_unique_identifier, destroy_snapshots: false})
  ADDRESS = CoreModule.new("Address", "Address", {
    unique_id_field_name: :add_sys_code,
    enabled_lambda: lambda {true},
    destroy_snapshots: false
  })
  TRADE_LANE = CoreModule.new("TradeLane", "Trade Lane", {
    enabled_lambda: lambda { MasterSetup.get.trade_lane_enabled? }
  })

  TRADE_PREFERENCE_PROGRAM = CoreModule.new("TradePreferenceProgram", "Trade Preference Program", {
    enabled_lambda: lambda { MasterSetup.get.trade_lane_enabled? }
  })
  TPP_HTS_OVERRIDE = CoreModule.new("TppHtsOverride", "Trade Preference HTS Override", {
    enabled_lambda: lambda { MasterSetup.get.trade_lane_enabled? }
  })
  PRODUCT_RATE_OVERRIDE = CoreModule.new("ProductRateOverride", "Product Rate Override", {
    enabled_lambda: lambda { CoreModule::CLASSIFICATION.enabled? },
    unique_id_field_name: :pro_key,
    changed_at_parents_lambda: lambda {|c| c.product.nil? ? [] : [c.product] },
    show_field_prefix: true
  })

  CUSTOMS_DAILY_STATEMENT_ENTRY_FEE = CoreModule.new("DailyStatementEntryFee", "Statement Fee", {
    enabled_lambda: lambda { MasterSetup.get.customs_statements_enabled? },
    show_field_prefix: true,
    unique_id_field_name: :dsef_code,
    key_model_field_uids: [:dsef_code],
    destroy_snapshots: false,
    module_chain: [DailyStatementEntryFee]
  })

  CUSTOMS_DAILY_STATEMENT_ENTRY = CoreModule.new("DailyStatementEntry", "Statement Entry", {
    enabled_lambda: lambda { MasterSetup.get.customs_statements_enabled? },
    show_field_prefix: true,
    unique_id_field_name: :dse_broker_reference,
    key_model_field_uids: [:dse_broker_reference],
    children: [DailyStatementEntryFee],
    child_lambdas: {DailyStatementEntryFee => lambda {|s| s.daily_statement_entry_fees }},
    child_joins: {DailyStatementEntryFee => "LEFT OUTER JOIN daily_statement_entry_fees on daily_statement_entries.id = daily_statement_entry_fees.daily_statement_entry_id"},
    destroy_snapshots: false,
    module_chain: [DailyStatementEntry, DailyStatementEntryFee]
  })

  CUSTOMS_DAILY_STATEMENT = CoreModule.new("DailyStatement", "Daily Statement", {
    default_search_columns: [:cds_statement_number, :cds_status, :cds_received_date, :cds_port_code, :cds_paid_date],
    unique_id_field_name: :cds_statement_number,
    key_model_field_uids: [:cds_statement_number],
    children: [DailyStatementEntry],
    child_lambdas: {DailyStatementEntry => lambda {|s| s.daily_statement_entries }},
    child_joins: {DailyStatementEntry => "LEFT OUTER JOIN daily_statement_entries on daily_statements.id = daily_statement_entries.daily_statement_id"},
    enabled_lambda: lambda { MasterSetup.get.customs_statements_enabled? },
    module_chain: [DailyStatement, DailyStatementEntry, DailyStatementEntryFee],
    quicksearch_fields: [:cds_statement_number],
    quicksearch_extra_fields: [:cds_status, :cds_total_amount, :cds_received_date, :cds_final_received_date]
  })

  CUSTOMS_MONTHLY_STATEMENT = CoreModule.new("MonthlyStatement", "Monthly Statement", {
    default_search_columns: [:cms_statement_number, :cms_status, :cms_received_date, :cms_port_code, :cms_paid_date],
    unique_id_field_name: :cms_statement_number,
    key_model_field_uids: [:cms_statement_number],
    children: [],
    child_lambdas: {},
    child_joins: {},
    enabled_lambda: lambda { MasterSetup.get.customs_statements_enabled? },
    module_chain: [MonthlyStatement],
    quicksearch_fields: [:cms_statement_number],
    quicksearch_extra_fields: [:cms_status, :cms_total_amount, :cms_received_date, :cms_final_received_date]
  })

  RUN_AS_SESSION = CoreModule.new("RunAsSession", "Run As Session",
    unique_id_field_name: :ras_start_time,
    key_model_field_uids: [:ras_start_time],
    children: [],
    child_lambdas: {},
    child_joins: {},
    default_search_columns: [:ras_admin_username, :ras_run_as_username, :ras_start_time, :ras_end_time],
    destroy_snapshots: false
  )

  USER = CoreModule.new("User", "User",
    unique_id_field_name: :usr_username,
    key_model_field_uids: [:usr_username],
    children: [Group, EventSubscription],
    child_lambdas: {Group => lambda {|u| u.groups}, EventSubscription => lambda { |u| u.event_subscriptions}},
    child_joins: {Group => "LEFT OUTER JOIN user_group_memberships ON users.id = user_group_memberships.user_id
                            LEFT OUTER JOIN groups ON user_group_memberships.group_id = groups.id",
                  EventSubscription => "LEFT OUTER JOIN event_subscriptions ON user.id = users.id"},
  snapshot_descriptor: SnapshotDescriptor.for(User, {
      groups: { type: Group },
      event_subscriptions: { type: EventSubscription}
  })
  )

  EVENT_SUBSCRIPTION = CoreModule.new("EventSubscription", "Event Subscriptions",
    unique_id_field_name: :evnts_event_type,
    key_model_field_uids: [:evnts_event_type],
    destroy_snapshots: false
  )

  INVOICE = CoreModule.new("Invoice", "Customer Invoices",
    unique_id_field_name: :inv_inv_num,
    key_model_field_uids: [:inv_inv_num],
    children: [InvoiceLine],
    child_lambdas: {InvoiceLine => lambda {|parent| parent.invoice_lines}},
    child_joins: {InvoiceLine => "LEFT OUTER JOIN invoice_lines ON invoices.id = invoice_lines.invoice_id"},
    quicksearch_fields: [:inv_inv_num, :inv_po_numbers, :inv_part_numbers, :inv_cust_ref_num],
    module_chain: [Invoice, InvoiceLine],
    enabled_lambda: lambda { MasterSetup.get.invoices_enabled? },
    default_search_columns: [
        :inv_inv_num,
        :inv_inv_date,
        :inv_cust_ref_num,
        :inv_inv_tot_foreign,
        :inv_inv_tot_domestic,
        :inv_total_discounts,
        :inv_total_charges
    ]
  )

  INVOICE_LINE = CoreModule.new("InvoiceLine", "Invoice Line",
    unique_id_field_name: :invln_ln_number,
    key_model_field_uids: [:invln_ln_number],
    show_field_prefix: true,
    destroy_snapshots: false,
    module_chain: [InvoiceLine]
  )

  ENTRY_EXCEPTION = CoreModule.new("EntryException", "Exceptions", {
      destroy_snapshots: false
  })

  PGA_SUMMARY = CoreModule.new("PgaSummary", "PGA Summaries", {
      destroy_snapshots: false
  })

  # Don't need these any longer, clear them...this should be the last line in the file
  DESCRIPTOR_REPOSITORY.clear
end
