require 'open_chain/archive_packet_generator'

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
    if s.update(params[:attachment_archive_setup])
      add_flash :notices, "Your setup was successfully updated."
      redirect_to [s.company, s]
    else
      error_redirect "Your setup could not be updated."
    end
  end

  def create
    make_params_consistent(params)
    @aas = AttachmentArchiveSetup.new(params[:attachment_archive_setup])

    c = Company.find params[:company_id]
    if c.attachment_archive_setup
      error_redirect "This company already has an attachment archive setup."
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
end
