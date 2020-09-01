module OpenChain; module CustomHandler; module Generator315; module Tradelens; class Data315Filler
  attr_reader :entry, :data, :data_315, :milestone

  def initialize entry, data, milestone
    @entry = entry
    @data = data
    @milestone = milestone
  end

  def create_315_data
    return self if data[:master_bills].blank? || data[:container_numbers].blank?

    data_315 = OpenStruct.new
    data_315.transport_mode_code = data[:transport_mode_code].to_i
    data_315.master_bills = data[:master_bills]
    data_315.container_numbers = data[:container_numbers]
    data_315.event_code = milestone.code
    data_315.event_date = milestone.date
    data_315.sync_record = milestone.sync_record
    @data_315 = data_315

    self
  end

  def add_entry_port
    return unless data_315

    port_code = entry.entry_port_code
    if port_code.match(/[A-Z]/)
      data_315.unlocode = port_code
    else
      data_315.gln = "#{port_prefix} #{port_code}".strip
    end

    self
  end

  private

  def port_prefix
    return "Schedule D:" if entry.american?
    return "CBSA:" if entry.canadian?
  end
end; end; end; end; end
