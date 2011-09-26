class LinkableAttachmentImportRulesController < ApplicationController
  def index
    admin_secure {
      @rules = LinkableAttachmentImportRule.all
    }
  end

  def show
    redirect_to edit_linkable_attachment_import_rule_path(LinkableAttachmentImportRule.find(params[:id]))
  end
  def edit
    admin_secure {
      @rule = LinkableAttachmentImportRule.find(params[:id]) 
    }
  end
  def destroy 
    admin_secure {
      r = LinkableAttachmentImportRule.find(params[:id]) 
      add_flash :notices, "Rule deleted successfully." if r.destroy
      errors_to_flash r
      redirect_to linkable_attachment_import_rules_path
    }
  end
  def update 
    admin_secure {
      r = LinkableAttachmentImportRule.find(params[:id]) 
      add_flash :notices, "Rule updated successfully." if r.update_attributes(params[:linkable_attachment_import_rule])
      errors_to_flash r
      redirect_to edit_linkable_attachment_import_rule_path r
    }
  end
  def create
    admin_secure {
      r = LinkableAttachmentImportRule.create(params[:linkable_attachment_import_rule])
      if r.errors.empty?
        add_flash :notices, "Rule created successfully."
        redirect_to edit_linkable_attachment_import_rule_path r
      else
        @rule = r
        errors_to_flash r, :now=>true
        render :new
      end
    }
  end
  def new
    admin_secure {
      @rule = LinkableAttachmentImportRule.new
    }
  end
end
