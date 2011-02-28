class ChainHelpController < ApplicationController
  def index
   pg = params[:page].blank? ? 'index' : params[:page]
   render pg, :layout=>'help' unless pg.blank?
  end
end
