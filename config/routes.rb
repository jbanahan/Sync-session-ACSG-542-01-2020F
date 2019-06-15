OpenChain::Application.routes.draw do
  # redirect bootstrap glyphicon fonts to public path
  get '/assets/:subpath/fonts/:font.woff2', to: redirect('/%{subpath}/fonts/%{font}.woff2', status: 302)
  get '/assets/:subpath/fonts/:font.woff', to: redirect('/%{subpath}/fonts/%{font}.woff', status: 302)
  get '/assets/:subpath/fonts/:font.ttf', to: redirect('/%{subpath}/fonts/%{font}.ttf', status: 302)
  get '/assets/:subpath/fonts/:font.svg', to: redirect('/%{subpath}/fonts/%{font}.svg', status: 302)
  get '/assets/:subpath/fonts/:font.eot', to: redirect('/%{subpath}/fonts/%{font}.eot', status: 302)

  # Resolves font-awesome requests with a URL this is not based underneath assets...I believe this just happens on dev. machines.
  get '/:subpath/fonts/:font.woff2', to: redirect('/fonts/%{font}.woff2', status: 302)
  get '/:subpath/fonts/:font.woff', to: redirect('/fonts/%{font}.woff', status: 302)
  get '/:subpath/fonts/:font.ttf', to: redirect('/fonts/%{font}.ttf', status: 302)
  get '/:subpath/fonts/:font.svg', to: redirect('/fonts/%{font}.svg', status: 302)
  get '/:subpath/fonts/:font.eot', to: redirect('/fonts/%{font}.eot', status: 302)

  get '/hts/subscribed_countries', to: 'hts#subscribed_countries'
  get '/hts/:iso/heading/:heading', to: 'hts#heading'
  get '/hts/:iso/chapter/:chapter', to: 'hts#chapter'
  get '/hts/:iso', to: 'hts#country'
  get '/hts', to: 'hts#index'

  get "auth/:provider/callback", to: "user_sessions#create_from_omniauth"
  get 'auth/failure', to: redirect("/login")

  namespace :api do
    namespace :v1 do
      get '/business_rules/for_module/:module_type/:id', to: 'business_rules#for_module'
      get '/business_rules/refresh/:module_type/:id', to: 'business_rules#refresh'
      get '/comments/for_module/:module_type/:id', to: 'comments#for_module'
      get '/messages/count/:user_id', to: 'messages#count'
      get "/emails/validate_email_list", to: "emails#validate_email_list"
      post "/entries/importer/:importer_id/activity_summary/us/download", to: 'entries#store_us_activity_summary_download'
      post "/entries/importer/:importer_id/activity_summary/ca/download", to: 'entries#store_ca_activity_summary_download'
      post "/entries/importer/:importer_id/activity_summary/us/email", to: 'entries#email_us_activity_summary_download'
      post "/entries/importer/:importer_id/activity_summary/ca/email", to: 'entries#email_ca_activity_summary_download'
      resources :messages, only: [:index, :create] do
        post :mark_as_read, on: :member
      end
      resources :comments, only: [:create,:destroy]
      get "/:base_object_type/:base_object_id/comments", to: "comments#polymorphic_index"
      post "/:base_object_type/:base_object_id/comments", to: "comments#polymorphic_create"
      get "/:base_object_type/:base_object_id/comment/:id", to: "comments#polymorphic_show"
      delete "/:base_object_type/:base_object_id/comment/:id", to: "comments#polymorphic_destroy"

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
          post :send_shipment_instructions
          match 'book_order/:order_id', to: 'shipments#book_order', via: [:put, :patch]
          get :state_toggle_buttons
          post :toggle_state_button
        end
        collection do
          post 'booking_from_order/:order_id', to: 'shipments#create_booking_from_order'
          get 'open_bookings', to: "shipments#open_bookings"
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
          get :enabled_users
          post 'me/toggle_email_new_messages', to: 'users#toggle_email_new_messages'
          post :change_my_password
        end

      end

      resources :official_tariffs, only: [] do
        get 'find/:iso/:hts', to: 'official_tariffs#find', on: :collection, constraints: {hts: /[\d\.]+/}
      end
      resources :products, only: [:index, :show, :create, :update] do
        # The optional param is for temporary backwards compatibility on the API
        get 'by_uid(/:path_uid)', to: "products#by_uid", on: :collection
        get :state_toggle_buttons, on: :member
        post :toggle_state_button, on: :member
        post :validate, on: :member
      end
      resources :variants, only: [:show] do
        get 'for_vendor_product/:vendor_id/:product_id', to: 'variants#for_vendor_product', on: :collection
      end
      resources :product_rate_overrides, only: [:index, :show, :update, :create]

      resources :plants, only: [] do
        get :state_toggle_buttons, on: :member
        post :toggle_state_button, on: :member
      end

      resources :plant_product_group_assignments, only: [] do
        get :state_toggle_buttons, on: :member
        post :toggle_state_button, on: :member
      end

      resources :product_vendor_assignments, only: [:index,:show,:update,:create] do
        collection do 
          match :bulk_update, via: [:put, :patch]
          post :bulk_create
        end
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

      resources :vendors, only: [:index,:show,:update,:create] do
        post :validate, on: :member
        get :state_toggle_buttons, on: :member
        post :toggle_state_button, on: :member
      end

      resources :user_manuals, only: [:index]

      resources :trade_lanes, except: [:destroy]
      resources :trade_preference_programs, except: [:destroy]
      resources :tpp_hts_overrides, except: [:destroy]

      get "/setup_data", to: "setup_data#index"

      get "/ports/autocomplete", to: "ports#autocomplete"
      get "/divisions/autocomplete", to: "divisions#autocomplete"

      post "/intacct_data/receive_alliance_invoice_details", to: "intacct_data#receive_alliance_invoice_details"
      post "/intacct_data/receive_check_result", to: "intacct_data#receive_check_result"
      post "/alliance_data/receive_alliance_entry_details", to: "alliance_data#receive_alliance_entry_details"
      post "/alliance_data/receive_alliance_entry_tracking_details", to: "alliance_data#receive_alliance_entry_tracking_details"
      post "/alliance_data/receive_updated_entry_numbers", to: "alliance_data#receive_updated_entry_numbers"
      post "/alliance_data/receive_entry_data", to: "alliance_data#receive_entry_data"
      post "/alliance_data/receive_mid_updates", to: "alliance_data#receive_mid_updates"
      post "/alliance_data/receive_address_updates", to: "alliance_data#receive_address_updates"
      post "/alliance_reports/receive_alliance_report_data", to: "alliance_reports#receive_alliance_report_data"
      post "/sql_proxy_postbacks/receive_sql_proxy_report_data", to: "sql_proxy_postbacks#receive_sql_proxy_report_data"

      post "/schedulable_jobs/run_jobs", to: "schedulable_jobs#run_jobs"

      get "/:base_object_type/:base_object_id/attachments", to: "attachments#index"
      post "/:base_object_type/:base_object_id/attachments", to: "attachments#create"
      get "/:base_object_type/:base_object_id/attachment/:id", to: "attachments#show"
      delete "/:base_object_type/:base_object_id/attachment/:id", to: "attachments#destroy"
      get "/:base_object_type/:base_object_id/attachment/:id/download", to: "attachments#download"
      get "/:base_object_type/:base_object_id/attachment_types", to: "attachments#attachment_types"
      get "/data_cross_references/count_xrefs", to: "data_cross_references#count_xrefs"

      post "/feedback/send_feedback", to: 'feedback#send_feedback'

      namespace :admin do
        get 'event_subscriptions/:event_type/:subscription_type/:object_id', to: "event_subscriptions#show_by_event_type_object_id_and_subscription_type"
        post 'search_setups/:id/create_template', to: 'search_setups#create_template'
        get "/settings/paths", to: "settings#paths"
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

        resources :groups, only: [:create, :update, :destroy]

        resources :custom_view_templates, only: [:edit, :update]

        resources :state_toggle_buttons, only: [:edit, :update, :destroy]

        resources :business_validation_schedules, except: [:show]

        resources :kewill_entry_documents, only: [] do
          collection do
            post :send_s3_file_to_kewill
          end
        end

      end
      
      resources :one_time_alerts, only: [:edit, :update, :destroy] do 
        collection do
          post 'update_reference_fields'
        end
      end

      resources :fenix_postbacks, only: [] do
        collection do
          post :receive_lvs_results
        end
      end

      resources :addresses, only: [:index, :create, :update, :destroy] do 
        collection do 
          get :autocomplete
        end
      end

      resources :countries, only: [:index]

      resources :support_requests, only: [:create]

      resources :search_criterions, only: [:index, :create, :update, :destroy]

      get "/:base_object_type/:base_object_id/folders", to: "folders#index"
      post "/:base_object_type/:base_object_id/folders", to: "folders#create"
      get "/:base_object_type/:base_object_id/folder/:id", to: "folders#show"
      match "/:base_object_type/:base_object_id/folder/:id", to: "folders#update", via: [:put, :patch]
      delete "/:base_object_type/:base_object_id/folder/:id", to: "folders#destroy"

      resources :groups, only: [:index, :show]
      get "/groups/show_excluded_users/:id", to: "groups#show_excluded_users"
      post "/:base_object_type/:base_object_id/groups/:id/add", to: "groups#add_to_object"
      post "/:base_object_type/:base_object_id/groups", to: "groups#set_groups_for_object"

      resources :search_table_configs, only: [] do
        get 'for_page/:page_uid', to: "search_table_configs#for_page", on: :collection
      end
    end
  end

  resources :aws_backup_sessions, only: [:index, :show]
  namespace :customer do
    get '/lumber_liquidators/sap_vendor_setup_form/:vendor_id', to: 'lumber_liquidators#sap_vendor_setup_form'
  end
  resources :delayed_jobs, :only => [:destroy] do
    member do
      delete :bulk_destroy
      post :run_now
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

  resources :inbound_files, :only => [:index, :show] do
    member do
      get 'download'
      post 'reprocess'
    end
  end

  get '/entries/activity_summary/us', to: 'entries#us_activity_summary'
  get '/entries/importer/:importer_id/activity_summary/us', to: 'entries#us_activity_summary', as: :entries_activity_summary_us_with_importer
  get '/entries/importer/:importer_id/activity_summary/us/content', to: 'entries#us_activity_summary_content'
  get '/entries/importer/:importer_id/activity_summary/us/duty_detail', to: 'entries#us_duty_detail'

  get '/entries/activity_summary/ca', to: 'entries#ca_activity_summary'
  get '/entries/importer/:importer_id/activity_summary/ca', to: 'entries#ca_activity_summary', as: :entries_activity_summary_ca_with_importer
  get '/entries/importer/:importer_id/activity_summary/ca/content', to: 'entries#ca_activity_summary_content'

  get '/entries/importer/:importer_id/entry_port/:port_code/country/:iso_code', to: 'entries#by_entry_port'
  get '/entries/importer/:importer_id/country/:iso_code/release_range/:release_range', to: 'entries#by_release_range'
  get '/entries/importer/:importer_id/country/:iso_code/release_range/:release_range/download', to: 'entries#by_release_range_download'
  get "/entries/bi", to: "entries#bi_three_month"
  get "/entries/bi/three_month", to: "entries#bi_three_month"
  get "/entries/bi/three_month_hts", to: "entries#bi_three_month_hts"

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
      post 'bulk_get_images'
      post 'bulk_request_entry_data'
      post 'bulk_send_last_integration_file_to_test'
    end

    resources :broker_invoices do 
      member do 
        get 'sync_records'
      end
    end
  end

  resources :business_validation_templates do
    member do 
      get 'download'
      post 'copy'
    end
    collection do 
      post 'upload'
    end
    resources :t_search_criterions, only: [:new, :create, :destroy]
    resources :business_validation_rules, only: [:create, :destroy, :edit, :update] do
      member do 
        post 'copy'
        get 'download'
      end
      collection do 
        post 'upload'
      end
      resources :r_search_criterions, only: [:new, :create, :destroy]
    end
  end

  get '/business_validation_templates/:id/manage_criteria', to: 'business_validation_templates#manage_criteria'
  get '/business_validation_templates/:id/edit_angular', to: 'business_validation_templates#edit_angular'
  get '/business_validation_rules/:id/edit_angular', to: 'business_validation_rules#edit_angular'

  resources :business_validation_rule_results, only: [:update] do
    match 'cancel_override', :on=>:member, via: [:put, :patch]
  end

  resources :commercial_invoices, :only => [:show]
  resources :broker_invoices, :only => [:index,:show] do
    member do 
      get 'sync_records'
    end

    collection do
      post 'bulk_send_last_integration_file_to_test'
    end
  end
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
    member do 
      post 'restore'
      get 'download'
      get 'download_integration_file'
    end
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
  resources :field_labels, only: [:index] do
    post 'save', :on=>:collection
  end
  resources :password_resets, only: [:edit, :create, :update]
  resources :dashboard_widgets, only: [:index] do
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
      post 'release_migration_lock'
      post 'clear_upgrade_errors'
    end
  end
  resources :upgrade_logs, :only=>[:show]
  resources :attachment_types

  get "/official_tariffs/auto_classify/:hts", to: "official_tariffs#auto_classify"

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

  # TODO Fix this route to be resourceful
  get "/attachments/email_attachable/:attachable_type/:attachable_id", to: "attachments#show_email_attachable"
  post "/attachments/email_attachable/:attachable_type/:attachable_id", to: "attachments#send_email_attachable"

  resources :attachments do
    member do
      get 'download'
    end

    collection do
      get 'download_last_integration_file'
      post 'send_last_integration_file_to_test'
    end
  end

  resources :comments do
    post 'send_email', on: :member
    post 'bulk_count', on: :collection
    post 'bulk', on: :collection
  end

  resources :public_fields, only: [:index] do
    collection do 
      post :save
    end
  end

  # TODO Fix these routes to be resourceful
  get "email_attachments/:id", to: "email_attachments#show", as: :email_attachments_show
  post "email_attachments/:id/download", to: "email_attachments#download", as: :email_attachments_download
  resources :email_attachments, only: [:show] do
    post :download
  end

  resources :advanced_search, :only => [:show,:index,:update,:create,:destroy] do
    get 'last_search_id', :on=>:collection
    member do
      get 'setup'
      get 'download'
      post 'send_email'
      get 'total_objects'
      get 'show_audit'
      get 'download_audit'
      post 'audit'
    end
  end

  resources :random_audits, :only => [] do
    get 'download', on: :member
  end

  resources :run_as_sessions, :only => [:index, :show]
  resources :invoices, :only => [:index, :show] do
    member do
      get 'history'
    end
  end

  #custom features
  match "/custom_features" => "custom_features#index", :via => :get
  match "/custom_features/ua_winshuttle_b" => "custom_features#ua_winshuttle_b_index", :via=>:get
  match "/custom_features/ua_winshuttle_b" => "custom_features#ua_winshuttle_b_send", :via=>:post
  match "/custom_features/ua_winshuttle" => "custom_features#ua_winshuttle_index", :via=>:get
  match "/custom_features/ua_winshuttle" => "custom_features#ua_winshuttle_send", :via=>:post
  match "/custom_features/ua_sites_subs" => "custom_features#ua_sites_subs_index", :via=>:get
  match "/custom_features/ua_sites_subs" => "custom_features#ua_sites_subs_send", :via=>:post
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
  match "/custom_features/le_chapter_98/:id/download" => "custom_features#le_chapter_98_download", :via => :get
  match "/custom_features/le_chapter_98_load" => "custom_features#le_chapter_98_index", :via => :get
  match "/custom_features/le_chapter_98/upload" => "custom_features#le_chapter_98_upload", :via => :post
  match "/custom_features/rl_fabric_parse" => "custom_features#rl_fabric_parse_index", :via=>:get
  match "/custom_features/rl_fabric_parse" => "custom_features#rl_fabric_parse_run", :via=>:post
  match "/custom_features/alliance_day_end" => "custom_features#alliance_day_end_index", :via=>:get
  match "/custom_features/alliance_day_end/upload" => "custom_features#alliance_day_end_upload", :via => :post
  match "/custom_features/alliance_day_end/:id/download" => "custom_features#alliance_day_end_download", :via => :get
  match "/custom_features/ascena_ca_invoices" => "custom_features#ascena_ca_invoices_index", :via=>:get
  match "/custom_features/ascena_ca_invoices/upload" => "custom_features#ascena_ca_invoices_upload", :via => :post
  match "/custom_features/ascena_ca_invoices/:id/download" => "custom_features#ascena_ca_invoices_download", :via => :get

  get "/custom_features/hm_po_line_parser", to: "custom_features#hm_po_line_parser_index"
  post "/custom_features/hm_po_line_parser/upload", to: "custom_features#hm_po_line_parser_upload"
  get "/custom_features/hm_po_line_parser/:id/download", to: "custom_features#hm_po_line_parser_download"

  match "/custom_features/lenox_shipment_status" => "custom_features#lenox_shipment_status_index", :via=>:get
  match "/custom_features/lenox_shipment_status/upload" => "custom_features#lenox_shipment_status_upload", :via => :post
  match "/custom_features/lenox_shipment_status/:id/download" => "custom_features#lenox_shipment_status_download", :via => :get

  match "/custom_features/ci_load" => "custom_features#ci_load_index", :via=>:get
  match "/custom_features/ci_load/upload" => "custom_features#ci_load_upload", :via => :post
  match "/custom_features/ci_load/:id/download" => "custom_features#ci_load_download", :via => :get

  match "/custom_features/fisher_ci_load" => "custom_features#fisher_ci_load_index", :via=>:get
  match "/custom_features/fisher_ci_load/upload" => "custom_features#fisher_ci_load_upload", :via => :post
  match "/custom_features/fisher_ci_load/:id/download" => "custom_features#fisher_ci_load_download", :via => :get

  get "/custom_features/crew_returns", to: "custom_features#crew_returns_index"
  post "/custom_features/crew_returns/upload", to: "custom_features#crew_returns_upload"
  get "/custom_features/crew_returns/:id/download", to: "custom_features#crew_returns_download"

  get "/custom_features/pvh_workflow", to: "custom_features#pvh_workflow_index"
  post "/custom_features/pvh_workflow/upload", to: "custom_features#pvh_workflow_upload"
  get "/custom_features/pvh_workflow/:id/download", to: "custom_features#pvh_workflow_download"

  get "/custom_features/pvh_ca_workflow", to: "custom_features#pvh_ca_workflow_index"
  post "/custom_features/pvh_ca_workflow/upload", to: "custom_features#pvh_ca_workflow_upload"
  get "/custom_features/pvh_ca_workflow/:id/download", to: "custom_features#pvh_ca_workflow_download"

  get "/custom_features/advan_parts", to: "custom_features#advan_parts_index"
  post "/custom_features/advan_parts/upload", to: "custom_features#advan_parts_upload"
  get "/custom_features/advan_parts/:id/download", to: "custom_features#advan_parts_download"

  get "/custom_features/cq_origin", to: "custom_features#cq_origin_index"
  post "/custom_features/cq_origin/upload", to: "custom_features#cq_origin_upload"
  get "/custom_features/cq_origin/:id/download", to: "custom_features#cq_origin_download"

  get "/custom_features/lumber_part", to: "custom_features#lumber_part_index"
  post "/custom_features/lumber_part/upload", to: "custom_features#lumber_part_upload"
  get "/custom_features/lumber_part/:id/download", to: "custom_features#lumber_part_download"

  get "/custom_features/lumber_carb", to: "custom_features#lumber_carb_index"
  post "/custom_features/lumber_carb/upload", to: "custom_features#lumber_carb_upload"
  get "/custom_features/lumber_carb/:id/download", to: "custom_features#lumber_carb_download"

  get "/custom_features/lumber_patent", to: "custom_features#lumber_patent_index"
  post "/custom_features/lumber_patent/upload", to: "custom_features#lumber_patent_upload"
  get "/custom_features/lumber_patent/:id/download", to: "custom_features#lumber_patent_download"

  get "/custom_features/eddie_bauer_7501", to: "custom_features#eddie_bauer_7501_index"
  post "/custom_features/eddie_bauer_7501/upload", to: "custom_features#eddie_bauer_7501_upload"
  get "/custom_features/eddie_bauer_7501/:id/download", to: "custom_features#eddie_bauer_7501_download"

  get "/custom_features/ascena_product", to: "custom_features#ascena_product_index"
  post "/custom_features/ascena_product/upload", to: "custom_features#ascena_product_upload"
  get "/custom_features/ascena_product/:id/download", to: "custom_features#ascena_product_download"

  get "/custom_features/ua_missing_classifications", to: "custom_features#ua_missing_classifications_index"
  post "/custom_features/ua_missing_classifications/upload", to: "custom_features#ua_missing_classifications_upload"
  get "/custom_features/ua_missing_classifications/:id/download", to: "custom_features#ua_missing_classifications_download"

  get "/custom_features/isf_late_filing", to: "custom_features#isf_late_filing_index"
  post "/custom_features/isf_late_filing/upload", to: "custom_features#isf_late_filing_upload"
  get "/custom_features/isf_late_filing/:id/download", to: "custom_features#isf_late_filing_download"

  get "/custom_features/intacct_invoice", to: "custom_features#intacct_invoice_index"
  post "/custom_features/intacct_invoice/upload", to: "custom_features#intacct_invoice_upload"
  get "/custom_features/intacct_invoice/:id/download", to: "custom_features#intacct_invoice_download"

  get "/custom_features/lumber_allport_billing", to: "custom_features#lumber_allport_billing_index"
  post "/custom_features/lumber_allport_billing/upload", to: "custom_features#lumber_allport_billing_upload"
  get "/custom_features/lumber_allport_billing/:id/download", to: "custom_features#lumber_allport_billing_download"

  get "/custom_features/customer_invoice_handler", to: "custom_features#customer_invoice_index"
  post "/custom_features/customer_invoice_handler/upload", to: "custom_features#customer_invoice_upload"
  get "/custom_features/customer_invoice_handler/:id/download", to: "custom_features#customer_invoice_download"

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
  match "/reports/show_special_programs_savings_report" => "reports#show_special_programs_savings_report", :via => :get
  match "/reports/run_special_programs_savings_report" => "reports#run_special_programs_savings_report", :via => :post  
  get "/reports/show_pvh_container_log", to: "reports#show_pvh_container_log"
  post "/reports/run_pvh_container_log", to: "reports#run_pvh_container_log"
  get "/reports/show_pvh_air_shipment_log", to: "reports#show_pvh_air_shipment_log"
  post "/reports/run_pvh_air_shipment_log", to: "reports#run_pvh_air_shipment_log"
  get "reports/show_monthly_entry_summation", to: "reports#show_monthly_entry_summation"
  post "reports/run_monthly_entry_summation", to: "reports#run_monthly_entry_summation"
  get "/reports/show_container_cost_breakdown", to: "reports#show_container_cost_breakdown"
  post "/reports/run_container_cost_breakdown", to: "reports#run_container_cost_breakdown"
  get "/reports/show_ll_dhl_order_push_report", to: "reports#show_ll_dhl_order_push_report"
  post "/reports/run_ll_dhl_order_push_report", to: "reports#run_ll_dhl_order_push_report"
  get "/reports/show_j_crew_drawback_imports_report", to: "reports#show_j_crew_drawback_imports_report"
  post "/reports/run_j_crew_drawback_imports_report", to: "reports#run_j_crew_drawback_imports_report"
  get "/reports/show_ua_duty_planning_report", to: "reports#show_ua_duty_planning_report"
  post "/reports/run_ua_duty_planning_report", to: "reports#run_ua_duty_planning_report"
  get "/reports/show_lumber_actualized_charges_report", to: "reports#show_lumber_actualized_charges_report"
  post "/reports/run_lumber_actualized_charges_report", to: "reports#run_lumber_actualized_charges_report"
  get "/reports/show_entries_with_holds_report", to: "reports#show_entries_with_holds_report"
  post "/reports/run_entries_with_holds_report", to: "reports#run_entries_with_holds_report"
  get "/reports/show_rl_jira_report", to: "reports#show_rl_jira_report"
  post "/reports/run_rl_jira_report", to: "reports#run_rl_jira_report"
  get "/reports/show_duty_savings_report", to: "reports#show_duty_savings_report"
  post "/reports/run_duty_savings_report", to: "reports#run_duty_savings_report"
  get "/reports/show_daily_first_sale_exception_report", to: "reports#show_daily_first_sale_exception_report"
  post "/reports/run_daily_first_sale_exception_report", to: "reports#run_daily_first_sale_exception_report"
  get "/reports/show_ticket_tracking_report", to: "reports#show_ticket_tracking_report"
  post "/reports/run_ticket_tracking_report", to: "reports#run_ticket_tracking_report"
  get "/reports/show_ascena_entry_audit_report", to: "reports#show_ascena_entry_audit_report"
  post "/reports/run_ascena_entry_audit_report", to: "reports#run_ascena_entry_audit_report"
  get "/reports/show_ascena_duty_savings_report", to: "reports#show_ascena_duty_savings_report"
  post "/reports/run_ascena_duty_savings_report", to: "reports#run_ascena_duty_savings_report"
  get "/reports/show_ascena_mpf_savings_report", to: "reports#show_ascena_mpf_savings_report"
  post "/reports/run_ascena_mpf_savings_report", to: "reports#run_ascena_mpf_savings_report"
  get "/reports/show_ppq_by_po_report", to: "reports#show_ppq_by_po_report"
  post "/reports/run_ppq_by_po_report", to: "reports#run_ppq_by_po_report"
  get "/reports/show_ascena_actual_vs_potential_first_sale_report", to: "reports#show_ascena_actual_vs_potential_first_sale_report"
  post "/reports/run_ascena_actual_vs_potential_first_sale_report", to: "reports#run_ascena_actual_vs_potential_first_sale_report"
  get "/reports/show_ascena_vendor_scorecard_report", to: "reports#show_ascena_vendor_scorecard_report"
  post "/reports/run_ascena_vendor_scorecard_report", to: "reports#run_ascena_vendor_scorecard_report"
  get "/reports/show_lumber_order_snapshot_discrepancy_report", to: "reports#show_lumber_order_snapshot_discrepancy_report"
  post "/reports/run_lumber_order_snapshot_discrepancy_report", to: "reports#run_lumber_order_snapshot_discrepancy_report"
  get "/reports/show_company_year_over_year_report", to: "reports#show_company_year_over_year_report"
  post "/reports/run_company_year_over_year_report", to: "reports#run_company_year_over_year_report"
  get "/reports/show_customer_year_over_year_report", to: "reports#show_customer_year_over_year_report"
  post "/reports/run_customer_year_over_year_report", to: "reports#run_customer_year_over_year_report"
  get "/reports/show_us_billing_summary" => "reports#show_us_billing_summary"
  post "/reports/run_us_billing_summary" => "reports#run_us_billing_summary"
  get "/reports/show_puma_division_quarter_breakdown", to: "reports#show_puma_division_quarter_breakdown"
  post "/reports/run_puma_division_quarter_breakdown", to: "reports#run_puma_division_quarter_breakdown"

  resources :report_results, :only => [:index,:show] do
    get 'download', on: :member
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

  get "/login", to: "user_sessions#new", as: :login
  match "/logout", to: "user_sessions#destroy", as: :logout, via: [:get, :post, :delete]

  resources :user_sessions, :only => [:index,:new,:create,:destroy]

  resources :item_change_subscriptions

	resources :piece_sets

  resources :shipments do
    member do
      get 'history'
      get 'make_invoice'
      get :download
    end
    collection do
      post 'bulk_send_last_integration_file_to_test'
    end
    resources :shipment_lines do
      post :create_multiple, on: :collection
    end
	end

	resources :deliveries do
    member do
      get 'history'
    end
    resources :delivery_lines do
      post :create_multiple, on: :collection
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
      post 'bulk_send_last_integration_file_to_test'
    end
    member do
      get 'show_beta'
      get 'history'
      get :next_item
      get :previous_item
      patch :import_worksheet
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
      get 'send_to_sap'
      post 'close'
      post 'reopen'
      post 'accept'
      post 'unaccept'
    end
    collection do
      post :bulk_update
      post :bulk_update_fields
      post :bulk_send_to_sap
      post 'bulk_send_last_integration_file_to_test'
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
		get 'render_partial', on: :member
	end

  resources :users, :only => [:index] do
    resources :scheduled_reports, :only=>[:index]
    member do
      get 'history'
      post 'unlock', action: "unlock_user"
    end
    collection do 
      get 'find_by_email'
      get 'me'
      post "email_new_message"
      post "task_email"
      post "set_homepage"
      post 'run_as', action: "enable_run_as"
      post 'disable_run_as'
      post 'hide_message'
      post 'move_to_new_company'
    end
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
      get 'history'
    end
    resources :mailing_lists do
      collection do
        delete 'bulk_delete'
      end
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
        get :destroy_all, on: :collection
      end
    end
    resources :charge_categories, :only => [:index, :create, :destroy]
		get :shipping_address_list, on: :member
    get :attachment_archive_enabled, on: :collection
    resources :fiscal_months, :except=>[:show] do
      get 'download', :on=>:collection
      post 'upload', :on=>:collection
    end
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
      match 'update_search_criterions', via: [:put, :patch]
    end
    get 'show_angular', :on=>:collection
    resources :imported_file_downloads, :only=>[:index,:show]
  end
  match "/imported_files_results/:id" => "imported_files#results", :via=>:get
  match "/imported_files_results/:id/total_objects" => "imported_files#total_objects", :via => :get

  resources :search_setups do
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
      patch 'archive'
      put 'archive'
      patch 'restore'
      put 'restore'
    end
  end
  resources :survey_responses do
    member do
      get 'invite'
      patch 'archive'
      put 'archive'
      patch 'restore'
      put 'restore'
      post 'remind'
    end
    resources :corrective_action_plans, :only=>[:show,:create,:destroy,:update] do
      member do 
        post 'add_comment'
        patch 'activate'
        put 'activate'
        patch 'resolve'
        put 'resolve'
      end
    end
    resources :survey_response_logs, :only=>[:index]
  end
  resources :answers, only:[:update] do
    resources :answer_comments, only:[:create]
  end
  resources :corrective_issues, :only=>[:create,:update,:destroy] do
    member do 
      post 'update_resolution', action: :update_resolution_status
    end
  end

  resources :drawback_upload_files, :only=>[:index,:create] do
    collection do 
      patch 'process_j_crew_entries'
      put 'process_j_crew_entries'
    end
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

  resources :security_filings, :only=>[:index, :show] do
    collection do
      post 'bulk_send_last_integration_file_to_test'
    end
  end

  resources :sync_records do
    post 'resend', :on=>:member
  end

  resources :project_sets, only: [:show]

  match '/projects/:id/add_project_set/:project_set_name' => 'projects#add_project_set', via: :post
  match '/projects/:id/remove_project_set/:project_set_name' => 'projects#remove_project_set', via: :delete
  resources :projects, except: [:destroy] do
    resources :project_updates, only: [:update,:create]
    resources :project_deliverables, only: [:update,:create]
    member do 
      patch 'toggle_close'
      put 'toggle_close'
      patch 'toggle_on_hold'
      put 'toggle_on_hold'
    end
  end
  resources :project_deliverables, only: [:index]
  resources :schedulable_jobs, except: [:show] do
    member do 
      post 'run'
      post 'reset_run_flag'
    end
  end
  resources :intacct_errors, only: [:index] do
    # Gets are here to accomodate clearing directly from Excel exception report
    match 'clear_receivable', on: :member, via: [:get, :put]
    match 'clear_payable', on: :member, via: [:get, :put]
    match 'clear_check', on: :member, via: [:get, :put]
  end
  match "/intacct_errors/push_to_intacct" => "intacct_errors#push_to_intacct", via: :post

  resources :data_cross_references do
    get 'show', to: "data_cross_references#edit"
    get 'download', on: :collection
    post 'upload', on: :collection
  end

  resources :search_templates, only: [:index,:destroy]

  resources :milestone_notification_configs, only: [:index]

  resources :user_templates

  match "/vendor_portal" => "vendor_portal#index", via: :get

  resources :summary_statements, except: [:destroy] do
    get 'get_invoices', :on=>:member
  end

  resources :vfi_invoices, only: [:index, :show]

  resources :user_manuals, except: [:show] do
    get :download, on: :member
    get :for_referer, on: :collection
  end
  
  resources :business_validation_schedules, only: [:index]

  resources :custom_view_templates, except: [:show, :update]

  resources :state_toggle_buttons, except: [:show, :update, :destroy]

  resources :search_table_configs

  resources :trade_lanes, only: [:index]

  resources :product_vendor_assignments, only: [:index]


  resources :daily_statements, only: [:index, :show] do 
    member do 
      post 'reload'
    end
  end

  resources :monthly_statements, only: [:index, :show] do 
    member do 
      post 'reload'
    end
  end

  resources :one_time_alerts, except: [:show, :update, :destroy] do
    member do
      get 'log_index'
      post 'copy'
    end
    collection do
      get 'reference_fields_index'
      delete 'mass_delete'
      put 'mass_expire'
      put 'mass_enable'
    end
  end

  resources :special_tariff_cross_references, except: [:show] do
    post 'upload', on: :collection
    get 'download', on: :collection
  end

  # The following are routes for just some random stuff that doesn't have resourceful routes for some reason
  post "/textile/preview", to: "textile#preview"
  post "/tracker", to: "public_shipments#index"
  get "/index.html", to: "home#index"
  post "/register", to: "registrations#send_email"
  get "/settings", to: "settings#index", as: :settings
  get "/tools", to: "settings#tools", as: :tools
  get "/settings/system_summary", to: "settings#system_summary"
  post "/feedback", to: "feedback#send_feedback"
  get "/model_fields/find_by_module_type", to: "model_fields#find_by_module_type"
  
  match "/quick_search", to: "quick_search#show", via: [:post, :get]
  match '/quick_search/by_module/:module_type', to: 'quick_search#by_module', via: [:post, :get]

  get "/logo.png", to: "logo#logo"
  get "/comparepdf", to: "comparepdf#compare"
  get "/glossary/:core_module", to: "model_fields#glossary"

  get "/:recordable_type/:recordable_id/business_rule_snapshots", to: "business_rule_snapshots#index"

  #Jasmine test runner
  mount JasmineRails::Engine => '/specs' if defined?(JasmineRails) && !Rails.env.production?

  get "/dump_request", to: "application#dump_request"

  root :to => "home#index"
end
