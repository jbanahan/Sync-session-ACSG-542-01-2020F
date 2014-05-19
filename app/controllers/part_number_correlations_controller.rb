require 'open_chain/tariff_finder'

class PartNumberCorrelationsController < ApplicationController
  def create
    if PartNumberCorrelation.can_view?(current_user)
      importer_ids = params["part_number_correlation"].delete("importers")
      importers = Company.where(id: [importer_ids]).to_a

      attached_file = params["part_number_correlation"].delete("attachment")

      pnc = PartNumberCorrelation.new(params[:part_number_correlation])
      att = Attachment.new(attached: attached_file)
      pnc.attachment = att; pnc.user = current_user
      if pnc.save
        pnc.delay.process(importers)
        add_flash :notices, "Your file is being processed. You will receive a system notification when processing is complete."
      else
        add_flash :errors, "#{pnc.errors.full_messages.join(' ')}. Please refresh the page and try again."
      end
    else
      add_flash :errors, "You do not have permission to use this tool."
    end

    redirect_to :back
  end

  def index
    if PartNumberCorrelation.can_view?(current_user)
      @importer_choices = Company.importers.collect{|c| [c.name, c.id]}
    else
      add_flash :errors, "You do not have permission to use this tool."
      redirect_to :back
    end
  end

end