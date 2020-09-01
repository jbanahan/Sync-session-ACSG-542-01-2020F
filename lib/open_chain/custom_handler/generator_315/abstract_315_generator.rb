require 'open_chain/custom_handler/generator_315/shared_315_support'

# Including classes should implement the following:
#  split_entry_data_identifiers
#  create_315_data
#  generate_and_send_document

module OpenChain; module CustomHandler; module Generator315; class Abstract315Generator
  include OpenChain::CustomHandler::Generator315::Shared315Support

  # tested by including class
  def generate_and_send_315s setup, obj, milestones, testing = false
    split_objects = split_entry_data_identifiers setup.output_style, obj
    data_315s = []

    split_objects.each do |data|
      milestones.each do |milestone|
        data_315s << create_315_data(obj, data, milestone)
      end
    end

    generate_and_send_document(setup_customer(setup), data_315s.compact, testing) do |data_315|
      data_315.sync_record.confirmed_at = Time.zone.now
      data_315.sync_record.save!
    end

    nil
  end

  def v uid, obj
    ModelField.by_uid(uid).process_export obj, user
  end

  def setup_customer setup
    setup.customer_number.presence || setup.parent_system_code
  end

  def determine_port_code_type code, port
    return nil if code.blank?

    case code.to_s.upcase
    when port.schedule_d_code.to_s.upcase
      "Schedule D"
    when port.schedule_k_code.to_s.upcase
      "Schedule K"
    when port.unlocode.to_s.upcase
      "UNLocode"
    when port.iata_code.to_s.upcase
      "IATA"
    when port.cbsa_port.to_s.upcase
      "CBSA"
    end
  end

end; end; end; end
