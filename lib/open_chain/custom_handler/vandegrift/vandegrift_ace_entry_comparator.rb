require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/kewill_entry_parser'
require 'open_chain/custom_handler/vandegrift/kewill_entry_comparator'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftAceEntryComparator
  extend OpenChain::CustomHandler::Vandegrift::KewillEntryComparator
  extend OpenChain::EntityCompare::ComparatorHelper

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    json = get_json_hash new_bucket, new_path, new_version

    # Don't send for FDA entries, per Mike McCullough April 11, 2016
    return unless json['entity']['model_fields']['ent_fda_transmit_date'].blank?


    new_comments = entry_comments(json)
    non_ace_comment = find_non_ace_entry_comment new_comments

    # If we have a comment, then check to see if it's the first time the comment has appeared.
    # If so, send out a notification
    if non_ace_comment
      old_json = get_json_hash old_bucket, old_path, old_version
      old_comments = entry_comments(old_json)
      old_non_ace_comment = find_non_ace_entry_comment old_comments

      if old_non_ace_comment == nil
        send_notification json['entity'], non_ace_comment
      end
    end

  end

  def self.entry_comments json
    comments = []
    if !json.blank? && json.try(:[], 'entity').try(:[], 'children').respond_to?(:each)
      json['entity']['children'].each do |child|
        if child['entity']['core_module'] == 'EntryComment'
          comments << child['entity']
        end
      end
    end

    comments
  end

  def self.find_non_ace_entry_comment comments
    comments.each do |comment|
      body = comment['model_fields'].try(:[], 'ent_com_body')
      return comment if non_ace_comment?(comment) && after_ace_changeover?(comment)
    end

    nil
  end

  def self.non_ace_comment? comment
    body = comment['model_fields'].try(:[], 'ent_com_body')
    body = body.to_s.upcase
    body.starts_with?("ACE ENTRY SUMMARY QUEUED TO SEND") || body.starts_with?("ENTRY SUMMARY QUEUED TO SEND")
  end

  def self.after_ace_changeover? comment
    # just make this after April 9 (changeover was 1st, but
    # we were manually checking these prior to that)
    @ace_changeover ||= parse_time('2016-04-09 04:00')

    # Created at is UTC...just make this after April 8 (changeover was 1st, but
    # we were manually checking these prior to that and don't need to notify people
    # prior to this)
    created_at = parse_time comment['model_fields'].try(:[], 'ent_com_created_at')
    created_at && created_at >= @ace_changeover
  end

  def self.send_notification entry_hash, non_ace_comment
    subject = "File # #{entry_hash['model_fields']['ent_brok_ref']} was transmitted as non-ACE"

    body_text = []
    body_text << "File #: <a href=\"#{Entry.excel_url(entry_hash['record_id'])}\">#{entry_hash['model_fields']['ent_brok_ref']}</a>".html_safe
    body_text << "Entry Type: #{entry_hash['model_fields']['ent_type']}"
    body_text << "User: #{non_ace_comment['model_fields']['ent_com_username']}"
    body_text << "Summary Transmit Date: #{parse_time(non_ace_comment['model_fields']['ent_com_created_at']).strftime "%Y-%m-%d %H:%M"}"

    body = "<p>".html_safe
    body_text.each do |t|
      body << t
      body << "<br>".html_safe
    end
    body << "</p>".html_safe

    OpenMailer.send_simple_html(Group.use_system_group("entry_reviewers", name: "Entry Reviewers"), subject, body).deliver!
  end

end; end; end; end
