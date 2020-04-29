require 'email_validator'

module OpenChain; module EmailValidationSupport
  # Assumes separator is comma or semi-colon, NOT a space
  def email_list_valid? list
    arr = Array.wrap(list).map {|email_str| email_str.split(/,|;/)}.flatten
    arr.empty? ? false : arr.map { |e| EmailValidator.valid?(e) && pass_additional_checks?(e) }.all?
  end

  def pass_additional_checks? address
    address.scan(/\n/).empty?
  end

end; end
