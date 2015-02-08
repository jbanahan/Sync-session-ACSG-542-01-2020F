require 'csv'
require 'open_chain/xl_client'
module OpenChain; module CustomHandler; module DutyCalc; 
  class ExportHistoryParser

    # processes the given attachment which must be attached to a claim with no
    # existing export history records
    def self.process_excel_from_attachment attachment_id, user_id
      attachment_name = "UNKNOWN"
      msg = ""
      has_error = false  
      u = User.find user_id
      begin
        att = Attachment.find attachment_id
        attachment_name = att.attached_file_name
        claim = att.attachable

        raise "Attachment with ID #{att.id} is not attached to a DrawbackClaim." unless claim.is_a?(DrawbackClaim)

        raise "User #{u.id} cannot edit DrawbackClaim #{claim.id}" unless claim.can_edit?(u)

        raise "DrawbackClaim #{claim.id} already has DrawbackExportHistory records." unless claim.drawback_export_histories.empty?

        self.new.parse_excel OpenChain::XLClient.new_from_attachable(att)

        msg = "Processing successful for file #{attachment_name} on claim #{claim.name}."
      rescue
        has_error = true
        $!.log_me
        msg = "Error processing export history file (#{attachment_name}): #{$!.message}"
      ensure
        u.messages.create!(subject:"Drawback Export History Complete #{has_error ? 'WITH ERRORS' : ''}",body:msg)
      end
      return has_error
    end

    def initialize opts={}
      @inner_opts = {group_size:1000}.merge opts
      @claim_cache = Hash.new
    end

    def parse_excel xl_client
      rp = Class.new do
        def initialize xlc
          @xlc = xlc
        end
        def parse
          @xlc.all_row_values(0) do |r|
            yield r
          end
        end
      end
      self.parse(rp.new(xl_client))
    end

    def parse_csv data
      rp = Class.new do 
        def initialize d
          @data = d
        end
        def parse
          CSV.parse(@data) do |r|
            yield r
          end
        end
      end
      self.parse(rp.new(data))
    end

    def parse row_parser
      ActiveRecord::Base.transaction do 
        rows = []
        row = 0
        row_parser.parse do |r|
          row += 1
          #manually skipping first row so we don't get the ruby built in header mapping
          #which makes the row sizes all report 11 even if columns are blank
          next if row == 1
          next unless r.size == 11 && r[10] && r[10].to_s.match(/[0-9]/)
          if rows.size == @inner_opts[:group_size]
            process_rows rows
            rows = []
          end
          rows << r
        end
        process_rows(rows) if rows.size > 0
      end
    end

    private 
    def process_rows rows
      histories = rows.collect do |r|
        h = DrawbackExportHistory.new(
          part_number:r[0],
          export_ref_1:r[1],
          export_date:make_export_date(r),
          quantity:r[5],
          drawback_claim_id: find_claim_id(r[7]),
          claim_amount_per_unit: r[9],
          claim_amount: r[10]
        )
      end
      DrawbackExportHistory.bulk_insert histories, {group_size: @inner_opts[:group_size]}
    end
    def make_export_date r
      s = r[4]
      raise "Can't handle blank export date for row #{r}" if s.blank?
      return s if s.respond_to?(:acts_like_date?) || s.respond_to?(:acts_like_time?)
      sd = s.split('/')
      Date.new(sd.last.to_i,sd.first.to_i,sd[1].to_i)
    end
    def find_claim_id claim_number
      r = @claim_cache[claim_number]
      if r.nil?
        dc = DrawbackClaim.find_by_entry_number claim_number
        if dc
          @claim_cache[claim_number] = dc.id
          r = dc.id
        end
      end
      r
    end
  end
end; end; end