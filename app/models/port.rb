class Port < ActiveRecord::Base

  validates :schedule_k_code, :format => {:with=>/^[0-9]{5}$/,:message=>"Schedule K code must be 5 digits.", :if=>:schedule_k_code?}
  validates :schedule_d_code, :format => {:with=>/^[0-9]{4}$/,:message=>"Schedule D code must be 4 digits.", :if=>:schedule_d_code?} 
  validates :cbsa_port, :format => {:with=>/^[0-9]{4}$/, :message=>"CBSA Port code must be 4 digits", :if=>:cbsa_port?}
  validates :cbsa_sublocation, :format => {:with=>/^[0-9]{4}$/, :message=>"CBSA Sublocation code must be 4 digits", :if=>:cbsa_sublocation?}
  validates :unlocode, :format => {:with=>/^[A-Z]{5}$/, :message=>"UN/LOCODE must be 5 upper case letters", :if=>:unlocode?}


  # Find the country who's port of entry this represents (or nil)
  def entry_country
    return 'United States' unless schedule_d_code.blank?
    return 'Canada' unless cbsa_port.blank?
    nil
  end

  # Returns array of arrays for option groups of schedule_d & cbsa ports
  def self.grouped_by_entry_country
    r = [['United States',[]],['Canada',[]]]
    Port.where('schedule_d_code is not null OR cbsa_port is not null').order(:name).each do |p|
      a = ["#{p.name} (#{p.search_friendly_port_code})",p.search_friendly_port_code]
      case p.entry_country
      when 'United States'
        r[0][1] << a
      when 'Canada'
        r[1][1] << a
      end
    end
    r
  end

  # Get a version of the port code that will match the Entry module (because Fenix truncates leading zeroes from port codes)
  def search_friendly_port_code
    return schedule_d_code unless schedule_d_code.blank?
    return schedule_k_code unless schedule_k_code.blank?
    return unlocode unless unlocode.blank?
    unless cbsa_port.blank?
      return cbsa_port.match(/^0/) ? cbsa_port[1,3] : cbsa_port
    end
    nil
  end

  # loads schedule d ports from the US standard at http://www.census.gov/foreign-trade/schedules/d/dist3.txt
  def self.load_schedule_d data
    Port.transaction do
      Port.where("schedule_d_code is not null").destroy_all
      CSV.parse(data) do |row|
        next unless row[0].blank? #don't process district code listings
        Port.create!(:schedule_d_code=>row[1],:name=>row[2])
      end
    end
  end

  # loads schedule k ports from teh US standard (CODEQ version) at http://www.ndc.iwr.usace.army.mil/db/foreign/scheduleK/data/
  def self.load_schedule_k data
    Port.transaction do
      Port.where("schedule_k_code is not null").destroy_all
      data.lines do |row|
        code = row[0,5]
        name = "#{row[7,50].strip}, #{row[57,25].strip}"
        p = Port.find_by_schedule_k_code code
        if p
          p.update_attributes(:schedule_k_code=>code,:name=>name)
        else
          Port.create!(:schedule_k_code=>code,:name=>name)
        end
      end
    end
  end

  # load canadia port data from http://www.cbsa-asfc.gc.ca/codes/generic-eng.html, must be modified to make tab separated file
  # you must clean up encoding issues before processing
  def self.load_cbsa_data data
    Port.transaction do
      data.lines do |row|
        ary = row.split("\t")
        p = Port.find_by_cbsa_port ary[0]
        #do nothing if port is found
        next if p || ary[0].blank? || ary[1].blank? || ary[2].blank?
        Port.create!(:name=>ary[2].strip,:cbsa_port=>ary[0].strip,:cbsa_sublocation=>ary[1].strip)
      end
    end
  end
end
