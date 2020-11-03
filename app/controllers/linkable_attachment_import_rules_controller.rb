class LinkableAttachmentImportRulesController < ApplicationController
  def set_page_title
    @page_title = 'Tools'
  end

  def index
    admin_secure do
      @rules = LinkableAttachmentImportRule.all
    end
  end

  def show
    redirect_to edit_linkable_attachment_import_rule_path(LinkableAttachmentImportRule.find(params[:id]))
  end

  def edit
    admin_secure do
      @rule = LinkableAttachmentImportRule.find(params[:id])
    end
  end

  def destroy
    admin_secure do
      r = LinkableAttachmentImportRule.find(params[:id])
      add_flash :notices, "Rule deleted successfully." if r.destroy
      errors_to_flash r
      redirect_to linkable_attachment_import_rules_path
    end
  end

  def update
    admin_secure do
      r = LinkableAttachmentImportRule.find(params[:id])
      add_flash :notices, "Rule updated successfully." if r.update(permitted_params(params))
      errors_to_flash r
      redirect_to edit_linkable_attachment_import_rule_path r
    end
  end

  def create
    admin_secure do
      r = LinkableAttachmentImportRule.create(permitted_params(params))
      if r.errors.empty?
        add_flash :notices, "Rule created successfully."
        redirect_to edit_linkable_attachment_import_rule_path r
      else
        @rule = r
        errors_to_flash r, now: true
        render :new
      end
    end
  end

  def new
    admin_secure do
      @rule = LinkableAttachmentImportRule.new
    end
  end

  private

    def permitted_params(params)
      params.require(:linkable_attachment_import_rule).permit(:model_field_uid, :path)
    end
end
