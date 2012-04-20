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
      @products = @file.linked_products.where("1=1")
      @search_run.search_criterions.each {|sc| @products = sc.apply @products}
      @products = @products.paginate(:per_page=>20,:page => params[:page])
      fields = ['prod_uid',
        CustomDefinition.find_by_label("Board Number").model_field_uid,
        CustomDefinition.find_by_label("GCC Description").model_field_uid,
        CustomDefinition.find_by_label("MSL+ HTS Description").model_field_uid,
        CustomDefinition.find_by_label("Fiber Content %s").model_field_uid,
        'prod_name']
      @columns = fields.each_with_index.collect {|mfuid,i| SearchColumn.new(:model_field_uid=>mfuid,:rank=>i)}
      hts1_model_field = ModelField.new(100000,:custom_prod_us_hts1,CoreModule::PRODUCT,:hts_1,{
        :export_lambda=>lambda {|p| 
          us_class = p.classifications.find_by_country_id(Country.find_by_iso_code("US").id)
          return "" unless us_class
          tr = us_class.tariff_records.first
          return "" unless tr
          return tr.hts_1
        },
        :label_override => "US HTS 1"
      })
      hts1_column = SearchColumn.new
      def hts1_column.model_field=(f); @msl_plus_custom_mf = f; end;
      def hts1_column.model_field; @msl_plus_custom_mf; end;
      hts1_column.model_field= hts1_model_field
      @columns.insert -2, hts1_column
      @bulk_actions = CoreModule::PRODUCT.bulk_actions current_user
    }
  end
  def msl_plus_filter
    f = CustomFile.find params[:id]
    action_secure(f.can_view?(current_user),f,{:verb=>"filter",:module_name=>"MSL+ File",:lock_check=>false}) {
      @file = f
      @search_run = @file.search_runs.find_or_create_by_user_id(current_user.id)
      search_params = (params[:search_run] && params[:search_run][:search_criterions_attributes]) ? params[:search_run][:search_criterions_attributes] : {}
      @search_run.search_criterions.destroy_all
      search_params.each do |k,p|
        p.delete "_destroy"
        @search_run.search_criterions.create(p)
      end
      redirect_to "/custom_features/msl_plus/#{f.id}"
    }
  end
  def msl_plus_upload
    f = CustomFile.new(:file_type=>MSL_PLUS,:uploaded_by=>current_user,:attached=>params[:attached])
    action_secure(f.can_view?(current_user),f,{:verb=>"upload",:module_name=>"MSL+ File",:lock_check=>false}) {
      if params[:attached].nil?
        add_flash :errors, "You must select a file to upload." 
      elsif f.save
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
