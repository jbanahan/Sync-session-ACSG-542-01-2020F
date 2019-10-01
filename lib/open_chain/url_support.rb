# Make Rails URL helpers available from anywhere

module OpenChain; module UrlSupport

  def show_url obj: nil, klass: nil, id: nil
    raise "Must be called with either an object, or a class and an id." unless obj || (klass && id) 
    helper = "#{obj ? obj.class.name.underscore : klass.name.underscore }_url"
    Rails.application.routes.url_helpers.public_send(helper, obj || id)
  end

  def validation_results_url obj: nil, klass: nil, id: nil
    raise "Must be called with either an object, or a class and an id." unless obj || (klass && id) 
    helper = "validation_results_#{obj ? obj.class.name.underscore : klass.name.underscore}_url"
    if Rails.application.routes.url_helpers.respond_to? helper
      Rails.application.routes.url_helpers.public_send(helper, obj || id)
    else
      ""
    end
  end

end; end
