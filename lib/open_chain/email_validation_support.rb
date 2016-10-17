require 'email_validator'

module OpenChain; module EmailValidationSupport
  def email_list_valid? list
    arr = Array.wrap(list).map{|email_str| email_str.delete(' ').split(/,|;/)}.flatten
    arr.empty? ? false : arr.map{ |e| EmailValidator.valid? e }.all?
  end
end; end