class DrawbackUploadFilesController < ApplicationController
  def index 
    if current_user.view_drawback?
      exports = DutyCalcExportFileLine.select("importer_id, count(*) as 'total_lines'").where("duty_calc_export_file_id IS NULL").group('importer_id')
      @export_lines_not_in_duty_calc = {}
      exports.each {|f| @export_lines_not_in_duty_calc[Company.find(f.importer_id)] = f.total_lines}

      imports = DrawbackImportLine.select("importer_id, count(*) as 'total_lines'").not_in_duty_calc_file.group('importer_id')
      @import_lines_not_in_duty_calc = {}
      imports.each {|f| @import_lines_not_in_duty_calc[Company.find(f.importer_id)] = f.total_lines}
      render :layout=>'one_col'
    else
      add_flash :errors, "You cannot view this page because you do not have permission to view Drawback."
      redirect_to request.referrer
    end
  end
  def create
    if current_user.edit_drawback?
      if params['drawback_upload_file']['processor'].blank?
        add_flash :errors, "You cannot upload this file because the processor is not set.  Please contact support."
      else
        if params['drawback_upload_file']['attachment_attributes'].blank? || params['drawback_upload_file']['attachment_attributes']['attached'].blank?
          add_flash :errors, "You must select a file before uploading."
        else
          params['drawback_upload_file']['start_at'] = 0.seconds.ago
          d = DrawbackUploadFile.create!(params['drawback_upload_file'])
          validation = d.validate_layout
          if validation.empty?
            d.delay.process current_user
            add_flash :notices, "Your file is being processed.  You'll receive a system message when it's done."
          else
            d.destroy
            err = (["Your file cannot be processed because of the following validation errors:"]+validation).join("<br />").html_safe
            add_flash :errors, err
          end
        end
      end
    else
      add_flash :errors, "You cannot upload files because you do not have permission to edit Drawback."
    end
    redirect_to drawback_upload_files_path 
  end
end
