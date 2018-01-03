require 'open_chain/integration_client_parser'
require 'open_chain/kewill_sql_proxy_client'

module OpenChain; module CustomHandler; module Vandegrift; class KewillStatementParser
  extend OpenChain::IntegrationClientParser

  def self.integration_folder
    # This parser is usable across multiple deployment instances so make sure the integration folder we're storing
    # to is tied to the system code as well

    # If we move to having multiple integration folders (like w/ an ftp server change), make sure the newest 
    # folder is the first returned in the array.
    "/home/ubuntu/ftproot/chainroot/#{MasterSetup.get.system_code}/kewill_statements"
  end

  def self.parse data, opts = {}
    json = ActiveSupport::JSON.decode(data)
    user = User.integration

    parser = self.new
    Array.wrap(json["daily_statements"]).each do |statement_json|
      parser.process_daily_statement user, statement_json, opts[:bucket], opts[:key]
    end

    Array.wrap(json["monthly_statements"]).each do |statement_json|
      parser.process_monthly_statement user, statement_json, opts[:bucket], opts[:key]
    end

    nil
  end

  def process_daily_statement user, json, last_file_bucket, last_file_path
    json = json["statement"]
    return if json.nil?

    statement_number, last_exported_from_source = statement_no_and_extract_time(json)

    s = nil
    find_and_process_daily_statement(statement_number, last_exported_from_source, last_file_bucket, last_file_path) do |statement|
      # Technically, we could update the daily statement entries / fees instead of destroying and rebuilding the
      # whole structure, but this is just easier for the time being.
      preliminary_data = json["status"].to_s.upcase == "P"

      parse_daily_statement(statement, json)
      broker_references = Set.new

      Array.wrap(json["details"]).each do |detail_json|
        detail = parse_daily_statement_entries(statement, detail_json, preliminary_data)
        broker_references << detail.broker_reference

        fee_codes = Set.new
        Array.wrap(detail_json["fees"]).each do |fee_json|
          fee = parse_daily_statement_entry_fee(statement, detail, fee_json, preliminary_data)
          fee_codes << fee.code
        end

        #Now we need to remove any fees from the detail that were not referenced in the json doc
        detail.daily_statement_entry_fees.each do |f|
          f.destroy unless fee_codes.include? f.code
        end
      end

      # Now we need to remove any statement entry which was not referenced in the json doc
      statement.daily_statement_entries.each do |e|
        e.destroy unless broker_references.include? e.broker_reference
      end

      # Now that we've synced up all the statement details to the json doc data, we need to set the 
      # daily statement totals based on those details
      set_daily_statement_totals(statement)

      statement.save!

      statement.create_snapshot user, nil, last_file_path 

      s = statement
    end

    s
  end

  def process_monthly_statement user, json, last_file_bucket, last_file_path
    json = json["monthly_statement"]
    return if json.nil?

    statement_number, last_exported_from_source = statement_no_and_extract_time(json)
    s = nil
    find_and_process_monthly_statement(statement_number, last_exported_from_source, last_file_bucket, last_file_path) do |statement|
      parse_monthly_statement(statement, json)

      # We need to now link the monthly statement with any daily statements that have this number
      DailyStatement.where(monthly_statement_number: statement.statement_number).update_all monthly_statement_id: statement.id

      calculate_monthly_totals(statement)

      statement.save

      statement.create_snapshot user, nil, last_file_path

      s = statement
    end

    s
  end

  private 

    def parse_monthly_statement statement, json
      # Don't ever change the status if the statement is in final status
      statement.status = json["status"] unless statement.final_statement?

      statement.due_date = parse_date(json["due_date"])
      statement.port_code = parse_port_code(json["port_code"])
      statement.pay_type = json["payment_type"]
      statement.customer_number = json["customer_number"]

      if statement.customer_number.blank?
        statement.importer = nil
      else
        statement.importer = Company.importers.where(alliance_customer_number: statement.customer_number).first
      end

      if json["status"] == "F"
        statement.final_received_date = parse_date(json["received_date"])
        # Paid date never comes on a prelim
        statement.paid_date = parse_date(json["paid_date"])
      else
        statement.received_date = parse_date(json["received_date"])
      end

      statement
    end

    def calculate_monthly_totals statement
      totals = {
        total_amount: BigDecimal("0"), duty_amount: BigDecimal("0"), tax_amount: BigDecimal("0"), 
        cvd_amount: BigDecimal("0"), add_amount: BigDecimal("0"), interest_amount: BigDecimal("0"),
        fee_amount: BigDecimal("0"),
        preliminary_total_amount: BigDecimal("0"), preliminary_duty_amount: BigDecimal("0"), preliminary_tax_amount: BigDecimal("0"), 
        preliminary_cvd_amount: BigDecimal("0"), preliminary_add_amount: BigDecimal("0"), preliminary_interest_amount: BigDecimal("0"),
        preliminary_fee_amount: BigDecimal("0")
      }

      # We're potentialy updating several daily statments previusly by setting the monthly statement id in them
      # That's why I'm doing a direct activerecord call / loop here, rather than relying on the potentially
      # outdated daily_statements relation in MonthlyStatement
      DailyStatement.where(monthly_statement_id: statement.id).each do |daily_statement|
        totals.keys.each do |key|
          val = daily_statement.public_send(key)
          totals[key] += val unless val.nil?
        end
      end

      totals.keys.each {|key| statement.public_send("#{key}=", totals[key]) }
    end


    def parse_daily_statement statement, json
      # Don't ever change the status if the statement is in final status
      statement.status = json["status"] unless statement.final_statement?

      statement.due_date = parse_date(json["due_date"])
      statement.port_code = parse_port_code(json["port_code"])
      statement.pay_type = json["payment_type"]
      statement.customer_number = json["customer_number"]

      if statement.customer_number.blank?
        statement.importer = nil
      else
        statement.importer = Company.importers.where(alliance_customer_number: statement.customer_number).first
      end

      # Final statments don't ever receive monthly statement numbers (WTF?)
      if json["status"].to_s.strip != "F"
        statement.monthly_statement_number = json["monthly_statement_number"]

        if statement.monthly_statement_number.blank?
          statement.monthly_statement = nil
        else
          base_query = MonthlyStatement.where(statement_number: statement.monthly_statement_number)
          if !statement.importer.nil?
            base_query = base_query.where(importer_id: statement.importer_id)
          end

          statement.monthly_statement = base_query.first
        end
      end

      if json["status"] == "F"
        statement.final_received_date = parse_date(json["received_date"])
      else
        # Final daily statements never receive a paid date or accepted date (only prelims)
        statement.paid_date = parse_date(json["paid_date"])
        statement.payment_accepted_date = parse_date(json["payment_accepted_date"])
        statement.received_date = parse_date(json["received_date"])
      end


      statement
    end

    def parse_daily_statement_entries statement, json, preliminary
      # The reference # will have leading zeros, which our entries do not have, strip them
      broker_reference = json["broker_reference"].to_s.gsub(/^0+/, "")

      # I don't know why broker reference would ever be missing, it's required and no data in kewill's system is
      # missing it, so raise an error if we ever come across data without this value.
      raise "Statement '#{statement.statement_number}' contains a detail without a broker reference number." if broker_reference.blank?

      # Because of the way we're tracking preliminary / final amounts, we want to update in place any entries, rather than destroy / rebuild entirely
      statement_entry = statement.daily_statement_entries.find {|e| e.broker_reference == broker_reference }
      if statement_entry.nil?
        statement_entry = statement.daily_statement_entries.build broker_reference: broker_reference
      end

      if statement_entry.broker_reference.blank?
        statement_entry.entry = nil
        statement_entry.billed_amount = nil
      else
        statement_entry.entry = Entry.where(source_system: Entry::KEWILL_SOURCE_SYSTEM, broker_reference: statement_entry.broker_reference).first
        if statement_entry.entry
          statement_entry.billed_amount = statement_entry.entry.broker_invoice_lines.where(charge_code: "0001").sum(:charge_amount)
        end
        
      end
      statement_entry.port_code = parse_port_code(json["port_code"])

      if preliminary
        statement_entry.preliminary_duty_amount = parse_decimal(json["duty_amount"])
        statement_entry.preliminary_tax_amount = parse_decimal(json["tax_amount"])
        statement_entry.preliminary_cvd_amount = parse_decimal(json["cvd_amount"])
        statement_entry.preliminary_add_amount = parse_decimal(json["add_amount"])
        statement_entry.preliminary_fee_amount = parse_decimal(json["fee_amount"])
        statement_entry.preliminary_interest_amount = parse_decimal(json["interest_amount"])
        statement_entry.preliminary_total_amount = parse_decimal(json["total_amount"])

        # If we're parsing a statement that has not gone to final status yet,
        # then we should also set the amounts into the main amount fields
        if !statement.final_statement?
          statement_entry.duty_amount = statement_entry.preliminary_duty_amount
          statement_entry.tax_amount = statement_entry.preliminary_tax_amount
          statement_entry.cvd_amount = statement_entry.preliminary_cvd_amount
          statement_entry.add_amount = statement_entry.preliminary_add_amount
          statement_entry.fee_amount = statement_entry.preliminary_fee_amount
          statement_entry.interest_amount = statement_entry.preliminary_interest_amount
          statement_entry.total_amount = statement_entry.preliminary_total_amount
        end
      else
        statement_entry.duty_amount = parse_decimal(json["duty_amount"])
        statement_entry.tax_amount = parse_decimal(json["tax_amount"])
        statement_entry.cvd_amount = parse_decimal(json["cvd_amount"])
        statement_entry.add_amount = parse_decimal(json["add_amount"])
        statement_entry.fee_amount = parse_decimal(json["fee_amount"])
        statement_entry.interest_amount = parse_decimal(json["interest_amount"])
        statement_entry.total_amount = parse_decimal(json["total_amount"])
      end
      
      statement_entry
    end

    def parse_daily_statement_entry_fee statement, statement_entry, fee_json, preliminary
      # The code is numeric in the json, so make sure we translate it to a string before trying to find it
      code = fee_json["code"].to_s
      raise "Statement # '#{statement.statement_number}' / File # '#{statement_entry.broker_reference}' has a fee line missing a code." if code.blank?

      # Because of the way we're tracking preliminary / final amounts, we want to update in place any fees, rather than destroy / rebuild entirely
      entry_fee = statement_entry.daily_statement_entry_fees.find {|f| f.code == code }
      if entry_fee.nil?
        entry_fee = statement_entry.daily_statement_entry_fees.build code: code
      end

      entry_fee.description = fee_json["description"]
      amount = parse_decimal(fee_json["amount"])

      if preliminary
        entry_fee.preliminary_amount = amount
        if !statement.final_statement?
          entry_fee.amount = amount
        end
      else
        entry_fee.amount = amount
      end

      entry_fee
    end

    def set_daily_statement_totals statement
      totals = {
        total_amount: BigDecimal("0"), duty_amount: BigDecimal("0"), tax_amount: BigDecimal("0"), 
        cvd_amount: BigDecimal("0"), add_amount: BigDecimal("0"), interest_amount: BigDecimal("0"),
        fee_amount: BigDecimal("0"),
        preliminary_total_amount: BigDecimal("0"), preliminary_duty_amount: BigDecimal("0"), preliminary_tax_amount: BigDecimal("0"), 
        preliminary_cvd_amount: BigDecimal("0"), preliminary_add_amount: BigDecimal("0"), preliminary_interest_amount: BigDecimal("0"),
        preliminary_fee_amount: BigDecimal("0")
      }

      # The meta-programming below is primarily me being lazy
      statement.daily_statement_entries.each do |e|
        totals.keys.each do |key|
          val = e.public_send(key)
          totals[key] += val unless val.nil?
        end
      end

      totals.keys.each {|key| statement.public_send("#{key}=", totals[key]) }
      nil
    end

    def find_and_process_daily_statement statement_number, last_exported_from_source, last_file_bucket, last_file_path
      statement = nil
      Lock.acquire("DailyStatement-#{statement_number}") do 
        statement = DailyStatement.where(statement_number: statement_number).first_or_create! last_exported_from_source: last_exported_from_source
      end

      Lock.db_lock(statement) do 
        return nil unless process_statement?(statement, last_exported_from_source)

        statement.last_exported_from_source = last_exported_from_source
        statement.last_file_bucket = last_file_bucket
        statement.last_file_path = last_file_path

        yield statement
      end

      statement
    end

    def find_and_process_monthly_statement statement_number, last_exported_from_source, last_file_bucket, last_file_path
      statement = nil
      Lock.acquire("MonthlyStatement-#{statement_number}") do 
        statement = MonthlyStatement.where(statement_number: statement_number).first_or_create! last_exported_from_source: last_exported_from_source
      end

      Lock.db_lock(statement) do 
        return nil unless process_statement?(statement, last_exported_from_source)

        statement.last_exported_from_source = last_exported_from_source
        statement.last_file_bucket = last_file_bucket
        statement.last_file_path = last_file_path

        yield statement
      end

      statement
    end


    def process_statement? statement, last_exported_from_source
      statement.last_exported_from_source.nil? || last_exported_from_source.nil? || statement.last_exported_from_source <= last_exported_from_source
    end

    def statement_no_and_extract_time json
      [json["statement_number"], Time.zone.parse(json["extract_time"].to_s)]
    end

    def parse_date val
      return nil if val.nil? || val.to_i == 0

      Time.zone.parse(val.to_i.to_s).to_date
    end

    def parse_port_code val
      val.to_s.rjust(4, '0')
    end

    def parse_decimal val, decimal_places: 2, decimal_offset: 2, rounding_mode: BigDecimal::ROUND_HALF_UP, no_offset: false
      str = val.to_s
      return BigDecimal.new("0") if str.blank? || str == 0

      str = str.rjust(decimal_offset, '0')

      # The decimal places is what the value will be rounding to when returned
      # The decimal offset is used because all of the numeric values in Kewill are
      # stored and sent without decimal places "12345" instead of "123.45" so that 
      # they don't have to worry about decimal rounding and integer arithmetic can be done on everything.
      # This also means that we need to know the scale of the number before parsing it.
      if !str.include?(".") && decimal_offset > 0
        begin
          str = str.insert(-(decimal_offset+1), '.')
        rescue IndexError
          str = "0"
        end
      end

      BigDecimal.new(str).round(decimal_places, rounding_mode)
    end

end; end; end; end;