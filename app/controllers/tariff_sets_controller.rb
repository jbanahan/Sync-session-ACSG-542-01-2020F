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
      run_at = Time.zone.now
      unless params[:date].blank?
        run_at = make_date_time params[:date]
      end
      
      # Verify that the file the S3 path points to starts w/ the countrie's ISO code...this helps to ensure we don't accidently load a set to a wrong
      # country.
      if (File.basename(params['path']).upcase.starts_with?(country.iso_code) && params['label'].to_s.upcase.starts_with?(country.iso_code)) || (country.european_union && File.basename(params['path']).upcase.starts_with?('EU') && params['label'].to_s.upcase.starts_with?('EU'))
        TariffLoader.delay(:run_at => run_at).process_s3 params['path'], country, params['label'], (params['activate'] ? true : false), current_user
        add_flash :notices, "Tariff Set is loading in the background. You'll receive a system message when it's done."
      else
        add_flash :errors, "Tariff Set filename and Label must begin with the Country you are loading's ISO Code."
      end
    else
      add_flash :errors, "Only system administrators can load tariff sets."
    end
    redirect_to TariffSet 
  end

  private 
    def make_date_time d
      # Expect the standard rails date time components: :year, :month, :day, :hour, :minute
      return Time.zone.parse "#{d[:year]}-#{d[:month]}-#{d[:day]} #{d[:hour]}:#{d[:minute]}"
    end
end
