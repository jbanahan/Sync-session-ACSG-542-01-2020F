class RegionsController < ApplicationController
  before_filter :secure
  def index
    @regions = Region.all
  end

  def create
    r = Region.create!(params[:region])
    redirect_to regions_path
  end

  def destroy
    r = Region.destroy(params[:id])
    redirect_to regions_path
  end

  def update
    r = Region.find(params[:id]).update_attributes(params[:region])
    redirect_to regions_path
  end

  def add_country
    r = Region.find(params[:id])
    c = Country.find(params[:country_id])
    r.countries << c unless r.countries.find_by_id(c.id)
    redirect_to regions_path
  end

  def remove_country
    r = Region.find(params[:id])
    c = Country.find_by_id(params[:country_id])
    r.countries.delete(c)
    redirect_to regions_path
  end

  private
  def secure
    if current_user.admin?
      return true
    else
      add_flash :errors, "You must be an admin to access this page."
      redirect_to request.referrer
      return false
    end
  end
end
