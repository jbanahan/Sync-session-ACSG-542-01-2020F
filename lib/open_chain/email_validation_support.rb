require 'email_validator'

module OpenChain; module EmailValidationSupport

  # Returns true if every email in the given string or array of strings is valid
  # allow_newlines - if true (defaults to false), newlines will be allowed as delimiters for email addresses in addition to commas and semicolons
  def email_list_valid? list, allow_newlines: false
    valid_emails, invalid_emails = partition_valid_email_addresses(list, allow_newlines: allow_newlines)
    valid_emails.present? && invalid_emails.empty?
  end

  # Returns two arrays, the first array is a parsed list of all the valid email addresses from the given string/array.
  # The second array is all the invalid emails.
  #
  # allow_newlines: if true (defaults to true), newlines will be allowed as delimiters for email addresses in addition to commas and semicolons
  def partition_valid_email_addresses list, allow_newlines: true
    arr = split_email_list(list, allow_newlines: allow_newlines)
    arr.partition { |email_address| email_valid?(email_address) }
  end

  # Splits a string list or array of email addresses into an array of individual addresses.
  #
  # allow_newlines - if true (defaults to true), newlines will be allowed as delimiters for email addresses in addition to commas and semicolons
  def split_email_list email_list_string, allow_newlines: true
    split_expression = allow_newlines ? /(?:,|;|\r?\n)/ : /,|;/
    # The gsubs are to remove trailing spaces / tabs from each individual "row" of data
    Array.wrap(email_list_string).map {|email_str| email_str.split(split_expression).map { |value| value.gsub(/^[\t ]+/, "").gsub(/[\t ]+$/, "") } }.flatten
  end

  # Returns true if the given individual email address is a validly structured email address.
  def email_valid? email_address
    EmailValidator.valid?(email_address) && _pass_additional_checks?(email_address)
  end

  def _pass_additional_checks? address
    address.scan(/\n/).empty?
  end

end; end
