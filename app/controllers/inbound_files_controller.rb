require 'open_chain/ftp_file_support'

class InboundFilesController < ApplicationController
  include DownloadS3ObjectSupport
  include OpenChain::FtpFileSupport

  SEARCH_PARAMS = {
    'd_companyid' => {:field => 'inbound_files.company_id', :label => "Company ID"},
    'd_companyname' => {:field => 'companies.name', :label => "Company Name"},
    'd_createdate' => {:field => 'inbound_files.created_at', :label => "Created At"},
    'd_filename' => {:field => 'inbound_files.file_name', :label => 'File Name'},
    'd_processstatus' => {:field => 'inbound_files.process_status', :label => "File Processing Status"},
    'd_identifier' => {:field => 'inbound_file_identifiers.value', :label => "Identifier"},
    'd_isanumber' => {:field => 'inbound_files.isa_number', :label => "ISA Number"},
    'd_message' => {:field => 'inbound_file_messages.message', :label => "Message"},
    'd_origprocessstartdate' => {:field => 'inbound_files.original_process_start_date', :label => "Original Process Start Date"},
    'd_parsername' => {:field => 'inbound_files.parser_name', :label=> 'Parser Name'},
    'd_processenddate' => {:field => 'inbound_files.process_end_date', :label => "Process End Date"},
    'd_processstartdate' => {:field => 'inbound_files.process_start_date', :label => "Process Start Date"},
    'd_receiptloc' => {:field => 'inbound_files.receipt_location', :label => 'Receipt Location'},
    'd_requeuecount' => {:field => 'inbound_files.requeue_count', :label => 'Requeue Count'}
  }

  def index
    sys_admin_secure {
      sp = SEARCH_PARAMS.clone
      s = build_search(sp, 'd_filename', 'd_processstartdate', 'd')
      s = s.joins("LEFT OUTER JOIN companies ON companies.id = inbound_files.company_id")

      if search_params_contains? 'd_identifier'
        s = s.joins("INNER JOIN inbound_file_identifiers ON inbound_files.id = inbound_file_identifiers.inbound_file_id")
        s = s.uniq
      end
      if search_params_contains? 'd_message'
        s = s.joins("INNER JOIN inbound_file_messages ON inbound_files.id = inbound_file_messages.inbound_file_id")
        s = s.uniq
      end

      # No field has been selected...ie it's the initial page load
      if params[:f1].blank?
        s = s.where("process_start_date > ?", Time.zone.now.beginning_of_day)
        @default_display = "By default, only files processed today are displayed when no search fields are utilized."
      end
      respond_to do |format|
          format.html {
              @inbound_files = s.paginate(:per_page => 40, :page => params[:page])
              render :layout => 'one_col'
          }
      end
    }
  end

  def show
    sys_admin_secure {
      @inbound_file = InboundFile.find(params[:id])
      respond_to do |format|
        format.html
      end
    }
  end

  def download
    sys_admin_secure {
      @inbound_file = InboundFile.find(params[:id])
      download_s3_object(@inbound_file.s3_bucket, @inbound_file.s3_path, filename: @inbound_file.file_name, disposition: "attachment", content_type: Array.wrap(MIME::Types.type_for(File.extname(@inbound_file.file_name))).first.try(:content_type))
    }
  end

  def reprocess
    sys_admin_secure {
      @inbound_file = InboundFile.find(params[:id])
      # Keeping things simple: the "reprocessing" that we're doing is simply downloading the file from S3, then
      # uploading it to the original pickup directory.  Another process will take over from there, eventually.
      OpenChain::S3.download_to_tempfile(@inbound_file.s3_bucket, @inbound_file.s3_path) do |s3_file|
        ftp_file s3_file, ecs_connect_vfitrack_net(@inbound_file.receipt_location, @inbound_file.file_name)
        add_flash :notices, "File has been queued for reprocessing."
      end
      redirect_to request.referrer
    }
  end

  private
    def secure
      InboundFile.find_can_view(current_user)
    end

end