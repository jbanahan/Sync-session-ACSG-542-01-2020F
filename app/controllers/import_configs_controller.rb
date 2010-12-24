class ImportConfigsController < ApplicationController
  # GET /import_configs
  # GET /import_configs.xml
  def index
    @import_configs = ImportConfig.all

    respond_to do |format|
      format.html { render :layout => 'one_col' }
      format.xml  { render :xml => @import_configs }
    end
  end

  # GET /import_configs/new
  # GET /import_configs/new.xml
  def new
    @import_config = ImportConfig.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @import_config }
    end
  end

  # GET /import_configs/1/edit
  def edit
    @import_config = ImportConfig.find(params[:id])
    #inefficent - probably doesn't matter in the long run
    @mapped_fields = []
    @unmapped_fields = []
    ImportConfig.sorted_model_fields(@import_config.model_type.intern).each do |mf|
      found = false
      unless found
        @import_config.import_config_mappings.each do |mapped|
          if mf.uid == mapped.model_field_uid
            found = true
          end
        end
      end
      if found
        @mapped_fields << mf
      else
        @unmapped_fields << mf
      end
    end
  end

  # POST /import_configs
  # POST /import_configs.xml
  def create
    @import_config = ImportConfig.new(params[:import_config])

    respond_to do |format|
      if @import_config.save
        add_flash :notices, "File Format saved."
        format.html { redirect_to edit_import_config_path(@import_config) }
        format.xml  { render :xml => @import_config, :status => :created, :location => @import_config }
      else
        errors_to_flash @import_config
        format.html { render :action => "new" }
        format.xml  { render :xml => @import_config.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /import_configs/1
  # PUT /import_configs/1.xml
  def update
    @import_config = ImportConfig.find(params[:id])
    old_mappings = []
    @import_config.import_config_mappings.each do |m|
      old_mappings << m.clone
    end
    @import_config.import_config_mappings.delete_all
    respond_to do |format|
      if @import_config.update_attributes(params[:import_config])
        add_flash :notices, "File Format saved."
        format.html { redirect_to edit_import_config_path(@import_config) }
        format.xml  { head :ok }
      else
        errors_to_flash @import_config
        #put back old mappings
        old_mappings.each do |om|
          om.save
        end
        format.html { redirect_to edit_import_config_path(@import_config) }
        format.xml  { render :xml => @import_config.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /import_configs/1
  # DELETE /import_configs/1.xml
  def destroy
    @import_config = ImportConfig.find(params[:id])
    @import_config.destroy

    respond_to do |format|
      format.html { redirect_to(import_configs_url) }
      format.xml  { head :ok }
    end
  end
end
