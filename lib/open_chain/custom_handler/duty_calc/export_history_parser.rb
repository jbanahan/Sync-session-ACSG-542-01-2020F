require 'csv'
module OpenChain; module CustomHandler; module DutyCalc; 
  class ExportHistoryParser
    def initialize opts={}
      @inner_opts = {group_size:1000}.merge opts
      @claim_cache = Hash.new
    end
    def parse data
      ActiveRecord::Base.transaction do 
        rows = []
        row = 0
        CSV.parse(data) do |r|
          row += 1
          #manually skipping first row so we don't get the ruby built in header mapping
          #which makes the row sizes all report 11 even if columns are blank
          next if row == 1
          next unless r.size == 11 && r[10] && r[10].match(/[0-9]/)
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
      raise "Can't handle blank export date for row #{r}" if s.nil?
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