require 'open_chain/email_validation_support'

module OpenChain; module Report; module ReportEmailHelper
  extend ActiveSupport::Concern
  include OpenChain::EmailValidationSupport

  # This method exists to provide a more standardized option parsing for handling email instructions
  # for scheduled jobs / reports
  # It parses the given hash, validates email addresses referenced in it and returns a standardized hash
  # with symbolized keys of to, cc, bcc containing any email addresses or groups referenced in the given opts.
  #
  # Raises an error if it encounters any invalid email addresses or if no to emails are present
  def parse_email_from_opts opts, to_param: "email", group_param: "email_group", cc_param: "cc", bcc_param: "bcc"
    emails = {}
    to = []
    if opts[to_param].present?
      to.push(*parse_email_list(opts[to_param]))
    end

    if opts[group_param].present?
      to.push(*parse_email_group(opts[group_param]))
    end

    if to.length == 0
      raise ArgumentError, "At least one email address must be present under the '#{to_param}' key."
    end

    emails[:to] = to
    emails[:cc] = parse_email_list(opts[cc_param])
    emails[:bcc] = parse_email_list(opts[bcc_param])

    emails
  end

  def parse_email_list email_string
    return nil if email_string.blank?
    valid_emails, invalid_emails = partition_valid_email_addresses(email_string)
    if invalid_emails.present?
      raise ArgumentError,
            "Invalid email #{"address".pluralize(invalid_emails.length)} found: #{invalid_emails.join(", ")}."
    end

    valid_emails
  end

  def parse_email_group group_system_code
    return nil if group_system_code.blank?

    group = Group.where(system_code: group_system_code).order(:system_code).to_a
    raise ArgumentError, "Invalid email group found: #{Array.wrap(group_system_code).join(", ")}." if group.blank?
    group
  end

end; end; end
