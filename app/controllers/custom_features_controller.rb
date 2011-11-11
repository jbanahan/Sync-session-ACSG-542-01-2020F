class CustomFeaturesController < ApplicationController
  MSL_PLUS = 'OpenChain::CustomHandler::PoloMslPlusHandler'
  def index
    render :layout=>'one_col'
  end
  def msl_plus_index
    action_secure(current_user.edit_products?,Product,{:verb=>"view",:module_name=>"MSL+ Uploads",:lock_check=>false}) {
      @files = CustomFile.where(:file_type=>MSL_PLUS).order('created_at DESC').paginate(:per_page=>20,:page => params[:page])
      render :layout => 'one_col'
    }
  end
  def msl_plus_show
    f = CustomFile.find params[:id]
    action_secure(f.can_view?(current_user),f,{:verb=>"view",:module_name=>"MSL+ File",:lock_check=>false}) {
      @file = f
      @search_run = @file.search_runs.find_or_create_by_user_id(current_user.id)
      @search_run.update_attributes(:last_accessed=>Time.now)
      @products = @file.linked_products.paginate(:per_page=>20,:page => params[:page])
      fields = ['prod_uid','prod_name']
      @columns = fields.each_with_index.collect {|mfuid,i| SearchColumn.new(:model_field_uid=>mfuid,:rank=>i)}
      @bulk_actions = CoreModule::PRODUCT.bulk_actions current_user
    }
  end
  def msl_plus_upload
    f = CustomFile.new(:file_type=>MSL_PLUS,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"MSL+ File",:lock_check=>false}) {
      if f.save
        f.delay.process(current_user)
        add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
      else
        errors_to_flash f
      end
      redirect_to '/custom_features/msl_plus'
    }
  end
  def msl_plus_show_email
    f = CustomFile.find params[:id]
    action_secure(f.can_view?(current_user),f,{:verb=>"view",:module_name=>"MSL+ File",:lock_check=>false}) {
      @file = f
    }
  end
  def msl_plus_send_email
    f = CustomFile.find params[:id] 
    action_secure(f.can_view?(current_user),f,{:verb=>"view",:module_name=>"MSL+ File",:lock_check=>false}) {
      f.delay.email_updated_file current_user, params[:to], (params[:copy_me] ? current_user.email : ""), params[:subject], params[:body]
      add_flash :notices, "Your file is being processed and will be emailed soon."
      redirect_to "/custom_features/msl_plus/#{f.id}"
    }
  end
end
