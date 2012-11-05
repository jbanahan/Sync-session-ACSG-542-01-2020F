OpenChain::Application.routes.draw do
  resources :delayed_jobs, :only => [:destroy]
  resources :ftp_sessions, :only => [:index, :show] do
    member do
      get 'download'
    end
  end

  match "/entries/bi" => "entries#bi_three_month", :via=>:get
  match "/entries/bi/three_month" => "entries#bi_three_month", :via=>:get
  match "/entries/bi/three_month_hts" => "entries#bi_three_month_hts", :via=>:get
  resources :entries, :only => [:index,:show] do
    get 'reprocess', :on=>:collection
    post 'bulk_get_images', :on=>:collection
    get 'get_images', :on=>:member
    resources :broker_invoices, :only=>[:create]
  end
  
  resources :commercial_invoices, :only => [:show]
  resources :broker_invoices, :only => [:index,:show]
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
  resources :entity_snapshots, :only => [:show]
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
  resources :password_resets, :only => [:new, :edit, :create, :update] do
    member do
      get 'forced'
    end
  end
  resources :dashboard_widgets, :only => [:index] do
    collection do
      get 'edit'
      post 'save'
    end
  end
  resources :master_setups do
    collection do
      get 'show_system_message'
      post 'set_system_message'
      post 'upgrade'
    end
  end
  resources :upgrade_logs, :only=>[:show]
  resources :attachment_types

  match "/official_tariffs/auto_classify/:hts" => "official_tariffs#auto_classify"
  resources :official_tariffs, :only=>[:index,:show] do
    get 'find', :on => :collection
    get 'find_schedule_b', :on => :collection
    get 'schedule_b_matches', :on => :collection
  end
  resources :official_tariff_meta_data, :only=>[:create,:update]

  resources :status_rules
  resources :attachments do
    get 'download', :on => :member
  end
  resources :comments do
    post 'send_email', :on => :member
  end

  match "/textile/preview" => "textile#preview"
  match "/tracker" => "public_shipments#index"
	match "/index.html" => "dashboard_widgets#index"
  match "/shipments/:id/add_sets" => "shipments#add_sets"
  match "/shipments/:id/receive_inventory" => "shipments#receive_inventory"
  match "/shipments/:id/undo_receive" => "shipments#undo_receive"
  match "/deliveries/:id/add_sets" => "deliveries#add_sets"
  match "/login" => "user_sessions#new", :as => :login
  match "/logout" => "user_sessions#destroy", :as => :logout
  match "/settings" => "settings#index", :as => :settings
  match "/tools" => "settings#tools", :as => :tools
  match "/active_users" => "settings#active_users", :as=>:active_users
  match "/adjust_inventory" => "products#adjust_inventory"
  match "/feedback" => "feedback#send_feedback"
  match "/model_fields/find_by_module_type" => "model_fields#find_by_module_type"
  match "/help" => "chain_help#index"
  match "/accept_tos" => "users#accept_tos"
  match "/show_tos" => "users#show_tos"
  match "/public_fields" => "public_fields#index"
  match "/public_fields/save" => "public_fields#save", :via => :post
  match "/users/email_new_message" => "users#email_new_message"
  match "/quick_search" => "quick_search#show"
  match "/quick_search/module_result" => "quick_search#module_result"
  match "/enable_run_as" => "users#enable_run_as"
  match "/disable_run_as" => "users#disable_run_as"

  match "email_attachments/:id" => "email_attachments#show", :as => :email_attachments_show, :via => :get
  match "email_attachments/:id/download" => "email_attachments#download", :as => :email_attachments_download, :via => :post

  #custom features
  resources :custom_files, :only => :show
  match "/custom_features" => "custom_features#index", :via => :get
  match "/custom_features/msl_plus" => "custom_features#msl_plus_index", :via => :get
  match "/custom_features/msl_plus/:id" => "custom_features#msl_plus_show", :via => :get 
  match "/custom_features/msl_plus/upload" => "custom_features#msl_plus_upload", :via => :post
  match "/custom_features/msl_plus/:id/email" => "custom_features#msl_plus_show_email", :via => :get
  match "/custom_features/msl_plus/:id/email" => "custom_features#msl_plus_send_email", :via => :post
  match "/custom_features/msl_plus/:id/filter" => "custom_features#msl_plus_filter", :via=>:post
  match "/custom_features/csm_sync" => "custom_features#csm_sync_index", :via=>:get
  match "/custom_features/csm_sync/upload" => "custom_features#csm_sync_upload", :via => :post
  match "/custom_features/csm_sync/:id/download" => "custom_features#csm_sync_download", :via => :get
  match "/custom_features/csm_sync/:id/reprocess" => "custom_features#csm_sync_reprocess", :via=>:get
  match "/custom_features/polo_canada" => "custom_features#polo_efocus_index", :via=>:get
  match "/custom_features/polo_canada/upload" => "custom_features#polo_efocus_upload", :via => :post
  match "/custom_features/polo_canada/:id/download" => "custom_features#polo_efocus_download", :via => :get

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
      get 'read_all'
      get 'message_count'
    end
  end

  resources :user_sessions

  resources :item_change_subscriptions
  
	resources :piece_sets

  resources :shipments do
    collection do
      get 'show_next'
      get 'show_previous'
    end
    member do
      get 'history'
      get 'make_invoice'
      put 'generate_invoice'
    end
    resources :shipment_lines do
      post :create_multiple, :on => :collection
    end
	end
	
	resources :deliveries do
    collection do
      get 'show_next'
      get 'show_previous'
    end
    member do
      get 'history'
    end
    resources :delivery_lines do
      post :create_multiple, :on => :collection
    end
	end

  resources :products do
    collection do
      get 'show_next'
      get 'show_previous'
      post 'bulk_edit'
      post 'bulk_update'
      post 'bulk_classify'
      post 'bulk_update_classifications'
      post 'bulk_instant_classify'
      post 'show_bulk_instant_classify'
    end
    member do
      get 'history'
      get 'classify'
      put :import_worksheet 
    end
    post :import_new_worksheet, :on=>:new
  end

  resources :orders do
    collection do
      get 'show_next'
      get 'show_previous'
      get 'all_open'
    end
    member do
      get 'history'
    end
		resources :order_lines
	end
	
  resources :sales_orders do
    collection do
      get 'show_next'
      get 'show_previous'
      get 'all_open'
    end
    member do
      get 'history'
    end
    resources :sales_order_lines
  end

  resources :countries

	resources :addresses do
		get 'render_partial', :on => :member
	end

  resources :users, :only => [:index]

  resources :companies do
    member do
      get 'show_children'
      post 'update_children'
    end
		resources :addresses
		resources :divisions
    resources :power_of_attorneys, :only => [:index, :new, :create, :destroy] do
      member do
        get 'download'
      end
    end
    
		resources :users do
		  get :disable, :on => :member
		  get :enable, :on => :member
      resources :debug_records, :only => [:index, :show] do
        get :destroy_all, :on => :collection
      end
		end
		get :shipping_address_list, :on => :member
  end
  
  resources :file_import_results, :only => [:show] do
    member do
      get 'messages'
    end
  end
  resources :imported_files, :only => [:index, :show, :destroy] do
    member do
      get 'preview'
      get 'show_email_file'
      post 'email_file'
      get 'download'
      post 'download_items'
      get 'process'
      post 'filter'
    end
    resources :imported_file_downloads, :only=>[:index,:show]
  end

  resources :search_setups do
    collection do
      post 'sticky_open'
      post 'sticky_close'
    end
    member do
      get 'copy'
      get 'give'
    end
    resources :imported_files, :only => [:new, :create, :show] do
      member do 
        get 'download'
        get 'process_file'
      end
    end 
  end
  
  resources :surveys do
    member do 
      get 'show_assign'
      get 'toggle_subscription'
      post 'assign'
      get 'copy'
    end
  end
  resources :survey_responses do
    get 'invite', :on=>:member
    resources :survey_response_logs, :only=>[:index]
  end
  resources :drawback_upload_files, :only=>[:index,:create]
  resources :error_log_entries, :only => [:index, :show]
  resources :charge_codes, :only => [:index, :update, :create, :destroy]
  root :to => "dashboard_widgets#index"
end
