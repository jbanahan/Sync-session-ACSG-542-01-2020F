module UserManualHelper

  def url um
    if um.document_url?
      um.document_url
    elsif um.wistia_code?
      nil
    else
      Rails.application.routes.url_helpers.download_user_manual_url(um, host: MasterSetup.get.request_host, 
                                                                        protocol: (Rails.env.development? ? "http" : "https"))
    end
  end

  def last_update um
    um.updated_at.to_date.strftime("%m-%d-%Y")
  end

end
