module OpenChain; module CustomHandler; module Generator315; module Tradelens; class RequestDataExtractor
  attr_reader :data_315

  def initialize data_315
    @data_315 = data_315
  end

  def request
    container_num = data_315.container_numbers.first
    event_date = data_315.event_date

    request = {originatorName: "Damco Customs Services Inc",
               originatorId: "DCSI",
               eventSubmissionTime8601: formatted_date(Time.zone.now),
               equipmentNumber: container_num,
               billOfLadingNumber: master_bill,
               eventOccurrenceTime8601: formatted_date(event_date)}

    add_port(request) if port?

    request
  end

  private

  def port?
    data_315.unlocode || data_315.gln
  end

  def add_port request
    if data_315.unlocode
      location = {type: "UN/LOCODE", value: data_315.unlocode}
    else
      location = {gln: data_315.gln}
    end
    request.merge!({location: location})
  end

  def master_bill
    transport_mode = Entry.get_transport_mode_name_lookup_us_ca[data_315.transport_mode_code]
    mbol = data_315.master_bills.first
    mbol = mbol&.sub(/^[a-zA-Z]{4}/, '') if transport_mode == "SEA"
    mbol
  end

  def formatted_date date
    date.strftime("%FT%T.000%:z")
  end

end; end; end; end; end
