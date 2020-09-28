require 'open_chain/custom_handler/ascena/abstract_ascena_billing_invoice_file_generator'
require 'open_chain/report/base_report_helper'

module OpenChain; module CustomHandler; module Ascena; class AscenaFtzBillingInvoiceFileGenerator < AbstractAscenaBillingInvoiceFileGenerator
  include OpenChain::Report::BaseReportHelper

  attr_reader :custom_where, :supplemental_file_data

  def self.run_schedulable opts = {}
    opts = opts.with_indifferent_access
    self.new(opts).generate_and_send opts[:customer_number]
  end

  def initialize opts = {}
    @custom_where = opts[:custom_where]
  end

  def generate_and_send customer_number
    results = run_query customer_number
    entry_digest = entries_from_qry(results)
    file_data, sync_records = process_entries(entry_digest)

    if file_data.present?
      send_file(file_data, sync_records, file_prefix(entry_digest.keys.first.customer_number), ftz: true, duty_file: true)
      handle_sync_records(sync_records)
    end

    nil
  end

  private

  def trading_partners
    [DUTY_SYNC, DUTY_CORRECTION_SYNC]
  end

  def run_query cust_num
    results = Hash.new { |h, k| h[k] = Set.new }

    trading_partners.each do |tp|
      qry_results = ActiveRecord::Base.connection.execute(query(cust_num, tp))
      qry_results.each { |r| results[r[0]].add r[1] }
    end

    results
  end

  def entries_from_qry results
    Entry.where(id: results.keys)
         .includes(:broker_invoices, :entity_snapshots)
         .reject(&:any_failed_rules?)
         .map do |ent|
            ent_snapshot = ent.last_snapshot.snapshot_json
            # Keep only the invoices that were picked up by the query
            bi_snapshots = json_child_entities(ent_snapshot, "BrokerInvoice").select { |bi_json| results[ent.id].include? bi_json["record_id"] }
            [ent, [bi_snapshots, ent_snapshot]]
         end.to_h
  end

  def process_entries entry_hsh
    file_data = []
    sync_records = []

    entry_hsh.each_pair do |entry, (bi_snapshots, ent_snapshot)|
      Lock.db_lock(entry) do
        @supplemental_file_data = SupplementalFileData.new(entry).parse
        unsent = unsent_invoices(entry, bi_snapshots, trading_partners, override_sync_records: custom_where.present?)

        unsent.each_pair do |_invoice_number, invoice_data|
          supplemental_file_data.calculate_duty(invoice_data[:invoice_lines][DUTY_SYNC])

          generate_invoice(ent_snapshot, invoice_data, entry) do |inv_file_data, sync_record|
            file_data.concat inv_file_data
            sync_records << sync_record
          end
        end
      end
    end
    [file_data, sync_records]
  end

  def handle_sync_records sync_records
    BrokerInvoice.transaction do
      sync_records.each do |sr|
        sr.sent_at = Time.zone.now
        sr.confirmed_at = sr.sent_at + 1.minute
        sr.save!
      end
    end
  end

  def po_organization_ids _entry_snapshot
    supplemental_file_data.brand_hash
  end

  def calculate_duty_amounts _entry_snapshot
    supplemental_file_data.duty_hash
  end

  def query cust_num, trading_partner
    qry = <<-SQL
            SELECT entries.id, broker_invoices.id
            FROM broker_invoices
              INNER JOIN entries ON entries.id = broker_invoices.entry_id
              #{BrokerInvoice.need_sync_join_clause(trading_partner) unless custom_where}
            WHERE entries.customer_number = ?
              AND entries.entry_type = '06'
              AND entries.first_entry_sent_date IS NOT NULL
              AND #{custom_where || BrokerInvoice.has_never_been_synced_where_clause}
              #{"AND broker_invoices.invoice_date > DATE_SUB(CURDATE(), INTERVAL 1 YEAR)" unless custom_where}
    SQL
    ActiveRecord::Base.sanitize_sql_array([qry, cust_num])
  end

  class SupplementalFileData
    include OpenChain::EntityCompare::ComparatorHelper

    attr_reader :raw_totals, :duty

    def initialize entry
      @entry = entry
      @raw_totals = Hash.new { |h, k| h[k] = {total_duty: BigDecimal("0"), brand: nil} }
      @duty = nil
    end

    def parse
      suppl_att = @entry.attachments.where(attachment_type: "FTZ Supplemental Data").first

      suppl_att&.download_to_tempfile do |t|
        CSV.foreach(t.path, headers: true) do |r|
          row = Wrapper.new r
          total_duty = row[:cotton_fee] + row[:mpf_pro_rate] + row[:duty]
          @raw_totals[row[:po_number]][:total_duty] += total_duty
          @raw_totals[row[:po_number]][:brand] = po_organization_code(row[:brand].to_i)
        end
      end

      self
    end

    def calculate_duty bi_invoice_lines
      ci_total_duty = raw_totals.values.map { |v| v[:total_duty] }.sum
      bi_total_duty = bi_invoice_lines.map { |l| mf(l, "bi_line_charge_amount") }.compact.sum

      @duty = raw_totals.transform_values do |v|
        total_duty = ci_total_duty.zero? ? nil : ((v[:total_duty] / ci_total_duty) * bi_total_duty).round(2)
        {total_duty: total_duty, brand: v[:brand]}
      end

      distribute_pennies bi_total_duty unless ci_total_duty.zero?

      self
    end

    def duty_hash
      duty&.transform_values { |v| v[:total_duty] }
    end

    def brand_hash
      duty&.transform_values { |v| v[:brand] }
    end

    private

    def distribute_pennies bi_total_duty
      excess = bi_total_duty - duty.values.map { |v| v[:total_duty] }.sum
      pennies = (excess * 100).abs.round
      increment = 0.01 * (excess.positive? ? 1 : -1)
      duty.keys.cycle.take(pennies).each { |k| duty[k][:total_duty] += increment }
    end

    def po_organization_code code
      xref = {5 => 151, 6 => 151, 52 => 151, 81 => 151, # Justice
              35 => 7220, 36 => 7220, # Lane Bryant
              37 => 7218, 38 => 7218, # Catherines
              86 => 218, 87 => 218, 88 => 218} # Maurices
      xref[code]
    end

  end

  class Wrapper < RowWrapper
    FIELD_MAP ||= {brand: 7, cotton_fee: 11, duty: 16, mpf_pro_rate: 51, po_number: 55}.freeze

    def initialize row
      super row, FIELD_MAP
      [:cotton_fee, :mpf_pro_rate, :duty].each { |k| self[k] = BigDecimal(self[k].to_s) }
    end
  end

end; end; end; end
