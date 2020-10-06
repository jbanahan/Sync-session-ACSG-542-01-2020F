require 'open_chain/archive_packet_generator'
require 'open_chain/template_util'
class AttachmentArchiveSetupsController < ApplicationController
  before_action :secure_me

  def show
    flash.keep
    redirect_to edit_company_attachment_archive_setup_path(params[:company_id], params[:id])
  end

  def new
    @company = Company.find params[:company_id]
    @company.build_attachment_archive_setup
  end

  def edit
    @company = AttachmentArchiveSetup.find(params[:id]).company
  end

  def update
    s = AttachmentArchiveSetup.find(params[:id])
    make_params_consistent(params)

    unless verify_output_path params[:attachment_archive_setup][:output_path]
      error_redirect "Archive setup was not saved. 'Archive Output Path' was not valid."
      return
    end

    if s.update(permitted_params(params))
      add_flash :notices, "Your setup was successfully updated."
      redirect_to [s.company, s]
    else
      error_redirect "Your setup could not be updated."
    end
  end

  def create
    make_params_consistent(params)
    @aas = AttachmentArchiveSetup.new(permitted_params(params))

    c = Company.find params[:company_id]
    if c.attachment_archive_setup
      error_redirect "This company already has an attachment archive setup."
      return
    end

    unless verify_output_path params[:attachment_archive_setup][:output_path]
      error_redirect "Archive setup was not saved. 'Archive Output Path' was not valid."
      return
    end

    if @aas.save!
      c.attachment_archive_setup = @aas
      c.save!
      add_flash :notices, "Your setup was successfully created."
    else
      errors_to_flash c.create_attachment_archive_setup(params[:attachment_archive_setup])
    end

    redirect_to [c, c.attachment_archive_setup]
  end

  def generate_packets
    c = Company.find params[:company_id]

    if params[:start_date].blank? && params[:csv_file].blank?
      add_flash :errors, "Either the start date or csv file must be provided."
    else
      settings = { company_id: params[:company_id], user_id: current_user.id, start_date: params[:start_date], end_date: params[:end_date], csv_file: params[:csv_file] }
      OpenChain::ArchivePacketGenerator.delay.generate_packets(settings)
      add_flash :notices, "Your packet generation request has been received. You will receive a message when it is complete."
    end

    redirect_to [c, c.attachment_archive_setup]
  end

  private

  def verify_output_path output_path
    # Not required, so blank is valid
    return true if output_path.blank?

    entry = Entry.new
    attachment = Attachment.new(attachable: entry)
    archive_attachment = AttachmentArchivesAttachment.new(attachment: attachment)

    variables = {'attachment' => ActiveRecordLiquidDelegator.new(attachment),
                 'archive_attachment' => ActiveRecordLiquidDelegator.new(archive_attachment),
                 'entry' => ActiveRecordLiquidDelegator.new(entry)}

    begin
      OpenChain::TemplateUtil.interpolate_liquid_string(output_path, variables)
    rescue StandardError
      false
    else
      true
    end
  end

  def make_params_consistent params
    unless params[:attachment_archive_setup][:combine_attachments] == "1"
      params[:attachment_archive_setup][:combined_attachment_order] = ""
      params[:attachment_archive_setup][:include_only_listed_attachments] = "0"
      params[:attachment_archive_setup][:send_in_real_time] = "0"
    end
  end

  def secure_me
    if !current_user.admin?
      error_redirect "You do not have permission to access this page."
      return false
    end
    true
  end

  def permitted_params(params)
    params.require(:attachment_archive_setup).permit(:company_id, :start_date, :end_date, :archive_scheme, :output_path,
                                                     :combine_attachments, :combined_attachment_order, :include_only_listed_attachments,
                                                     :send_in_real_time, :send_as_customer_number)
  end
end
