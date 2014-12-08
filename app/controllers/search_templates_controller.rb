class SearchTemplatesController < ApplicationController
  def index
    admin_secure {
      render
    }
  end

  def destroy
    admin_secure {
      st = SearchTemplate.find(params[:id])
      if st.destroy
        add_flash :notices, "Template deleted."
      else
        add_flash :errors, "Template delete failed. #{st.errors.full_messages}"
      end
      redirect_to SearchTemplate
    }
  end
end