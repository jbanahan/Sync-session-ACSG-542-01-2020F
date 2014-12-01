class SearchTemplatesController < ApplicationController
  def index
    admin_secure {
      render
    }
  end
end