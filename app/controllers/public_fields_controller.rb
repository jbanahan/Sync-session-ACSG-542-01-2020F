class PublicFieldsController < ApplicationController

  def set_page_title
    @page_title = 'Tools'
  end

  def index
    admin_secure do
      @model_fields = CoreModule::ENTRY.model_fields.values
    end
  end

  def save
    admin_secure do
      PublicField.transaction do
        PublicField.destroy_all # start over every time
        field_hash = params[:public_fields].to_hash.with_indifferent_access
        field_hash.each do |_k, v|
          PublicField.create!(v) if v[:model_field_uid]
        end
        add_flash :notices, "Your changes have been saved."
        redirect_to '/public_fields'
      end
    end
  end
end
