class Port < ActiveRecord::Base

  validates :schedule_k_code, :format => {:with=>/^[0-9]{5}$/,:message=>"Schedule K code must be 5 digits.", :if=>:schedule_k_code?}
  validates :schedule_d_code, :format => {:with=>/^[0-9]{4}$/,:message=>"Schedule D code must be 4 digits.", :if=>:schedule_d_code?} 
  validates :cbsa_port, :format => {:with=>/^[0-9]{4}$/, :message=>"CBSA Port code must be 4 digits", :if=>:cbsa_port?}
  validates :cbsa_sublocation, :format => {:with=>/^[0-9]{4}$/, :message=>"CBSA Sublocation code must be 4 digits", :if=>:cbsa_sublocation?}
  validates :unlocode, :format => {:with=>/^[A-Z]{5}$/, :message=>"UN/LOCODE must be 5 upper case letters", :if=>:unlocode?}

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
  def self.load_cbsa_data data
    Port.transaction do
      data.lines do |row|
        ary = row.split("\t")
        p = Port.find_by_cbsa_port ary[0]
        #do nothing if port is found
        next if p
        Port.create!(:name=>ary[2].strip,:cbsa_port=>ary[0].strip,:cbsa_sublocation=>ary[1].strip)
      end
    end
  end
end
