require 'open_chain/report/builder_output_report_helper'
require 'open_chain/custom_handler/target/target_custom_definition_support'

# This report works with entry initiation information, stored as Shipments, determining
# which of these shipments/entry initiations can be consolidated as customs entries.
module OpenChain; module CustomHandler; module Target; class TargetEntryConsolidationReport
  include OpenChain::CustomHandler::Target::TargetCustomDefinitionSupport
  include OpenChain::Report::BuilderOutputReportHelper

  LAST_REPORT_RUN = "Target Entry Consolidation Report Last Run".freeze
  INIT_PARSER = "OpenChain::CustomHandler::Target::TargetEntryInitiationFileParser".freeze

  ConsolidationReportData ||= Struct.new(:date_group_number, :bol, :vessel, :port_unlading_code, :port_unlading_name, :container_count, :total_value)

  # This should be scheduled to run every few minutes, but will only actually generate a report, at most,
  # once per day.
  def self.run_schedulable _settings = {}
    self.new.run_if_able
  end

  def run_if_able
    now = ActiveSupport::TimeZone[local_time_zone].now
    # Ensure that we've received entry initiations today, and that the last initiation finished processing
    # at least 30 minutes ago.  This is set up to allow for a burst of files, which was the original
    # plan for how Target would be sending this data.  In practice, since go live, we've been getting
    # only one or two init files per day.  When multiple files were involved, they were spaced out by
    # more than 30 minutes, which caused problems with the original requirement that only one consolidation
    # report run per day, forcing the removal of that code.
    max_proc_date = entry_initiation_inbound_files(last_run_date).maximum(:process_end_date)
    if max_proc_date && max_proc_date < (now - 30.minutes)
      run_entry_consolidation_report
    end
  end

  def run_entry_consolidation_report
    workbook = nil
    distribute_reads do
      workbook = generate_report
    end

    file_name_no_suffix = "Target_Entry_Consolidation_Report_#{ActiveSupport::TimeZone[local_time_zone].now.strftime("%Y-%m-%d-%H%M%S")}"
    write_builder_to_tempfile workbook, file_name_no_suffix do |temp|
      body_msg = "Attached is the Entry Consolidation Report."
      c = Company.with_customs_management_number("TARGEN").first
      ml = MailingList.where(system_code: "Target Entry Consolidation Report", company_id: c.id).first
      raise "No mailing list exists for 'Target Entry Consolidation Report' system code." if ml.nil?
      OpenMailer.send_simple_html(ml, "Target Entry Consolidation Report", body_msg, temp).deliver_now
    end

    # Update the last run system date so that we don't pick up the same entries on the next report run.
    sd = SystemDate.where(date_type: LAST_REPORT_RUN).first_or_create!
    sd.update! start_date: ActiveSupport::TimeZone[local_time_zone].now
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:shp_first_sale, :tar_fda_flag, :tar_fws_flag, :tar_add_case,
                                                   :tar_cvd_case, :prod_required_documents, :tar_spi_primary, :prod_aphis]
  end

  private

    def last_run_date
      SystemDate.find_start_date(LAST_REPORT_RUN, default_date: Date.new(1970, 1, 1))
    end

    def entry_initiation_inbound_files start_date
      InboundFile.where(parser_name: "OpenChain::CustomHandler::Target::TargetEntryInitiationFileParser").where("process_start_date >= ?", start_date)
    end

    def generate_report
      wbk = XlsxBuilder.new
      assign_styles wbk

      # Using inbound file log, look up the shipments connected to the entry initiation files received
      # today, which we're defining here as since the last report run.  Target is unlikely to send inits
      # later in the previous day, after data goes out, but it's not impossible.  Group shipments with
      # matching vessel and unlading port together.
      grouped_shipments = Hash.new {|h, k| h[k] = [] }
      rejected_shipments = []
      shipment_ids = entry_initiation_inbound_files(last_run_date)
                     .where(inbound_file_identifiers: {identifier_type: InboundFileIdentifier::TYPE_SHIPMENT_NUMBER})
                     .includes(:identifiers).pluck("inbound_file_identifiers.module_id").compact
      Shipment.where(id: shipment_ids).includes(:containers, shipment_lines: [:product]).find_each(batch_size: 250) do |shp|
        if ok_to_consolidate?(shp)
          grouped_shipments[[shp.vessel, shp.unlading_port&.schedule_d_code]] << shp
        else
          rejected_shipments << shp
        end
      end

      # Break the groupings down further if they exceed allowed consolidation thresholds.
      final_groupings = finalize_shipment_groupings(grouped_shipments, rejected_shipments)

      raw_data = []
      current_date_str = ActiveSupport::TimeZone[local_time_zone].now.strftime("%Y%m%d")
      final_groupings.each_with_index do |shp_arr, idx|
        shp_arr.each do |shp|
          raw_data << make_data_obj("#{current_date_str}-#{idx + 1}", shp)
        end
        # This will force a blank line between groupings.
        raw_data << nil
      end

      generate_consolidations_sheet wbk, raw_data

      excluded_raw_data = []
      rejected_shipments.each do |shp|
        excluded_raw_data << make_data_obj(nil, shp)
      end
      generate_excluded_sheet wbk, excluded_raw_data

      wbk
    end

    def ok_to_consolidate? shp
      if ok_to_consolidate_shipment? shp
        shp.shipment_lines.each do |line|
          if line.product
            if ok_to_consolidate_product? line.product
              tariff_records(line.product).each do |tar|
                if !ok_to_consolidate_tariff? tar
                  return false
                end
              end
            else
              return false
            end
          end
        end
      else
        return false
      end
      true
    end

    # Only ocean shipments can be consolidated. First sale shipments are excluded as well.
    # Additionally, NVOCC shipments cannot be consolidated or grouped.  NVOCC shipments are identified
    # by a house bill SCAC code of 'AMAW'.  These are very unlikely, but shipments with more than
    # 100 containers can be excluded as well.  They're too big for a consolidation.  (We were initially
    # instructed to prevent consolidations from being more than $999,999, but that requirement was
    # tossed before go-live.)
    def ok_to_consolidate_shipment? shp
      shp.ocean? &&
        !shp.custom_value(cdefs[:shp_first_sale]) &&
        !shp.house_bill_of_lading.to_s.upcase.starts_with?("AMAW") &&
        safe_container_count?(shp.containers.length)
    end

    # Returns false if the product has ties to CITES or FIFRA (defined as having "CITES CERTIFICATE"
    # or "FIFRA" appear in its Required Documents), or APHIS (a custom flag).
    def ok_to_consolidate_product? prod
      required_docs = prod.custom_value(cdefs[:prod_required_documents]).to_s.upcase
      !required_docs.match?(/CITES CERTIFICATE|FIFRA/) &&
        !prod.custom_value(cdefs[:prod_aphis])
    end

    # Returns false tariff has ties to FDA, FWS, ADD, CVD or FTA (defined as having a value in the Primary SPI field).
    def ok_to_consolidate_tariff? tar
      !tar.custom_value(cdefs[:tar_fda_flag]) &&
        !tar.custom_value(cdefs[:tar_fws_flag]) &&
        tar.custom_value(cdefs[:tar_add_case]).blank? &&
        tar.custom_value(cdefs[:tar_cvd_case]).blank? &&
        tar.custom_value(cdefs[:tar_spi_primary]).blank?
    end

    def tariff_records product
      product.classifications.where(country_id: us.id).first&.tariff_records || []
    end

    def us
      @us ||= Country.where(iso_code: "US").first
      raise "No US country found." if @us.nil?
      @us
    end

    # A consolidation cannot contain more than 50 BOLs (same as shipment count, 1:1 ratio) or more
    # than 100 containers, and its entered value also cannot exceed $999,999.  Should our vessel/port
    # groupings go over any of these thresholds, we must split them into subgroupings.  We've already
    # excluded any single shipments that exceed these thresholds.  This method also tosses any groupings
    # that aren't truly groupings: a potential consolidation group on the report must contain more than
    # 1 shipment, otherwise there's no point.
    def finalize_shipment_groupings vessel_port_grouped_shipments, rejected_shipments
      final_groupings = []
      vessel_port_grouped_shipments.each_value do |shp_arr|
        # Groupings of 1 (i.e. shipments that don't share vessel/unlading port with other shipments
        # in this batch) are to be excluded from the report.
        if shp_arr.length > 1
          bol_groupings = shp_arr.in_groups_of(50, false)
          bol_groupings.each do |shp_max_50_bol_arr|
            total_container_count = 0
            total_entered_value = BigDecimal(0)
            current_grouping = []
            shp_max_50_bol_arr.each do |shp|
              container_count = shp.containers.length
              entered_value = total_value(shp)
              if !safe_container_count?(total_container_count + container_count)
                if current_grouping.length > 1
                  final_groupings << current_grouping
                elsif current_grouping.length == 1
                  rejected_shipments << current_grouping[0]
                end
                current_grouping = []
                total_container_count = 0
                total_entered_value = BigDecimal(0)
              end
              total_container_count += container_count
              total_entered_value += entered_value
              current_grouping << shp
            end
            if current_grouping.length > 1
              final_groupings << current_grouping
            elsif current_grouping.length == 1
              rejected_shipments << current_grouping[0]
            end
          end
        else
          rejected_shipments << shp_arr[0]
        end
      end
      final_groupings
    end

    # Returns true if the container count is less than the allowed maximum for a consolidated entry.
    def safe_container_count? container_count
      container_count <= 100
    end

    def total_value shp
      val = BigDecimal(0)
      shp.shipment_lines.each do |ship_line|
        val += (ship_line.quantity || BigDecimal(0)) * (ship_line.order_line&.price_per_unit || BigDecimal(0))
      end
      val
    end

    def make_data_obj date_group_number, shp
      d = ConsolidationReportData.new
      d.date_group_number = date_group_number
      d.bol = shp.master_bill_of_lading
      d.vessel = shp.vessel
      d.port_unlading_code = shp.unlading_port&.schedule_d_code
      d.port_unlading_name = shp.unlading_port&.name
      d.container_count = shp.containers.length
      d.total_value = total_value(shp)
      d
    end

    def generate_consolidations_sheet wbk, raw_data
      sheet = wbk.create_sheet "Possible Consolidations",
                               headers: ["Date-Group #", "BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]

      raw_data.each do |row|
        styles = [nil, nil, nil, nil, nil, :integer, :currency]
        if row
          values = [row.date_group_number, row.bol, row.vessel, row.port_unlading_code, row.port_unlading_name, row.container_count, row.total_value]
        else
          # A nil row object is meant to represent a blank line.
          values = [nil, nil, nil, nil, nil, nil, nil]
        end
        wbk.add_body_row sheet, values, styles: styles
      end

      wbk.set_column_widths sheet, *Array.new(7, 20)

      sheet
    end

    def generate_excluded_sheet wbk, raw_data
      sheet = wbk.create_sheet "Excluded", headers: ["BOL", "Vessel", "Port Unlading Code", "Port of Unlading Name", "Container Count", "Total Value"]

      raw_data.each do |row|
        styles = [nil, nil, nil, nil, :integer, :currency]
        values = [row.bol, row.vessel, row.port_unlading_code, row.port_unlading_name, row.container_count, row.total_value]
        wbk.add_body_row sheet, values, styles: styles
      end

      wbk.set_column_widths sheet, *Array.new(6, 20)

      sheet
    end

    def assign_styles wbk
      wbk.create_style :integer, {format_code: "#,##0"}
      wbk.create_style :currency, {format_code: "$#,##0.00"}
    end

    def local_time_zone
      "America/New_York"
    end

end; end; end; end
