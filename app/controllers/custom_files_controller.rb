class CustomFilesController < ApplicationController
  def show
    cf = CustomFile.find params[:id]
    if cf.file_type == "OpenChain::CustomHandler::PoloMslPlusHandler"
      redirect_to "/custom_features/msl_plus/#{cf.id}"
    else
      error_redirect "Cannot identify route for custom file with file type #{cf.file_type}"
    end
  end
end
