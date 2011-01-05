OpenChain::Application.routes.draw do


	match "/index.html" => "dashboard#show_main"
  match "/shipments/:id/add_sets" => "shipments#add_sets"
  match "/shipments/:id/receive_inventory" => "shipments#receive_inventory"
  match "/shipments/:id/undo_receive" => "shipments#undo_receive"
  match "/deliveries/:id/add_sets" => "deliveries#add_sets"
  match "/login" => "user_sessions#new", :as => :login
  match "/logout" => "user_sessions#destroy", :as => :logout
  match "/settings" => "settings#index", :as => :settings
  match "/adjust_inventory" => "products#adjust_inventory"

  resources :import_configs
  resources :imported_files, :only => [:new, :create, :show] do
    member do 
      get 'download'
      get 'process_file'
    end
  end 

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
		get 'unpacked_order_lines', :on => :member
	end
	
	resources :deliveries do
	  get 'unpacked_order_lines', :on => :member
	end

  resources :products

  resources :orders do
		resources :order_lines
	end
	
  resources :sales_orders do
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
		end
		get :shipping_address_list, :on => :member
  end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
   root :to => "dashboard#show_main"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
