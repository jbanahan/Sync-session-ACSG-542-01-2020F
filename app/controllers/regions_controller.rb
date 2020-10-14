class RegionsController < ApplicationController
  before_action :secure
  def set_page_title
    @page_title = 'Tools'
  end

  def index
    @regions = Region.by_name.all
  end

  def create
    Region.create!(permitted_params(params))
    redirect_to regions_path
  end

  def destroy
    Region.destroy(params[:id])
    redirect_to regions_path
  end

  def update
    Region.find(params[:id]).update(permitted_params(params))
    redirect_to regions_path
  end

  def add_country
    r = Region.find(params[:id])
    c = Country.find(params[:country_id])
    r.countries << c unless r.countries.find_by(id: c.id)
    redirect_to regions_path
  end

  def remove_country
    r = Region.find(params[:id])
    c = Country.find_by(id: params[:country_id])
    r.countries.delete(c)
    redirect_to regions_path
  end

  private

  def secure
    if current_user.admin?
      true
    else
      add_flash :errors, "You must be an admin to access this page."
      redirect_to request.referer
      false
    end
  end

  def permitted_params(params)
    params.require(:region).permit(:name)
  end
end
