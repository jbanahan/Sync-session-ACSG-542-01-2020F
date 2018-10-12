require 'spec_helper'

describe MailingList do
  describe '.mailing_lists_for_user' do
    it 'finds mailing lists for a user' do
      company = Factory(:company)
      user = Factory(:user, company: company)
      mailing_list = Factory(:mailing_list, name: 'blah', user: user, email_addresses: 'test@domain.com')
      company.mailing_lists << mailing_list
      company.save!

      expect(MailingList.mailing_lists_for_user(user)).to include(mailing_list)
    end
  end

  describe '#split_emails' do
    it 'splits the emails into an array' do
      mailing_list = MailingList.new
      mailing_list.email_addresses = "abc@domain.com, cde@domain.com"
      expect(mailing_list.split_emails).to eql(['abc@domain.com', 'cde@domain.com'])
    end
  end

  describe "#validate_email_addresses" do
    it 'sets non_vfi_addresses to true if a non_vfi_address is present' do
      vfi_user = Factory(:user)
      mailing_list = Factory(:mailing_list, name: 'blah', email_addresses: "#{vfi_user.email}, unknown@domain.com")
      mailing_list.reload
      expect(mailing_list.non_vfi_addresses).to be_truthy
    end

    it 'handles non-vfitrack emails at the beginning of the list' do
      vfi_user = Factory(:user)
      mailing_list = Factory(:mailing_list, name: 'blah', email_addresses: "#{vfi_user.email}")
      mailing_list.reload
      expect(mailing_list.non_vfi_addresses).to be_falsey
      mailing_list.email_addresses = "nonuser@domain.com, #{vfi_user.email}"
      mailing_list.save!
      mailing_list.reload
      expect(mailing_list.non_vfi_addresses).to be_truthy
    end

    it 'handles duplicate vfitrack email addresses' do
      vfi_user = Factory(:user)
      mailing_list = Factory(:mailing_list, name: 'blah', email_addresses: "#{vfi_user.email}, #{vfi_user.email}")
      mailing_list.reload
      expect(mailing_list.non_vfi_addresses).to be_falsey
    end

    it 'sets non_vfi_email_addresses when non-vfitrack email addresses are present' do
      vfi_user = Factory(:user)
      mailing_list = Factory(:mailing_list, name: 'blah', email_addresses: "#{vfi_user.email}, unknown@domain.com")
      expect(mailing_list.non_vfi_email_addresses).to eql('unknown@domain.com')
    end

    it 'sets non_vfi_addresses to false if no non_vfi_address is present' do
      vfi_user = Factory(:user)
      mailing_list = Factory(:mailing_list, name: 'blah', email_addresses: "#{vfi_user.email}")
      mailing_list.reload
      expect(mailing_list.non_vfi_addresses).to be_falsey
    end
  end

  describe '#extract_invalid_emails' do
    it 'should be true if an email is in an invalid format.' do
      mailing_list = MailingList.new
      mailing_list.email_addresses = "abc@domain.com, cde@domain"
      expect(mailing_list.extract_invalid_emails).to include('cde@domain')
    end
  end
end
