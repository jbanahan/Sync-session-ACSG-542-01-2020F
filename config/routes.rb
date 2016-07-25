OpenChain::Application.routes.draw do
  match '/hts/subscribed_countries' => 'hts#subscribed_countries', :via=>:get
  match '/hts/:iso/heading/:heading' => 'hts#heading', :via=>:get
  match '/hts/:iso/chapter/:chapter' => 'hts#chapter', :via=>:get
  match '/hts/:iso' => 'hts#country', :via=>:get
  match '/hts' => 'hts#index', :via=>:get

  match "auth/:provider/callback" => "user_sessions#create_from_omniauth"
  match 'auth/failure' => redirect("/login")

  namespace :api do
    namespace :v1 do
      match '/comments/for_module/:module_type/:id' => 'comments#for_module', via: :get
      match '/messages/count/:user_id' => 'messages#count'
      resources :messages, only: [:index, :create] do
        post :mark_as_read, on: :member
      end
      resources :comments, only: [:create,:destroy]
      resources :commercial_invoices, only: [:index,:create,:update]
      resources :shipments, only: [:index,:show,:create,:update] do
        member do
          post :process_tradecard_pack_manifest
          post :process_booking_worksheet
          post :process_manifest_worksheet
          post :request_booking
          post :approve_booking
          post :confirm_booking
          post :revise_booking
          post :request_cancel
          post :cancel
          post :uncancel
          post :send_isf
          get :available_orders
          get :booked_orders
          get :available_lines
          get :autocomplete_order
          get :autocomplete_product
          get :autocomplete_address
          post :create_address
          get :shipment_lines
          get :booking_lines
        end
      end
      resources :fields, only: [:index]
      resources :companies, only: [:index] do
        get :state_toggle_buttons, on: :member
        post :toggle_state_button, on: :member
        post :validate, on: :member
      end

      resources :drawback_claims, only: [] do
        post :validate, on: :member
      end

      resources :entries, only: [] do
        post :validate, on: :member
      end

      resources :orders, only: [:index,:show,:update] do
        member do
          get :state_toggle_buttons
          post :toggle_state_button
          post :accept
          post :unaccept
          get :by_order_number
          post :validate
        end
        collection do
          get :by_order_number
        end
      end
      resources :order_lines, only: [] do
        get :state_toggle_buttons, on: :member
        post :toggle_state_button, on: :member
      end

      resources :users, only: [] do
        resources :event_subscriptions, only: [:index,:create]
        collection do
          post :login
          post :google_oauth2
          get :me
          post 'me/toggle_email_new_messages' => 'users#toggle_email_new_messages'
          post :change_my_password
        end

      end

      resources :official_tariffs, only: [] do
        get 'find/:iso/:hts' => 'official_tariffs#find', on: :collection, constraints: {hts: /[\d\.]+/}
      end
      resources :products, only: [:index, :show, :create, :update] do
        # The optional param is for temporary backwards compatibility on the API
        get 'by_uid(/:path_uid)' => "products#by_uid", on: :collection
        get :state_toggle_buttons, on: :member
        post :toggle_state_button, on: :member
        post :validate, on: :member
      end
      resources :variants, only: [:show]
      resources :product_rate_overrides, only: [:index, :show, :update, :create]

      resources :plants, only: [] do
        get :state_toggle_buttons, on: :member
        post :toggle_state_button, on: :member
      end

      resources :plant_product_group_assignments, only: [] do
        get :state_toggle_buttons, on: :member
        post :toggle_state_button, on: :member
      end

      resources :product_vendor_assignments, only: [:index] do
        put :bulk_update, on: :collection
        post :bulk_create, on: :collection
      end

      resources :model_fields, only: [:index] do
        get :cache_key, on: :collection
      end

      resources :survey_responses, only: [:index, :show] do
        member do
          post :checkout
          post :cancel_checkout
          post :checkin
          post :submit
        end
      end

      resources :vendors, only: [] do
        post :validate, on: :member
      end

      resources :user_manuals, only: [:index]

      resources :trade_lanes, except: [:destroy]
      resources :trade_preference_programs, except: [:destroy]
      resources :tpp_hts_overrides, except: [:destroy]

      match "/setup_data" => "setup_data#index", via: :get

      match "/ports/autocomplete" => "ports#autocomplete", :via => :get
      match "/divisions/autocomplete" => "divisions#autocomplete", via: :get

      match "/intacct_data/receive_alliance_invoice_details" => "intacct_data#receive_alliance_invoice_details", :via => :post
      match "/intacct_data/receive_check_result" => "intacct_data#receive_check_result", :via => :post
      match "/alliance_data/receive_alliance_entry_details" => "alliance_data#receive_alliance_entry_details", :via => :post
      match "/alliance_data/receive_alliance_entry_tracking_details" => "alliance_data#receive_alliance_entry_tracking_details", :via => :post
      match "/alliance_data/receive_updated_entry_numbers" => "alliance_data#receive_updated_entry_numbers", :via => :post
      match "/alliance_data/receive_entry_data" => "alliance_data#receive_entry_data", :via => :post
      match "/alliance_reports/receive_alliance_report_data" => "alliance_reports#receive_alliance_report_data", :via => :post

      match "/schedulable_jobs/run_jobs" => "schedulable_jobs#run_jobs", via: :post

      match "/workflow/:id/set_multi_state" => "workflow#set_multi_state", via: :put
      match "/workflow/:id/assign" => "workflow#assign", via: :put
      match "/workflow/:core_module/:id/my_instance_open_task_count" => "workflow#my_instance_open_task_count", via: :get


      match "/:attachable_type/:attachable_id/attachments/:id" => "attachments#show", via: [:get], as: :attachable_attachment
      match "/:attachable_type/:attachable_id/attachments" => "attachments#index", via: [:get], as: :attachable_attachments
      match "/:attachable_type/:attachable_id/attachments" => "attachments#create", via: [:post]
      match "/:attachable_type/:attachable_id/attachments/:id/download" => "attachments#download", via: [:get], as: :download_attachable_attachment
      match "/:attachable_type/:attachable_id/attachments/:id" => "attachments#destroy", via: [:delete]

      match "/feedback/send_feedback" => 'feedback#send_feedback', via: :post

      namespace :admin do
        match 'event_subscriptions/:event_type/:subscription_type/:object_id' => "event_subscriptions#show_by_event_type_object_id_and_subscription_type", via: :get
        match 'search_setups/:id/create_template' => 'search_setups#create_template', via: :post
        resources :users, only: [] do
          member do
            post :add_templates
            post :change_user_password
          end
        end
        resources :milestone_notification_configs, only: [:index, :show, :new, :create, :update, :destroy] do
          get :copy, on: :member
          get :model_fields, on: :collection
        end
      end

      resources :fenix_postbacks, only: [] do
        collection do
          post :receive_lvs_results
        end
      end

      resources :addresses, only: [:index]

      resources :countries, only: [:index]

      resources :support_requests, only: [:create]

      resources :search_criterions, only: [:index, :create, :update, :destroy]
    end
  end

  namespace :customer do
    match '/lumber_liquidators/sap_vendor_setup_form/:vendor_id' => 'lumber_liquidators#sap_vendor_setup_form', via: :get
  end
  resources :delayed_jobs, :only => [:destroy] do
    member do
      delete :bulk_destroy
    end
  end
  resources :ftp_sessions, :only => [:index, :show] do
    member do
      get 'download'
    end
  end

  resources :sent_emails, :only => [:index, :show] do
    member do
      get "body"
    end
  end

  match '/my_tasks' => 'workflow#my_tasks', :via => :get
  match '/my_tasks/by_page_panel' => 'workflow#my_tasks_by_page_panel', :via => :get
  match '/my_tasks/by_due_panel' => 'workflow#my_tasks_by_due_panel', :via => :get
  match '/workflow/:core_module/:id' => 'workflow#show', :via => :get
  match '/entries/activity_summary/us' => 'entries#us_activity_summary', :via => :get
  match '/entries/importer/:importer_id/activity_summary/us' => 'entries#us_activity_summary', :via => :get
  match '/entries/importer/:importer_id/activity_summary/us/content' => 'entries#us_activity_summary_content', :via => :get
  match '/entries/importer/:importer_id/activity_summary/us/duty_detail' => 'entries#us_duty_detail', :via => :get

  match '/entries/activity_summary/ca' => 'entries#ca_activity_summary', :via => :get
  match '/entries/importer/:importer_id/activity_summary/ca' => 'entries#ca_activity_summary', :via => :get
  match '/entries/importer/:importer_id/activity_summary/ca/content' => 'entries#ca_activity_summary_content', :via => :get

  match '/entries/importer/:importer_id/entry_port/:port_code' => 'entries#by_entry_port', :via => :get
  match '/entries/importer/:importer_id/country/:iso_code/release_range/:release_range' => 'entries#by_release_range', :via=>:get
  match "/entries/bi" => "entries#bi_three_month", :via=>:get
  match "/entries/bi/three_month" => "entries#bi_three_month", :via=>:get
  match "/entries/bi/three_month_hts" => "entries#bi_three_month_hts", :via=>:get
  resources :entries, :only => [:index,:show] do
    member do
      get 'validation_results'
      get 'sync_records'

      post 'request_entry_data'
      post 'get_images'
      post 'purge'
      post 'generate_delivery_order'
    end

    collection do
      get 'reprocess'

      post 'bulk_get_images'
      post 'bulk_request_entry_data'
    end

    resources :broker_invoices, :only=>[:create]
  end

  resources :business_validation_templates do
    resources :t_search_criterions, only: [:new, :create, :destroy]
    resources :business_validation_rules, only: [:create, :destroy, :edit, :update] do
      resources :r_search_criterions, only: [:new, :create, :destroy]
    end
  end

  match '/business_validation_templates/:id/manage_criteria' => 'business_validation_templates#manage_criteria', via: :get
  match '/business_validation_templates/:id/edit_angular' => 'business_validation_templates#edit_angular', via: :get
  match '/business_validation_rules/:id/edit_angular' => 'business_validation_rules#edit_angular', via: :get

  resources :business_validation_rule_results, only: [:update] do
    put 'cancel_override', :on=>:member
  end

  resources :commercial_invoices, :only => [:show]
  resources :broker_invoices, :only => [:index,:show]
  resources :part_number_correlations, only: [:index, :show, :create]
  resources :commercial_invoice_maps, :only=>[:index] do
    post 'update_all', :on=>:collection
  end

  resources :support_tickets

  resources :linkable_attachment_import_rules
  resources :tariff_sets, :only => [:index] do
    member do
      get 'activate'
    end
    collection do
      post 'load'
    end
  end
  resources :entity_snapshots, :only => [:show] do
    post 'restore', :on=>:member
  end
  resources :instant_classifications do
    collection do
      post 'update_rank'
    end
  end
  resources :instant_classification_results, :only => [:show,:index]
  resources :milestone_plans do
    resources :milestone_definitions, :only => [:index]
  end
  resources :milestone_forecast_sets do
    member do
      post 'replan'
      post 'change_plan'
    end
    collection do
      get 'show_by_order_line_id'
    end
  end
  resources :entity_types
  resources :field_validator_rules do
    get 'validate', :on=>:collection
  end
  resources :field_labels, :only=>[:index] do
    post 'save', :on=>:collection
  end
  resources :password_resets, :only => [:edit, :create, :update]
  resources :dashboard_widgets, :only => [:index] do
    collection do
      get 'edit'
      post 'save'
    end
  end
  resources :master_setups do
    collection do
      get 'perf' #MasterSetup.get performance test
      get 'show_system_message'
      post 'set_system_message'
      post 'upgrade'
    end
  end
  resources :upgrade_logs, :only=>[:show]
  resources :attachment_types

  match "/official_tariffs/auto_classify/:hts" => "official_tariffs#auto_classify"
  resources :official_tariffs, :only=>[:index,:show] do
    collection do
    get 'find'
    get 'find_schedule_b'
    get 'schedule_b_matches'
    get 'auto_complete'
    end
  end
  resources :official_tariff_meta_data, :only=>[:create,:update]

  resources :status_rules
  resources :attachments do
    member do
      get 'download'
    end

    collection do
      get 'download_last_integration_file'
    end
  end
  resources :comments do
    post 'send_email', :on => :member
    post 'bulk_count', :on => :collection
    post 'bulk', :on => :collection
  end

  match "/textile/preview" => "textile#preview"
  match "/tracker" => "public_shipments#index"
	match "/index.html" => "home#index"
  match "/shipments/:id/add_sets" => "shipments#add_sets"
  match "/shipments/:id/receive_inventory" => "shipments#receive_inventory"
  match "/shipments/:id/undo_receive" => "shipments#undo_receive"
  match "/deliveries/:id/add_sets" => "deliveries#add_sets"
  match "/login" => "user_sessions#new", :as => :login
  match "/logout" => "user_sessions#destroy", :as => :logout
  match "/register" => "registrations#send_email", :via => :post
  match "/my_subscriptions" => "users#event_subscriptions"
  match "/settings" => "settings#index", :as => :settings
  match "/tools" => "settings#tools", :as => :tools
  match "/adjust_inventory" => "products#adjust_inventory"
  match "/feedback" => "feedback#send_feedback"
  match "/model_fields/find_by_module_type" => "model_fields#find_by_module_type"
  match "/help" => "chain_help#index"
  match '/users/find_by_email' => "users#find_by_email", :via => :get
  match '/users/move_to_new_company/:destination_company_id' => "users#move_to_new_company", :via => :post
  match "/accept_tos" => "users#accept_tos"
  match "/show_tos" => "users#show_tos"
  match "/public_fields" => "public_fields#index"
  match "/public_fields/save" => "public_fields#save", :via => :post
  match "/users/email_new_message" => "users#email_new_message"
  match "/users/task_email" => "users#task_email"
  match "/hide_message/:message_name" => 'users#hide_message', :via => :post
  match "/quick_search" => "quick_search#show"
  match '/quick_search/by_module/:module_type' => 'quick_search#by_module', via: :get
  match "/enable_run_as" => "users#enable_run_as"
  match "/disable_run_as" => "users#disable_run_as"
  match "/users/set_homepage" => "users#set_homepage", :via => :post
  match "/me" => "users#me", via: :get
  match "/logo.png" => "logo#logo", via: :get

  match "email_attachments/:id" => "email_attachments#show", :as => :email_attachments_show, :via => :get
  match "email_attachments/:id/download" => "email_attachments#download", :as => :email_attachments_download, :via => :post

  match "/attachments/email_attachable/:attachable_type/:attachable_id" => "attachments#show_email_attachable", via: :get
  match "/attachments/email_attachable/:attachable_type/:attachable_id" => "attachments#send_email_attachable", via: :post

  match "/project_deliverables/:user_id/notify_now" => "project_deliverables#notify_now", via: :get
  match "/glossary/:core_module" => "model_fields#glossary", via: :get

  resources :advanced_search, :only => [:show,:index,:update,:create,:destroy] do
    get 'last_search_id', :on=>:collection
    get 'setup', :on=>:member
    get 'download', :on=>:member
    post 'send_email', :on=>:member
    get 'total_objects', :on=>:member
  end

  #custom features
  match "/custom_features" => "custom_features#index", :via => :get
  match "/custom_features/ua_winshuttle_b" => "custom_features#ua_winshuttle_b_index", :via=>:get
  match "/custom_features/ua_winshuttle_b" => "custom_features#ua_winshuttle_b_send", :via=>:post
  match "/custom_features/ua_winshuttle" => "custom_features#ua_winshuttle_index", :via=>:get
  match "/custom_features/ua_winshuttle" => "custom_features#ua_winshuttle_send", :via=>:post
  match "/custom_features/csm_sync" => "custom_features#csm_sync_index", :via=>:get
  match "/custom_features/csm_sync/upload" => "custom_features#csm_sync_upload", :via => :post
  match "/custom_features/csm_sync/:id/download" => "custom_features#csm_sync_download", :via => :get
  match "/custom_features/csm_sync/:id/reprocess" => "custom_features#csm_sync_reprocess", :via=>:get
  match "/custom_features/kewill_isf" => "custom_features#kewill_isf_index", via: :get
  match "/custom_features/kewill_isf/upload" => "custom_features#kewill_isf_upload", via: :post
  match "/custom_features/polo_sap_bom" => "custom_features#polo_sap_bom_index", :via=>:get
  match "/custom_features/polo_sap_bom/upload" => "custom_features#polo_sap_bom_upload", :via=>:post
  match "/custom_features/polo_sap_bom/:id/download" => "custom_features#polo_sap_bom_download", :via=>:get
  match "/custom_features/polo_sap_bom/:id/reprocess" => "custom_features#polo_sap_bom_reprocess", :via=>:get
  match "/custom_features/jcrew_parts" => "custom_features#jcrew_parts_index", :via=>:get
  match "/custom_features/jcrew_parts/upload" => "custom_features#jcrew_parts_upload", :via => :post
  match "/custom_features/jcrew_parts/:id/download" => "custom_features#jcrew_parts_download", :via => :get
  match "/custom_features/polo_ca_invoices" => "custom_features#polo_ca_invoices_index", :via=>:get
  match "/custom_features/polo_ca_invoices/upload" => "custom_features#polo_ca_invoices_upload", :via => :post
  match "/custom_features/polo_ca_invoices/:id/download" => "custom_features#polo_ca_invoices_download", :via => :get
  match "/custom_features/ua_tbd" => "custom_features#ua_tbd_report_index", :via=>:get
  match "/custom_features/ua_tbd/upload" => "custom_features#ua_tbd_report_upload", :via => :post
  match "/custom_features/ua_tbd/:id/download" => "custom_features#ua_tbd_report_download", :via => :get
  match "/custom_features/ua_style_color_region" => "custom_features#ua_style_color_region_index", :via=>:get
  match "/custom_features/ua_style_color_region/upload" => "custom_features#ua_style_color_region_upload", :via => :post
  match "/custom_features/ua_style_color_region/:id/download" => "custom_features#ua_style_color_region_download", :via => :get
  match "/custom_features/ua_style_color_factory" => "custom_features#ua_style_color_factory_index", :via=>:get
  match "/custom_features/ua_style_color_factory/upload" => "custom_features#ua_style_color_factory_upload", :via => :post
  match "/custom_features/ua_style_color_factory/:id/download" => "custom_features#ua_style_color_factory_download", :via => :get
  match "/custom_features/lumber_epd" => "custom_features#lumber_epd_index", :via=>:get
  match "/custom_features/lumber_epd/upload" => "custom_features#lumber_epd_upload", :via => :post
  match "/custom_features/lumber_epd/:id/download" => "custom_features#lumber_epd_download", :via => :get
  match "/custom_features/lumber_order_close" => "custom_features#lumber_order_close_index", :via=>:get
  match "/custom_features/lumber_order_close" => "custom_features#lumber_order_close", :via=>:post
  match "/custom_features/fenix_ci_load" => "custom_features#fenix_ci_load_index", :via=>:get
  match "/custom_features/fenix_ci_load/upload" => "custom_features#fenix_ci_load_upload", :via => :post
  match "/custom_features/fenix_ci_load/:id/download" => "custom_features#fenix_ci_load_download", :via => :get
  match "/custom_features/ecellerate_shipment_activity" => "custom_features#ecellerate_shipment_activity_index", :via=>:get
  match "/custom_features/ecellerate_shipment_activity/upload" => "custom_features#ecellerate_shipment_activity_upload", :via => :post
  match "/custom_features/ecellerate_shipment_activity/:id/download" => "custom_features#ecellerate_shipment_activity_download", :via => :get
  match "/custom_features/eddie_fenix_ci_load" => "custom_features#eddie_fenix_ci_load_index", :via=>:get
  match "/custom_features/eddie_fenix_ci_load/upload" => "custom_features#eddie_fenix_ci_load_upload", :via => :post
  match "/custom_features/eddie_fenix_ci_load/:id/download" => "custom_features#eddie_fenix_ci_load_download", :via => :get
  match "/custom_features/le_returns" => "custom_features#le_returns_index", :via=>:get
  match "/custom_features/le_returns/upload" => "custom_features#le_returns_upload", :via => :post
  match "/custom_features/le_returns/:id/download" => "custom_features#le_returns_download", :via => :get
  match "/custom_features/le_ci_load" => "custom_features#le_ci_load_index", :via=>:get
  match "/custom_features/le_ci_load/upload" => "custom_features#le_ci_load_upload", :via => :post
  match "/custom_features/le_ci_load/:id/download" => "custom_features#le_ci_load_download", :via => :get
  match "/custom_features/rl_fabric_parse" => "custom_features#rl_fabric_parse_index", :via=>:get
  match "/custom_features/rl_fabric_parse" => "custom_features#rl_fabric_parse_run", :via=>:post
  match "/custom_features/alliance_day_end" => "custom_features#alliance_day_end_index", :via=>:get
  match "/custom_features/alliance_day_end/upload" => "custom_features#alliance_day_end_upload", :via => :post
  match "/custom_features/alliance_day_end/:id/download" => "custom_features#alliance_day_end_download", :via => :get
  match "/custom_features/ascena_ca_invoices" => "custom_features#ascena_ca_invoices_index", :via=>:get
  match "/custom_features/ascena_ca_invoices/upload" => "custom_features#ascena_ca_invoices_upload", :via => :post
  match "/custom_features/ascena_ca_invoices/:id/download" => "custom_features#ascena_ca_invoices_download", :via => :get


  match "/custom_features/lenox_shipment_status" => "custom_features#lenox_shipment_status_index", :via=>:get
  match "/custom_features/lenox_shipment_status/upload" => "custom_features#lenox_shipment_status_upload", :via => :post
  match "/custom_features/lenox_shipment_status/:id/download" => "custom_features#lenox_shipment_status_download", :via => :get

  match "/custom_features/ci_load" => "custom_features#ci_load_index", :via=>:get
  match "/custom_features/ci_load/upload" => "custom_features#ci_load_upload", :via => :post
  match "/custom_features/ci_load/:id/download" => "custom_features#ci_load_download", :via => :get

  match "/custom_features/fisher_ci_load" => "custom_features#fisher_ci_load_index", :via=>:get
  match "/custom_features/fisher_ci_load/upload" => "custom_features#fisher_ci_load_upload", :via => :post
  match "/custom_features/fisher_ci_load/:id/download" => "custom_features#fisher_ci_load_download", :via => :get

  get "/custom_features/crew_returns" => "custom_features#crew_returns_index"
  post "/custom_features/crew_returns/upload" => "custom_features#crew_returns_upload"
  get "/custom_features/crew_returns/:id/download" => "custom_features#crew_returns_download"

  get "/custom_features/pvh_workflow" => "custom_features#pvh_workflow_index"
  post "/custom_features/pvh_workflow/upload" => "custom_features#pvh_workflow_upload"
  get "/custom_features/pvh_workflow/:id/download" => "custom_features#pvh_workflow_download"

  get "/custom_features/advan_parts" => "custom_features#advan_parts_index"
  post "/custom_features/advan_parts/upload" => "custom_features#advan_parts_upload"
  get "/custom_features/advan_parts/:id/download" => "custom_features#advan_parts_download"

  get "/custom_features/cq_origin" => "custom_features#cq_origin_index"
  post "/custom_features/cq_origin/upload" => "custom_features#cq_origin_upload"
  get "/custom_features/cq_origin/:id/download" => "custom_features#cq_origin_download"

  get "/custom_features/lumber_part" => "custom_features#lumber_part_index"
  post "/custom_features/lumber_part/upload" => "custom_features#lumber_part_upload"
  get "/custom_features/lumber_part/:id/download" => "custom_features#lumber_part_download"

  match "/custom_features/eddie_bauer_7501" => "custom_features#eddie_bauer_7501_index", :via => :get
  match "/custom_features/eddie_bauer_7501/upload" => "custom_features#eddie_bauer_7501_upload", :via => :post
  match "/custom_features/eddie_bauer_7501/:id/download" => "custom_features#eddie_bauer_7501_download", :via => :get

  #H&M specific
  match "/hm/po_lines" => 'hm#show_po_lines', via: :get
  match "/hm" => 'hm#index', via: :get

  #reports
  match "/reports" => "reports#index", :via => :get
  match "/reports/show_tariff_comparison" =>"reports#show_tariff_comparison", :via => :get
  match "/reports/run_tariff_comparison" => "reports#run_tariff_comparison", :via => :post
  match "/reports/show_stale_tariffs" => "reports#show_stale_tariffs", :via => :get
  match "/reports/run_stale_tariffs" => "reports#run_stale_tariffs", :via => :post
  match "/reports/show_poa_expirations" => "reports#show_poa_expirations", :via => :get
  match "/reports/run_poa_expirations" => "reports#run_poa_expirations", :via => :get
  match "/reports/show_shoes_for_crews_entry_breakdown" => "reports#show_shoes_for_crews_entry_breakdown", :via=>:get
  match "/reports/run_shoes_for_crews_entry_breakdown" => "reports#run_shoes_for_crews_entry_breakdown", :via=>:post
  match "/reports/big_search" => "reports#show_big_search_message", :via=>:get
  match "/reports/show_containers_released" => "reports#show_containers_released", :via=>:get
  match "/reports/run_containers_released" => "reports#run_containers_released", :via=>:post
  match "/reports/show_attachments_not_matched" => "reports#show_attachments_not_matched", :via=>:get
  match "/reports/run_attachments_not_matched" => "reports#run_attachments_not_matched", :via=>:post
  match "/reports/show_products_without_attachments" => "reports#show_products_without_attachments", :via=>:get
  match "/reports/run_products_without_attachments" => "reports#run_products_without_attachments", :via=>:post
  match "/reports/show_product_sync_problems" => "reports#show_product_sync_problems", :via=>:get
  match "/reports/run_product_sync_problems" => "reports#run_product_sync_problems", :via=>:post
  match "/reports/show_eddie_bauer_statement_summary" => "reports#show_eddie_bauer_statement_summary", :via=>:get
  match "/reports/run_eddie_bauer_statement_summary" => "reports#run_eddie_bauer_statement_summary", :via=>:post
  match "/reports/show_marc_jacobs_freight_budget" => "reports#show_marc_jacobs_freight_budget", :via=>:get
  match "/reports/run_marc_jacobs_freight_budget" => "reports#run_marc_jacobs_freight_budget", :via=>:post
  match "/reports/show_drawback_exports_without_imports" => "reports#show_drawback_exports_without_imports", :via=>:get
  match "/reports/run_drawback_exports_without_imports" => "reports#run_drawback_exports_without_imports", :via=>:post
  match "/reports/show_foot_locker_billing_summary" => "reports#show_foot_locker_billing_summary", :via=>:get
  match "/reports/run_foot_locker_billing_summary" => "reports#run_foot_locker_billing_summary", :via=>:post
  match "/reports/show_foot_locker_ca_billing_summary" => "reports#show_foot_locker_ca_billing_summary", :via=>:get
  match "/reports/run_foot_locker_ca_billing_summary" => "reports#run_foot_locker_ca_billing_summary", :via=>:post
  match "/reports/show_das_billing_summary" => "reports#show_das_billing_summary", :via=>:get
  match "/reports/run_das_billing_summary" => "reports#run_das_billing_summary", :via=>:post
  match "/reports/show_kitchencraft_billing" => "reports#show_kitchencraft_billing", :via=>:get
  match "/reports/run_kitchencraft_billing" => "reports#run_kitchencraft_billing", :via=>:post
  match "/reports/show_landed_cost" => "reports#show_landed_cost", :via=>:get
  match "/reports/run_landed_cost" => "reports#run_landed_cost", :via=>:post
  match "/reports/show_jcrew_billing" => "reports#show_jcrew_billing", :via=>:get
  match "/reports/run_jcrew_billing" => "reports#run_jcrew_billing", :via=>:post
  match "/reports/show_eddie_bauer_ca_statement_summary" => "reports#show_eddie_bauer_ca_statement_summary", :via=>:get
  match "/reports/run_eddie_bauer_ca_statement_summary" => "reports#run_eddie_bauer_ca_statement_summary", :via=>:post
  match "/reports/show_hm_statistics" => "reports#show_hm_statistics", :via => :get
  match "/reports/run_hm_statistics" => "reports#run_hm_statistics", :via => :post
  match "/reports/show_hm_ok_log" => "reports#show_hm_ok_log", :via => :get
  match "/reports/run_hm_ok_log" => "reports#run_hm_ok_log", :via => :post
  match "/reports/show_deferred_revenue" => "reports#show_deferred_revenue", :via => :get
  match "/reports/run_deferred_revenue" => "reports#run_deferred_revenue", :via => :post
  match "/reports/show_j_jill_weekly_freight_summary" => "reports#show_j_jill_weekly_freight_summary", :via=>:get
  match "/reports/run_j_jill_weekly_freight_summary" => "reports#run_j_jill_weekly_freight_summary", :via=>:post
  match "/reports/show_drawback_audit_report" => "reports#show_drawback_audit_report", :via=>:get
  match "/reports/run_drawback_audit_report" => "reports#run_drawback_audit_report", :via=>:post
  match "/reports/show_rl_tariff_totals" =>"reports#show_rl_tariff_totals", :via=>:get
  match "/reports/run_rl_tariff_totals" =>"reports#run_rl_tariff_totals", :via=>:post
  match "/reports/show_eddie_bauer_ca_k84_summary" => "reports#show_eddie_bauer_ca_k84_summary", :via=>:get
  match "/reports/run_eddie_bauer_ca_k84_summary" => "reports#run_eddie_bauer_ca_k84_summary", :via=>:post
  match "/reports/show_pvh_billing_summary" => "reports#show_pvh_billing_summary", :via => :get
  match "/reports/run_pvh_billing_summary" => "reports#run_pvh_billing_summary", :via => :post
  match "/reports/show_sg_duty_due_report" => "reports#show_sg_duty_due_report", :via => :get
  match "/reports/run_sg_duty_due_report" => "reports#run_sg_duty_due_report", :via => :post
  match "/reports/show_ll_prod_risk_report" => "reports#show_ll_prod_risk_report", :via => :get
  match "/reports/run_ll_prod_risk_report" => "reports#run_ll_prod_risk_report", :via => :post
  get "/reports/show_pvh_container_log" => "reports#show_pvh_container_log"
  post "/reports/run_pvh_container_log" => "reports#run_pvh_container_log"
  get "reports/show_monthly_entry_summation" => "reports#show_monthly_entry_summation"
  post "reports/run_monthly_entry_summation" => "reports#run_monthly_entry_summation"
  get "/reports/show_container_cost_breakdown" => "reports#show_container_cost_breakdown"
  post "/reports/run_container_cost_breakdown" => "reports#run_container_cost_breakdown"
  get "/reports/show_ll_dhl_order_push_report" => "reports#show_ll_dhl_order_push_report"
  post "/reports/run_ll_dhl_order_push_report" => "reports#run_ll_dhl_order_push_report"
  get "/reports/show_j_crew_drawback_imports_report" => "reports#show_j_crew_drawback_imports_report"
  post "/reports/run_j_crew_drawback_imports_report" => "reports#run_j_crew_drawback_imports_report"
  get "/reports/show_ua_duty_planning_report" => "reports#show_ua_duty_planning_report"
  post "/reports/run_ua_duty_planning_report" => "reports#run_ua_duty_planning_report"

  resources :report_results, :only => [:index,:show] do
    get 'download', :on => :member
  end
  resources :custom_reports, :except=>[:index,:edit] do
    member do
      get 'preview'
      get 'run'
      get 'give'
      get 'copy'
    end
  end

  resources :custom_definitions

  resources :worksheet_configs

  resources :messages, :only => [:index, :new, :create, :destroy] do
    member do
      get 'read'
    end
    collection do
      get 'new_bulk'
      get 'read_all'
      get 'message_count'
      post 'send_to_users'
    end
  end

  resources :user_sessions, :only => [:index,:new,:create,:destroy]

  resources :item_change_subscriptions

	resources :piece_sets

  resources :shipments do
    member do
      get 'history'
      get 'make_invoice'
      put 'generate_invoice'
      get :download
    end
    resources :shipment_lines do
      post :create_multiple, :on => :collection
    end
	end

	resources :deliveries do
    member do
      get 'history'
    end
    resources :delivery_lines do
      post :create_multiple, :on => :collection
    end
	end

  resources :products do
    collection do
      post 'bulk_edit'
      post 'bulk_update'
      post 'bulk_classify'
      post 'bulk_update_classifications'
      post 'bulk_instant_classify'
      post 'show_bulk_instant_classify'
    end
    member do
      get 'show_beta'
      get 'history'
      get :next_item
      get :previous_item
      put :import_worksheet
      get :validation_results
    end
    post :import_new_worksheet, :on=>:new
  end
  resources :product_groups, only: [:index, :create, :update, :destroy]

  resources :orders do
    member do
      get 'history'
      get 'validation_results'
      post 'close'
      post 'reopen'
      post 'accept'
      post 'unaccept'
    end
		resources :order_lines
	end

  resources :sales_orders do
    get 'all_open', on: :collection
    member do
      get 'history'
    end
    resources :sales_order_lines
  end

  resources :countries
  resources :regions, :only => [:index,:create,:destroy,:update] do
    member do
      get 'add_country'
      get 'remove_country'
    end
  end

	resources :addresses do
		get 'render_partial', :on => :member
	end

  resources :users, :only => [:index] do
    resources :scheduled_reports, :only=>[:index]
  end

  resources :scheduled_reports, :only => [] do
    collection do
      post 'give_reports'
    end
  end

  resources :vendors, :only => [:show,:index,:new,:create] do
    member do
      get 'addresses'
      get 'orders'
      get 'plants'
      get 'products'
      get 'survey_responses'
      get 'validation_results'
    end
    collection do
      get 'matching_vendors'
    end
    resources :vendor_plants, only: [:show,:edit,:update,:create] do
      member do
        get 'unassigned_product_groups'
        post 'assign_product_group'
      end
      resources :plant_product_group_assignments, only: [:show,:update]
    end
  end
  resources :companies do
    member do
      get 'show_children'
      post 'update_children'
      post 'push_alliance_products'
      get 'validation_results'
    end
		resources :addresses
		resources :divisions
    resources :power_of_attorneys, :only => [:index, :new, :create, :destroy] do
      member do
        get 'download'
      end
    end
    resources :attachment_archive_manifests, :only=>[:create] do
      get 'download', :on=>:member
    end
    resources :attachment_archives, :only=>[:create, :show] do
      post 'complete', :on=>:member
    end
    resources :attachment_archive_setups, :except=>[:destroy,:index]

		resources :users do
      member do
  		  get :disable
  		  get :enable
        get :event_subscriptions
      end
      collection do
        get :show_bulk_upload
        post :bulk_invite
        post :bulk_upload
        post :preview_bulk_upload
        get :create_from_template, to: 'users#show_create_from_template'
        post :create_from_template
      end
      resources :debug_records, :only => [:index, :show] do
        get :destroy_all, :on => :collection
      end
    end
    resources :charge_categories, :only => [:index, :create, :destroy]
		get :shipping_address_list, :on => :member
    get :attachment_archive_enabled, :on => :collection
  end

  resources :file_import_results, :only => [:show] do
    member do
      get 'messages'
      get 'download_all'
      get 'download_failed'
    end
  end

  resources :bulk_process_logs, :only => [:show] do
    member do
      get 'messages'
    end
  end

  resources :imported_files, :only => [:index, :show, :destroy] do
    member do
      get 'preview'
      post 'email_file'
      get 'download'
      post 'download_items'
      post 'process_file'
      put 'update_search_criterions'
    end
    get 'show_angular', :on=>:collection
    resources :imported_file_downloads, :only=>[:index,:show]
  end
  match "/imported_files_results/:id" => "imported_files#results", :via=>:get
  match "/imported_files_results/:id/total_objects" => "imported_files#total_objects", :via => :get

  resources :search_setups do
    collection do
      post 'sticky_open'
      post 'sticky_close'
    end
    member do
      get 'copy'
      post 'copy'
      get 'give'
      post 'give'
      get 'attachments'
    end
    resources :imported_files, :only => [:new, :create, :show] do
      member do
        get 'download'
      end
    end
  end

  resources :surveys do
    member do
      get 'show_assign'
      get 'toggle_subscription'
      post 'assign'
      get 'copy'
      put 'archive'
      put 'restore'
    end
  end
  resources :survey_responses do
    member do
      get 'invite'
      put 'archive'
      put 'restore'
      post 'remind'
    end
    resources :corrective_action_plans, :only=>[:show,:create,:destroy,:update] do
      post 'add_comment', on: :member
      put 'activate', on: :member
      put 'resolve', on: :member
    end
    resources :survey_response_logs, :only=>[:index]
  end
  resources :answers, only:[:update] do
    resources :answer_comments, only:[:create]
  end
  resources :corrective_issues, :only=>[:create,:update,:destroy] do
    post 'update_resolution', on: :member, to: :update_resolution_status
  end

  resources :drawback_upload_files, :only=>[:index,:create] do
    put 'process_j_crew_entries', on: :collection
  end
  resources :duty_calc_import_files, :only=>[:create] do
    get 'download', on: :member
  end
  resources :duty_calc_export_files, :only=>[:create] do
    get 'download', on: :member
  end
  resources :drawback_claims do
    post 'process_report', on: :member
    post 'audit_report', on: :member
    get 'validation_results', on: :member
    delete 'clear_claim_audits', on: :member
    delete 'clear_export_histories', on: :member
  end

  resources :error_log_entries, :only => [:index, :show]
  match '/ang_error' => 'error_log_entries#log_angular', via: :post
  resources :charge_codes, :only => [:index, :update, :create, :destroy]
  resources :ports, :only => [:index, :update, :create, :destroy]
  resources :security_filings, :only=>[:index, :show]
  resources :sync_records do
    post 'resend', :on=>:member
  end

  resources :project_sets, only: [:show]

  match '/projects/:id/add_project_set/:project_set_name' => 'projects#add_project_set', via: :post
  match '/projects/:id/remove_project_set/:project_set_name' => 'projects#remove_project_set', via: :delete
  resources :projects, except: [:destroy] do
    resources :project_updates, only: [:update,:create]
    resources :project_deliverables, only: [:update,:create]
    put 'toggle_close', on: :member
    put 'toggle_on_hold', on: :member
  end
  resources :project_deliverables, only: [:index]
  resources :schedulable_jobs, except: [:show] do
    post 'run', on: :member
  end
  resources :intacct_errors, only: [:index] do
    # Gets are here to accomodate clearing directly from Excel exception report
    put 'clear_receivable', on: :member
    get 'clear_receivable', on: :member
    put 'clear_payable', on: :member
    get 'clear_payable', on: :member
    put 'clear_check', on: :member
    get 'clear_check', on: :member
  end
  match "/intacct_errors/push_to_intacct" => "intacct_errors#push_to_intacct", via: :post

  resources :data_cross_references do
    get 'show' => "data_cross_references#edit"
  end

  resources :search_templates, only: [:index,:destroy]

  resources :milestone_notification_configs, only: [:index]

  resources :user_templates

  match "/vendor_portal" => "vendor_portal#index", via: :get


  resources :groups, except: [:show]

  resources :summary_statements, except: [:destroy] do
    get 'get_invoices', :on=>:member
  end

  resources :user_manuals, except: [:show] do
    get :download, on: :member
    get :for_referer, on: :collection
  end

  resources :custom_view_templates, except: [:show]

  resources :trade_lanes, only: [:index]

  #Griddler inbound email processing
  mount_griddler

  #Jasmine test runner
  mount JasmineRails::Engine => "/specs" if defined?(JasmineRails) && !Rails.env.production?

  root :to => "home#index"
end
