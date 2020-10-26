class ComparepdfController < ApplicationController

  def compare
    @no_action_bar = true # implements it's own in compare.html.erb

    if params[:file1].blank? || params[:file2].blank?
      error_redirect "Two files must be provided."
    else
      @att1 = Attachment.find(params[:file1])
      @att2 = Attachment.find(params[:file2])

      unless @att1.can_view?(current_user) && @att2.can_view?(current_user)
        error_redirect "You do not have permission to view one or both documents."
      end

      unless @att1.pdf? && @att2.pdf?
        error_redirect "One or both documents is not a PDF."
      end
    end
  end
end
