module OpenChain; module CustomHandler; module DutyCalc
  class ClaimAuditParser
    def initialize opts={}
      @inner_opts = {group_size:2000}.merge opts
      @claim_cache = Hash.new
    end
    def parse data, claim_number
      ActiveRecord::Base.transaction do 
        rows = []
        row = 0
        CSV.parse(data) do |r|
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