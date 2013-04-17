module OpenChain
  module NextPreviousSupport
    def next_item
      id = result_cache.next params[:id].to_i
      if id.nil?
        add_flash :errors, "Next object could not be found."
        redirect_to request.referrer
      else
        redirect_to root_class.find id
      end
    end

    def previous_item
      id = result_cache.previous params[:id].to_i
      if id.nil?
        add_flash :errors, "Previous object could not be found."
        redirect_to request.referrer
      else
        redirect_to root_class.find id
      end
    end

    private
    def result_cache
      sr = search_run
      p = sr.parent
      rc = p.result_cache
      rc = p.build_result_cache(:page=>1,:per_page=>100) if rc.nil?
      rc
    end
  end
end
