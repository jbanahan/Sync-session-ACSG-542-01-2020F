require 'open_chain/entity_compare/entry_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/report/landed_cost_report'
require 'open_chain/report/landed_cost_data_generator'
require 'open_chain/events/entry_events/landed_cost_report_attacher_listener'

module OpenChain; module CustomHandler; module Talbots; class TalbotsLandedCostComparator

  extend OpenChain::EntityCompare::EntryComparator
  extend OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    if super
      r = snapshot.recordable
      !!r.last_billed_date && r.try(:importer).try(:alliance_customer_number) == "TALBO"
    else
      false
    end
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless ent = Entry.where(id: id).first
    lc_hsh = OpenChain::Report::LandedCostDataGenerator.new.landed_cost_data_for_entry ent
    checksum = OpenChain::Events::EntryEvents::LandedCostReportAttacherListener.new.calculate_landed_cost_checksum_v3 lc_hsh
    lc_atts = ent.attachments.where(attachment_type: "Landed Cost Report")
    if lc_atts.any? { |att| att.checksum == checksum }
      return
    elsif lc_atts.present?
      revision = lc_atts.length
      suffix = "_rev#{revision}"
      lc_atts.destroy_all
    end
    handle_file(lc_hsh, ent, checksum, revision, "Talbots_Landed_Cost_Report_#{ent.entry_number}#{suffix}.xls")
    ent.create_snapshot User.integration, nil, "Talbots Landed Cost Comparator"
  end

  def self.handle_file lc_hsh, entry, checksum, revision, file_name
    OpenChain::Report::LandedCostReport.run_report_from_lc_data(User.integration, lc_hsh, entry_number: entry.entry_number) do |f|
      Attachment.add_original_filename_method f
      f.original_filename = file_name
      entry.attachments.create!(attached: f, attachment_type: "Landed Cost Report", checksum: checksum, alliance_revision: revision)
      send_email entry.entry_number, revision, f
    end
  end

  def self.send_email entry_number, revision, attachment
    entry_name = entry_number + (revision ? ' rev ' + revision.to_s : '')
    subject = "Talbots Landed Cost Report for Entry: #{entry_name}"
    body = "The Talbots Landed Cost Report for #{entry_name} was generated by VFI Track on #{Time.zone.now.in_time_zone("America/New_York").strftime("%m-%d-%Y %H:%M")}."
    recipients = Group.where(system_code: "TALBOTS LC REPORT").first.try(:users)
    if recipients
      emails = recipients.map(&:email).join(",")
      OpenMailer.send_simple_html(emails, subject, body, [attachment]).deliver!
    end
  end

end; end; end; end