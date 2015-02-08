require 'csv'
require 'open_chain/xl_client'
module OpenChain; module CustomHandler; module DutyCalc
  class ClaimAuditParser
    # processes the given attachment which must be attached to a claim with no
    # existing claim audit records
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

        raise "DrawbackClaim #{claim.id} already has DrawbackClaimAudit records." unless claim.drawback_claim_audits.empty?

        self.new.parse_excel OpenChain::XLClient.new_from_attachable(att), claim.entry_number

        msg = "Processing successful for file #{attachment_name} on claim #{claim.name}."
      rescue
        has_error = true
        $!.log_me
        msg = "Error processing claim audit file (#{attachment_name}): #{$!.message}"
      ensure
        u.messages.create!(subject:"Drawback Claim Audit Complete #{has_error ? 'WITH ERRORS' : ''}",body:msg)
      end
      return has_error
    end

    def initialize opts={}
      @inner_opts = {group_size:2000}.merge opts
      @claim_cache = Hash.new
    end

    def parse_excel xl_client, claim_number
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
      self.parse(rp.new(xl_client),claim_number)
    end
    def parse_csv data, claim_number
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
      self.parse(rp.new(data),claim_number)
    end

    def parse row_parser, claim_number
      ActiveRecord::Base.transaction do 
        rows = []
        row = 0
        row_parser.parse do |r|
          row += 1
          #manually skipping first row so we don't get the ruby built in header mapping
          #which makes the row sizes all report 11 even if columns are blank
          next if row == 1
          next unless r.size == 11 && !r[10].blank?
          if rows.size == @inner_opts[:group_size]
            process_rows rows, claim_number
            rows = []
          end
          rows << r
        end
        process_rows(rows,claim_number) if rows.size > 0
      end
    end

    private 
    def process_rows rows, claim_number
      audits = rows.collect do |r|
        h = DrawbackClaimAudit.new(
          drawback_claim_id:find_claim_id(claim_number),
          export_date:make_date(r,0,"export date"),
          import_date:make_date(r,5,"import date"),
          import_part_number:r[2],
          export_part_number:r[3],
          import_entry_number:r[4],
          quantity:r[8],
          export_ref_1:r[9],
          import_ref_1:r[10]
        )
      end
      DrawbackClaimAudit.bulk_insert audits, {group_size: @inner_opts[:group_size]}
    end
    def make_date r, pos, desc
      s = r[pos]
      raise "Can't handle blank #{desc} for row #{r}" if s.nil?
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