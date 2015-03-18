class ProductGroupsController < ApplicationController
  around_filter :admin_secure
  def index
  end

  def create
    pg = ProductGroup.new params[:product_group]
    pg.save
    if pg.errors.full_messages.blank?
      add_flash :notices, "Product Group created."
    else
      add_flash :errors, pg.errors.full_messages.join(', ')
    end
    redirect_to product_groups_path
  end
  def destroy
    pg = ProductGroup.find params[:id]
    pg.destroy
    if pg.errors.full_messages.blank?
      add_flash :notices, "Product Group deleted."
    else
      add_flash :errors, pg.errors.full_messages.join(', ')
    end
    redirect_to product_groups_path
  end
end
