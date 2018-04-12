require 'spreadsheet'
require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'

module ConfigMigrations; module AnnInc; class AnnVendorLoader
  include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport

  def self.process(filename)
    wb = Spreadsheet.open filename

    self.new.process wb
  end

  def process(workbook)
    @workbook = workbook
    @cdefs = self.class.prep_custom_definitions [:mp_type, :dsp_type, :dsp_effective_date]
    @master = Company.where(master: true).first
    raise "No master company found" if @master.blank?

    create_suppliers
    add_general_users
  end

  def workbook
    @workbook
  end

  def cdefs
    @cdefs
  end

  def master
    @master
  end


  def create_suppliers
    suppliers = workbook.worksheet 0

    suppliers.each 1 do |supplier|
      supplier[1].to_s.split(',').each do |s|
        s = s.present? ? s : @master.system_code
        c = Company.where(system_code: s).first_or_initialize
        c.name = supplier[0]
        c.save!
        c.find_and_set_custom_value(cdefs[:mp_type], supplier[9])
        c.find_and_set_custom_value(cdefs[:dsp_type], supplier[8])
        c.find_and_set_custom_value(cdefs[:dsp_effective_date], supplier[7])
        c.save!
        master.linked_companies << c unless master.linked_companies.include? c
      end
    end
  end

  def add_general_users
    users = workbook.worksheet 0

    users.each 1 do |user|
      company_ids = user[1].to_s.split(',')
      companies = Company.where(system_code: company_ids)
      next unless companies.present? && user[3].present?
      first_name = user[3]
      last_name = user[4]
      email = user[5].gsub(/[[:space:]]/, "")
      username = email
      u = User.where(email: email).first_or_initialize
      u.username = username
      u.first_name = first_name
      u.last_name = last_name
      u.password = 'password'
      u.password_reset = true
      u.company = companies.first
      u.save!
      companies.each do |company|
        company.users << u
      end
    end
  end

end; end; end