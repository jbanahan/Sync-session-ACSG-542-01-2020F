class AttachmentTypesController < ApplicationController
  # GET /attachment_types
  # GET /attachment_types.xml
  def index
    admin_secure {
      @attachment_types = AttachmentType.all
      respond_to do |format|
        format.html {render :layout => 'one_col'}# index.html.erb
      end
    }
  end

  # POST /attachment_types
  # POST /attachment_types.xml
  def create
    admin_secure {
      @attachment_type = AttachmentType.new(params[:attachment_type])
      if @attachment_type.save
        add_flash :notices, "Attachment Type \"#{@attachment_type.name}\" added successfully."
      else
        errors_to_flash @attachment_type
      end
      respond_to do |format|
        format.html { redirect_to AttachmentType }
      end
    }
  end

  # DELETE /attachment_types/1
  # DELETE /attachment_types/1.xml
  def destroy
    admin_secure {
      @attachment_type = AttachmentType.find(params[:id])
      if @attachment_type.destroy
        add_flash :notices, "Attachment Type \"#{@attachment_type.name} deleted successfully."
      else
        errors_to_flash @attachment_type
      end
      respond_to do |format|
        format.html { redirect_to AttachmentType }
      end
    }
  end
end
