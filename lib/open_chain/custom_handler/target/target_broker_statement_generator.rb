require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module Target; class TargetDailyBrokerStatementGenerator
  include OpenChain::FtpFileSupport

  SYNC_TRADING_PARTNER = 'TARGET_BROKER_STATEMENT'.freeze

  def self.run_schedulable _opts = {}
    self.new.generate_and_send
  end

  def generate_and_send
    statements = find_statements

    Tempfile.open(["BROKER_STMT_", ".txt"]) do |temp|
      Attachment.add_original_filename_method temp, "BROKER_STMT_#{ActiveSupport::TimeZone["America/New_York"].now.strftime("%Y-%m-%d")}.txt"

      fp_generator = OpenChain::FixedPositionGenerator.new(exception_on_truncate: true, date_format: '%Y%m%d',
                                                           numeric_pad_char: '0', numeric_strip_decimals: true)
      statements.each do |stmt|
        stmt.daily_statement_entries.each do |ent|
          temp << generate_file_line(fp_generator, stmt, ent)
        end
      end
      temp.flush
      temp.rewind

      # Create a sync record for each statement that appeared on the report.  This will prevent them from
      # showing up on another report.
      sync_records = statements.map do |s|
        s.find_or_initialize_sync_record(SYNC_TRADING_PARTNER)
      end

      # Send the file, updating the sync record FTP session ID in the process.
      ftp_sync_file temp, sync_records

      # Finalize the sync records with sent/confirmed at dates.
      sync_records.each do |sync|
        sync.update! sent_at: 1.second.ago, confirmed_at: 0.seconds.ago
      end
    end
    nil
  end

  def ftp_credentials
    connect_vfitrack_net "to_ecs/target_broker_statement#{MasterSetup.get.production? ? "" : "_test"}"
  end

  private

    def find_statements
      target = Company.with_customs_management_number("TARGEN").first
      raise "Target company record not found." unless target
      DailyStatement
        .joins("LEFT OUTER JOIN sync_records AS sync ON sync.syncable_id = daily_statements.id AND sync.syncable_type = 'DailyStatement' " +
               "and sync.trading_partner = '#{SYNC_TRADING_PARTNER}'")
        .where(importer_id: target.id, status: "F").
        # Time needs to be excluded from this comparison.  Looking for records from the previous calendar day.
        where("daily_statements.final_received_date < ?", ActiveSupport::TimeZone["America/New_York"].now.to_date).
        # Daily statements that have been included on a previous version of this report should not be sent ever again.
        where("sync.id IS NULL OR sync.sent_at IS NULL").
        # Optional allowance of a hard limit on when we start looking for statements, in case of a delayed roll-out.
        where("daily_statements.final_received_date >= ?", SystemDate.find_start_date(SYNC_TRADING_PARTNER, default_date: Date.new(1970, 1, 1)))
    end

    def generate_file_line generator, stmt, ent
      line = ""
      line << generator.string(stmt.statement_number, 15)
      line << generator.date(stmt.final_received_date)
      line << generator.string(ent.entry&.entry_number&.gsub(/\A(\d{3})(\d*?)(\d{1})\Z/, '\1-\2-\3'), 35)
      line << generator.number(ent.total_amount, 12, decimal_places: 2)
      line << generator.string(stmt.status, 1)
      line << "\n"
      line
    end

end; end; end; end
