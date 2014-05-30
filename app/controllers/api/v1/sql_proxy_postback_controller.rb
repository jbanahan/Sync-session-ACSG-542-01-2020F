module Api; module V1; class SqlProxyPostbackController < ApiController

  before_filter :require_admin

  def extract_results params, options = {}
    options = {null_response: {"OK" => ""}, yield_nil_results: false}.merge options
    # Params may be nil in cases where a query didn't return any results (rails munges JSON like {'results':[]} into {'results':nil}).
    # So don't return an error if results is there but it's null, just don't yield.
    if (params.include?("results") && params[:results].nil?) || (params[:results] && params[:results].respond_to?(:each))
      if params[:results] || options[:yield_nil_results]
        yield params[:results], params[:context]
      else
        render json: options[:null_response]
      end
    else
      render_error "Bad Request", :bad_request
    end
  end

  private

    def require_admin
      render_forbidden unless User.current.admin?
    end

end; end; end;