require 'open_chain/custom_handler/vandegrift/kewill_entry_documents_sender'

module Api; module V1; module Admin; class KewillEntryDocumentsController < AdminApiController

  def send_google_drive_file_to_kewill
    drive_path = params[:path]
    gmail_account = params[:email]

    OpenChain::CustomHandler::Vandegrift::KewillEntryDocumentsSender.delay.send_google_drive_document_to_kewill gmail_account, drive_path

    render json: {ok: 'ok'}
  end

end; end; end; end
