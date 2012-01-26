OpenChain::Application.routes.draw do

  resources :entries, :only => [:index,:show]
  resources :broker_invoices, :only => [:index,:show]

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
  resources :password_resets, :only => [:new, :edit, :create, :update]
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

  #custom features
  resources :custom_files, :only => :show
  match "/custom_features" => "custom_features#index", :via => :get
  match "/custom_features/msl_plus" => "custom_features#msl_plus_index", :via => :get
  match "/custom_features/msl_plus/:id" => "custom_features#msl_plus_show", :via => :get 
  match "/custom_features/msl_plus/upload" => "custom_features#msl_plus_upload", :via => :post
  match "/custom_features/msl_plus/:id/email" => "custom_features#msl_plus_show_email", :via => :get
  match "/custom_features/msl_plus/:id/email" => "custom_features#msl_plus_send_email", :via => :post


  #reports
  match "/reports" => "reports#index", :via => :get
  match "/reports/show_tariff_comparison" =>"reports#show_tariff_comparison", :via => :get
  match "/reports/run_tariff_comparison" => "reports#run_tariff_comparison", :via => :post
  match "/reports/show_stale_tariffs" => "reports#show_stale_tariffs", :via => :get
  match "/reports/run_stale_tariffs" => "reports#run_stale_tariffs", :via => :post
  match "/reports/show_shoes_for_crews_entry_breakdown" => "reports#show_shoes_for_crews_entry_breakdown", :via=>:get
  match "/reports/run_shoes_for_crews_entry_breakdown" => "reports#run_shoes_for_crews_entry_breakdown", :via=>:post
  match "/reports/show_poa_expirations" => "reports#show_poa_expirations", :via => :get
  match "/reports/run_poa_expirations" => "reports#run_poa_expirations", :via => :get

  resources :report_results, :only => [:index,:show] do 
    get 'download', :on => :member
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
      post 'bulk_auto_classify'
      post 'bulk_instant_classify'
      post 'show_bulk_instant_classify'
    end
    member do
      get 'history'
      get 'classify'
      post :auto_classify 
      put  :auto_classify
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
    end
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
  
  resources :error_log_entries, :only => [:index, :show]
  root :to => "dashboard_widgets#index"
end
