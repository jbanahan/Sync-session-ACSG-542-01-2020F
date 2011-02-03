class AttachmentTypesController < ApplicationController
  # GET /attachment_types
  # GET /attachment_types.xml
  def index
    admin_secure {
      @attachment_types = AttachmentType.all
  
      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => @attachment_types }
      end
    }
  end

  # GET /attachment_types/1
  # GET /attachment_types/1.xml
  def show
    @attachment_type = AttachmentType.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @attachment_type }
    end
  end

  # GET /attachment_types/new
  # GET /attachment_types/new.xml
  def new
    @attachment_type = AttachmentType.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @attachment_type }
    end
  end

  # GET /attachment_types/1/edit
  def edit
    @attachment_type = AttachmentType.find(params[:id])
  end

  # POST /attachment_types
  # POST /attachment_types.xml
  def create
    @attachment_type = AttachmentType.new(params[:attachment_type])

    respond_to do |format|
      if @attachment_type.save
        format.html { redirect_to(@attachment_type, :notice => 'Attachment type was successfully created.') }
        format.xml  { render :xml => @attachment_type, :status => :created, :location => @attachment_type }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @attachment_type.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /attachment_types/1
  # PUT /attachment_types/1.xml
  def update
    @attachment_type = AttachmentType.find(params[:id])

    respond_to do |format|
      if @attachment_type.update_attributes(params[:attachment_type])
        format.html { redirect_to(@attachment_type, :notice => 'Attachment type was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @attachment_type.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /attachment_types/1
  # DELETE /attachment_types/1.xml
  def destroy
    @attachment_type = AttachmentType.find(params[:id])
    @attachment_type.destroy

    respond_to do |format|
      format.html { redirect_to(attachment_types_url) }
      format.xml  { head :ok }
    end
  end
end
