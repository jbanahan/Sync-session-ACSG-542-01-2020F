require 'open_chain/fixed_position_generator'
require 'open_chain/ftp_file_support'
require 'digest/md5'

# Business Rules:
# * All lines must have part number and po number
# * If the same style is used on multiple lines, then the _more specific_ line must use the following format  style~color~size 
#   Both color and size are optional so the following are all valid: 067-0541, 067-0541~RED, 067-0651~~XXXL, 067-0541-RED-XXXL
# * If used, color must be the 3 character EB provided code
# * If used, size must be the 4 character EB provided code
# * Files will be sent after they have been invoiced and all business rules are in a passed state
# * Files will be resent if anything in the output has changed

module OpenChain; module CustomHandler; module EddieBauer; class EddieBauerFtzAsnGenerator
  include OpenChain::FtpFileSupport
  TRANSPORT_MODE_CODES ||= {'11'=>'O','10'=>'O','20'=>'R','21'=>'R','30'=>'T','31'=>'T','32'=>'T','33'=>'T','34'=>'T','40'=>'A','41'=>'A'}

  SYNC_CODE ||= 'EBFTZASN'
      
  def self.run_schedulable opts={'customer_numbers'=>['EDDIEFTZ']}
    g = self.new Rails.env, opts
    g.run_for_entries(g.find_entries)
  end

  def run_for_entries entries
    generate_file(entries) do |file, sync_records, errors|
      begin
        ActiveRecord::Base.transaction do
          sync_records.each {|sr| sr.save!}

          ftp_file file
        end
      rescue => e
        errors << e
      end

      # This is a major hack to get all errors to go out via the scheduled job failure email handler.
      # I'm relying on the schedulable job's run method to use the exception's message attribute
      # to get the email's message
      if errors.length > 0
        message = ("<ul>" + errors.map {|e| "<li>#{e.message}</li>"}.join + "</ul>").html_safe
        raise StandardError, message
      end
    end
  end

  def initialize env=Rails.env, opts={}
    inner_opts = {'customer_numbers'=>['EDDIEFTZ']}.merge opts
    @f = OpenChain::FixedPositionGenerator.new(exception_on_truncate:true,
      date_format:'%m/%d/%Y', output_timezone: ActiveSupport::TimeZone["UTC"], numeric_pad_char: '0', numeric_strip_decimals: true
    )
    @env = env
    @customer_numbers = inner_opts['customer_numbers']
    @skip_long_containers = inner_opts['skip_long_containers']
  end

  def ftp_credentials
    folder_prefix = @env=='production' ? 'prod' : 'test'
    {:server=>'connect.vfitrack.net',:username=>'eddiebauer',:password=>'antxsqt',:folder=>"/#{folder_prefix}/to_eb/ftz_asn",:remote_file_name=>"FTZ_ASN_#{Time.now.strftime('%Y%m%d%H%M%S')}.txt"}
  end

  def generate_file entries
    Tempfile.open(['EDDIEFTZASN','.txt']) do |t|
      sync_records = []
      errors = []
      entries.each_with_index do |ent,i|
        begin
          data = generate_data_for_entry(ent)
          new_fingerprint = Digest::MD5.hexdigest(data)
          sr = ent.sync_records.first_or_initialize trading_partner: SYNC_CODE

          # We ignore the fingerprint if the sent_at is blank (which will happen on sync records built just now or ones marked to be resent)
          if sr.sent_at.nil? || new_fingerprint != sr.fingerprint
            t << "\r\n" if t.size > 0
            t << data
            sr.sent_at = Time.zone.now
            sr.fingerprint = new_fingerprint
          else
            sr.ignore_updates_before = ent.updated_at
          end
          sync_records << sr
        rescue => e
          # We're copying our error into a new one so that we can prepend the Entry # to the message so we know exactly which entry the 
          # error occurred on.
          new_error = e.class.new("File ##{ent.broker_reference}: #{e.message}")
          new_error.set_backtrace e.backtrace
          errors << new_error
        end
      end

      t.flush
      yield t, sync_records, errors
    end
    nil
  end
  
  # find entries that have passed business rules and need sync
  def find_entries
    passed_rules = SearchCriterion.new(model_field_uid:'ent_rule_state',operator:'eq',value:'Pass')
    cust_num = SearchCriterion.new(model_field_uid:'ent_cust_num',operator:'in',value:@customer_numbers.join("\n"))
    bi_total = SearchCriterion.new(model_field_uid:'ent_broker_invoice_total',operator:'gt',value:'0')
    r = bi_total.apply passed_rules.apply cust_num.apply Entry.select('distinct entries.*').where('file_logged_date > "2014-04-01"')
    r = r.where('(NOT length(entries.container_numbers) > 20)') if @skip_long_containers
    r.need_sync(self.class::SYNC_CODE)
  end

  def generate_data_for_entry ent
    r = ""
    ent.commercial_invoice_lines.each do |ci|
      style, color, size = parse_part(ci.part_number)
      next unless style.match(/^\d{3}-\d{4}/)
      r << "\r\n" if r.size > 0 #write new line except on first line
      r << @f.str(ent.broker_reference,7,false,true) #force truncate
      r << @f.str(ent.master_bills_of_lading,35)
      r << @f.str(ent.house_bills_of_lading,35)
      r << @f.str(ent.it_numbers,23)
      r << @f.str(ent.container_numbers,20)
      r << @f.date(ent.first_it_date)
      r << @f.str(ent.unlading_port_code,4)
      r << @f.str(ent.vessel,15,false,true)
      r << @f.str(TRANSPORT_MODE_CODES[ent.transport_mode_code],1)
      r << @f.date(ent.export_date)
      r << @f.date(ent.arrival_date)
      r << @f.str(ent.lading_port_code,5)
      r << @f.str(ent.unlading_port_code,4)
      r << @f.num(ent.total_packages,9,0)
      r << @f.str(ent.transport_mode_code,2)
      r << @f.str(ent.carrier_code,4)
      r << @f.str(ent.voyage,15,false,true)
      r << @f.str(ci.country_export_code,2)
      r << @f.str(ci.po_number,15)
      r << @f.str(ci.country_origin_code,2)
      r << @f.str(ci.mid,15)
      r << @f.str(style,20)
      r << @f.str(color,3)
      r << @f.str(size,4)
      r << @f.num(ci.quantity,9,0)
      tariff_1, tariff_2 = tariff_lines(ci)
      r << @f.num(tariff_1.entered_value,11,2)
      r << @f.num(0,11,2)
      r << @f.num(tariff_1.gross_weight,11,2)
      r << @f.num(tariff_1.hts_code,10)
      r << @f.str((tariff_2 && tariff_2.hts_code ? tariff_2.hts_code : ''),10)
    end
    r
  end
  private
  def parse_part p
    r = p.split('~')
    r << '' while r.size < 3
    r
  end
  def tariff_lines ci_line
    r = ci_line.commercial_invoice_tariffs.order("entered_value desc").limit(2).to_a
    r << nil if r.size == 1
    r
  end
end; end; end; end