OpenChain::Application.routes.draw do

  resources :password_resets, :only => [:new, :edit, :create, :update]
  resources :dashboard_widgets, :only => [:index] do
    collection do
      get 'edit'
      post 'save'
    end
  end
  resources :master_setups
  resources :attachment_types

  #get rid of this one eventually
  resources :official_tariffs

  resources :status_rules
  resources :attachments do
    get 'download', :on => :member
  end
  resources :comments do
    post 'send_email', :on => :member
  end

  match "/tracker" => "public_shipments#index"
	match "/index.html" => "dashboard_widgets/index"
  match "/shipments/:id/add_sets" => "shipments#add_sets"
  match "/shipments/:id/receive_inventory" => "shipments#receive_inventory"
  match "/shipments/:id/undo_receive" => "shipments#undo_receive"
  match "/deliveries/:id/add_sets" => "deliveries#add_sets"
  match "/login" => "user_sessions#new", :as => :login
  match "/logout" => "user_sessions#destroy", :as => :logout
  match "/settings" => "settings#index", :as => :settings
  match "/adjust_inventory" => "products#adjust_inventory"
  match "/feedback" => "feedback#send_feedback"
  match "/model_fields/find_by_module_type" => "model_fields#find_by_module_type"
  match "/search_setups/:id/copy" => "search_setups#copy"
  match "/help" => "chain_help#index"
  match "/accept_tos" => "users#accept_tos"
  match "/show_tos" => "users#show_tos"
  match "/public_fields" => "public_fields#index"
  match "/public_fields/save" => "public_fields#save", :via => :post

  resources :custom_definitions

  resources :worksheet_configs
  
  resources :messages, :only => [:index, :destroy] do
    member do
      get 'read'
    end
    collection do
      get 'read_all'
    end
  end

  resources :user_sessions

  resources :item_change_subscriptions
  
	resources :piece_sets

  resources :shipments do
    resources :shipment_lines do
      post :create_multiple, :on => :collection
    end
	end
	
	resources :deliveries do
    resources :delivery_lines do
      post :create_multiple, :on => :collection
    end
	end

  resources :products do
    get 'classify', :on=>:member
    post :auto_classify, :on=>:member
    put  :auto_classify, :on=>:member
    post :import_new_worksheet, :on=>:new
    put :import_worksheet, :on=>:member
  end

  resources :orders do
    get 'all_open', :on=>:collection
		resources :order_lines
	end
	
  resources :sales_orders do
    get 'all_open', :on=>:collection
    resources :sales_order_lines
  end

  resources :countries

	resources :addresses do
		get 'render_partial', :on => :member
	end

  resources :companies do
		resources :addresses
		resources :divisions
		resources :users do
		  get :disable, :on => :member
		  get :enable, :on => :member
      resources :debug_records, :only => [:index, :show] do
        get :destroy_all, :on => :collection
      end
		end
		get :shipping_address_list, :on => :member
  end
  
  resources :search_setups do
    resources :imported_files, :only => [:new, :create, :show] do
      member do 
        get 'download'
        get 'process_file'
      end
    end 
  end
  
  root :to => "dashboard_widgets#index"
end
