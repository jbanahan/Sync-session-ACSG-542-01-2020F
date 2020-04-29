require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/mutable_boolean'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberSapVendorXmlParser
  include OpenChain::CustomHandler::XmlHelper
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  include OpenChain::IntegrationClientParser

  def self.parse_file data, log, opts={}
    parse_dom REXML::Document.new(data), log, opts
  end

  def self.parse_dom dom, log, opts={}
    self.new(opts).parse_dom dom, log
  end

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/ll/_sap_vendor_xml"
  end

  def initialize opts={}
    @cdefs = self.class.prep_custom_definitions [:cmp_sap_company, :cmp_po_blocked, :cmp_sap_blocked_status]
    @user = User.integration
  end

  def parse_dom dom, log
    root = dom.root
    log.error_and_raise "Incorrect root element #{root.name}, expecting 'CREMAS05'." unless root.name == 'CREMAS05'

    log.company = Company.where(system_code: "LUMBER").first

    base = REXML::XPath.first(root, '//E1LFA1M')
    sap_code = et(base, 'LIFNR')
    log.reject_and_raise "Missing SAP Number. All vendors must have SAP Number at XPATH //E1LFA1M/LIFNR" if sap_code.blank?
    name = et(base, 'NAME1')

    c = nil
    changed = MutableBoolean.new false

    Lock.acquire("Company-#{sap_code}") do
      c = Company.where(system_code:sap_code).first_or_initialize(name: name, show_business_rules:true)
      if !c.persisted?
        c.save!
        changed.value = true
      end

      log.add_identifier InboundFileIdentifier::TYPE_SAP_NUMBER, sap_code, module_type:Company.to_s, module_id:c.id

      master = Company.find_by_master(true)
      master.linked_companies << c unless master.linked_companies.include?(c)
    end

    Lock.with_lock_retry(c) do
      c.vendor = true
      c.name = name

      set_custom_value(c, :cmp_sap_company, sap_code, changed)

      update_address c, sap_code, base, changed, log
      lock_or_unlock_vendor c, base, changed

      if c.changed?
        changed.value = true
        c.save!
      end

      if changed.value
        c.touch
        c.create_snapshot User.integration, nil, "System Job: SAP Vendor XML Parser"
      end
    end
  end

  private

  def lock_or_unlock_vendor company, el, changed
    lock_code = et(el, 'SPERM')
    is_locked = lock_code=='X'

    # we always write the SAP value to the SAP Blocked Status field for tracking purposes
    set_custom_value(company, :cmp_sap_blocked_status, is_locked, changed)

    # we only set the actual PO Blocked field if the vendor is Blocked
    # per LL SOW #2.36, we don't want to clear the blocked status if it's cleared in SAP since
    # it might be overridden on the screens.
    #
    # https://docs.google.com/document/d/1PX80pIkNiCnNRFtCaGrVhKVi5ubdI30GgqlnzDDU5LA/edit#heading=h.sqrtf262xrei
    if is_locked
      set_custom_value(company, :cmp_po_blocked, true, changed)
    end
  end

  def update_address company, sap_code, el, changed, log
    add_sys_code = "#{sap_code}-CORP"
    add = company.addresses.where(system_code:add_sys_code).first_or_initialize(name:'Corporate')
    changed.value = true unless add.persisted?

    country_iso = et(el, 'LAND1')
    country = Country.find_by_iso_code country_iso
    log.reject_and_raise "Invalid country code #{country_iso}." unless country

    add.line_1 = et(el, 'STRAS')
    add.city = et(el, 'ORT01')
    add.state = et(el, 'REGIO')
    add.postal_code = et(el, 'PSTLZ')
    add.country_id = country.id

    if add.changed?
      add.save!
      changed.value = true
    end
  end

  def set_custom_value obj, cdef_uid, value, changed
    cd = @cdefs[cdef_uid]
    existing = obj.custom_value(cd)
    if existing != value
      obj.update_custom_value! cd, value
      changed.value = true
    end
  end

end; end; end; end
