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
    g.run_for_entries(g.find_entries,g)
  end
  def run_for_entries entries, instance=self.new
    instance.ftp_file instance.generate_file entries
  end
  def initialize env=Rails.env, opts={}
    inner_opts = {'customer_numbers'=>['EDDIEFTZ']}.merge opts
    @f = OpenChain::FixedPositionGenerator.new(exception_on_truncate:true,
      date_format:'%m/%d/%Y'
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
    t = Tempfile.new(['EDDIEFTZASN','.txt'])
    has_data = false
    entries.each_with_index do |ent,i|
      Entry.transaction do
        data = self.generate_data_for_entry(ent)
        new_fingerprint = Digest::MD5.hexdigest(data)
        sr = ent.sync_records.first_or_create!(trading_partner:SYNC_CODE)
        if new_fingerprint != sr.fingerprint
          t << "\r\n" if has_data
          t << data
          has_data = true
          sr.sent_at = 0.seconds.ago
          sr.fingerprint = new_fingerprint
          sr.save!
        else
          sr = ent.sync_records.first_or_create!(trading_partner:SYNC_CODE)
          sr.ignore_updates_before = ent.updated_at
          sr.save!
        end
      end
    end
    t.flush
    t
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
      style, color, size = parse_part(ci.part_number)
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