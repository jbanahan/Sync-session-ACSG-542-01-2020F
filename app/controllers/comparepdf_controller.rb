class ComparepdfController < ApplicationController

  def compare
    @no_action_bar = true #implements it's own in compare.html.erb

    if params[:file1].blank? or params[:file2].blank?
      error_redirect "Two files must be provided."
    else
      @att1 = Attachment.find(params[:file1])
      @att2 = Attachment.find(params[:file2])

      unless @att1.can_view?(current_user) and @att2.can_view?(current_user)
        error_redirect "You do not have permission to view one or both documents."
      end

      unless @att1.is_pdf? and @att2.is_pdf?
        error_redirect "One or both documents is not a PDF."
      end
    end
  end
end
