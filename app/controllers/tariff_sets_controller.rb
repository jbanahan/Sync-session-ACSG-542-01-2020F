class TariffSetsController < ApplicationController

  def index 
    t = params[:country_id] ? TariffSet.where(:country_id=>params[:country_id]) : TariffSet.where(true)
    t = t.includes(:country).order("countries.name ASC, tariff_sets.label DESC").to_a
    respond_to do |format|
      format.json {render :json => t.to_json}
      format.html {@tariff_sets = t}#index.html.erb
    end 
  end

  # Activate a tariff set
  def activate
    if current_user.admin?
      ts = TariffSet.find params[:id]
      ts.delay.activate current_user
      add_flash :notices, "Tariff Set #{ts.label} is being activated in the background.  You'll receive a system message when it is complete."
    else
      add_flash :errors, "You must be an administrator to activate tariffs."
    end
    redirect_to TariffSet
  end

  # Load a new tariff set from an s3 path
  def load
    if current_user.sys_admin?
      country = Country.find params['country_id'] 
      TariffLoader.delay.process_s3 params['path'], country, params['label'], (params['activate'] ? true : false), current_user
      add_flash :notices, "Tariff Set is loading in the background. You'll receive a system message when it's done."
    else
      add_flash :errors, "Only system administrators can load tariff sets."
    end
    redirect_to TariffSet 
  end
end
