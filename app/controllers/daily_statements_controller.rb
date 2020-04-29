require 'open_chain/custom_handler/vandegrift/kewill_statement_requester'
require 'open_chain/daily_statement_attachment_zipper'
require 'open_chain/s3'

class DailyStatementsController < ApplicationController

  def set_page_title
    @page_title ||= "Daily Statement"
  end

  def index
    if current_user.view_statements?
      flash.keep
      redirect_to advanced_search CoreModule::CUSTOMS_DAILY_STATEMENT, params[:force_search]
    else
      error_redirect "You do not have permission to view Statements."
    end
  end

  def show
    if current_user.view_statements?
      statement = DailyStatement.find params[:id]
      action_secure(statement.can_view?(current_user), statement, {:lock_check=>false, :verb=>"view", :module_name=>"statement"}) {
        @statement = statement
      }
    else
      error_redirect "You do not have permission to view Statements."
    end
  end

  def reload
    statement = DailyStatement.find params[:id]
    if current_user.company.master? && statement.can_view?(current_user)
      OpenChain::CustomHandler::Vandegrift::KewillStatementRequester.delay.request_daily_statements [statement.statement_number]
      add_flash :notices, "Updated statement has been requested.  Please allow 10 minutes for it to appear."
    end

    redirect_to statement
  end

  def show_attachments
    if current_user.view_statements?
      @statement = DailyStatement.find params[:id]
      action_secure(@statement.can_view?(current_user), @statement, {:lock_check=>false, :verb=>"view", :module_name=>"statement"}) {
        @types = attachment_type_list @statement.id
      }
    else
      error_redirect "You do not have permission to view Statements."
    end
  end

  def message_attachments
    if current_user.view_statements?
      statement = DailyStatement.find params[:id]
      action_secure(statement.can_view?(current_user), statement, {:lock_check=>false, :verb=>"view", :module_name=>"statement"}) {
        OpenChain::DailyStatementAttachmentZipper.delay.zip_and_send_message current_user.id, statement.id, params[:attachments][:types]
        add_flash :notices, "You will receive a message when your attachments are ready."
        redirect_to statement
      }
    else
      error_redirect "You do not have permission to view Statements."
    end
  end

  def email_attachments
    if current_user.view_statements?
      statement = DailyStatement.find params[:id]
      action_secure(statement.can_view?(current_user), statement, {:lock_check=>false, :verb=>"view", :module_name=>"statement"}) {
        OpenChain::DailyStatementAttachmentZipper.delay.zip_and_email current_user.id, statement.id, params[:attachments][:types], params[:attachments][:email_opts]
        add_flash :notices, "An email with your attachments will be sent shortly."
        redirect_to statement
      }
    else
      error_redirect "You do not have permission to view Statements."
    end
  end


  private

  def attachment_type_list statement_id
    att_data = DailyStatement.joins(daily_statement_entries: {entry: :attachments})
                             .where(id: statement_id)
                             .pluck("attachments.attachment_type, attachments.attached_file_size")
                             .map { |result| {type: result[0], size: result[1]} }

    types = Hash.new { |h, k| h[k] = {size: 0, underscore: "", checked: false} }

    att_data.each do |hsh|
      types[hsh[:type]][:size] += hsh[:size]
      types[hsh[:type]][:underscore] = hsh[:type].downcase.gsub(" ", "_")
      types[hsh[:type]][:checked] = true if ["7501 - ORIGINAL", "ENTRY PACKET", "ENTRY SUMMARY - F7501"].include? hsh[:type]
    end

    types.sort.to_h
  end

end
