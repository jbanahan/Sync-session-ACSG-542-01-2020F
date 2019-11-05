require 'open_chain/integration_client_parser'

module OpenChain; module CustomHandler; module Vandegrift; class KewillCustomerParser
  include OpenChain::IntegrationClientParser

  def self.parse json_data, opts = {}
    self.new.parse(ActiveSupport::JSON.decode(json_data), User.integration, opts[:key])
  end

  def parse data, user, file_path
    data.each do |customer|
      parse_customer(customer, user, file_path)
    end
  end

  def parse_customer data, user, s3_path
    return nil if data["customer_number"].blank? || data["customer_name"].blank?
    # Adding "****" to the company name is kinda hacky but it's a way to make sure we're always snapshoting the initial company create (since the
    # company name will have updated) without having to actually track if the call to find_or_create actually created the company or not.
    # This allows us below to simply use the .changed? method to determine whether the company needs to be snapshot or not.
    company = Company.find_or_create_company!("Customs Management", data["customer_number"], {name: "***#{data["customer_name"]}***", importer: true})
    Lock.db_lock(company) do
      company.name = data["customer_name"]

      address_changed = false
      Array.wrap(data["addresses"]).each do |address_data|
        if find_or_create_address(company, address_data)
          address_changed = true
        end
      end

      Array.wrap(data["notes"]).each do |note|
        parse_note(data["customer_number"], company, note)
      end

      if company.changed? || address_changed
        company.save!
        company.create_snapshot user, nil, s3_path
      end
    end

  end

  private

    def find_or_create_address company, address_data
      address_number = address_data["address_no_alpha"].to_s.gsub(/^0+/, "")
      address = company.addresses.find {|a| a.system_code == address_number }
      if address.nil?
        address = company.addresses.build system_code: address_number
      end

      address.assign_attributes(name: address_data["name"], line_1: address_data["address_1"], line_2: address_data["address_2"], city: address_data["city"], 
                      state: address_data["state_province"], postal_code: address_data["zip"], country_id: countries[address_data["country"]])

      address.changed?
    end

    def parse_note customer_number, company, note
      # This is specialized note handling for some companies.  Because Kewill doesn't seem to have any place to add any sort of other system identifiers
      # we're putting them in the notes and then parsing them out here.
      if customer_number =~ /^AMZN/i
        parse_amazon_notes(company, note)
      end
    end

    def countries
      @countries ||= Hash.new do |h, k|
        country = Country.where(iso_code: k).first
        # In case country is missing from the address
        h[k] = country.try(:id)
      end
    end

    def parse_amazon_notes company, note
      if note["note_cust"].to_s =~ /IOR-([A-Z0-9]+)/i
        SystemIdentifier.where(system: "Amazon Reference", code: $1, company_id: company.id).first_or_create! 
      end
    end

end; end; end; end
