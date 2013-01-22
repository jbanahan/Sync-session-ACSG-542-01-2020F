require 'spec_helper'

describe 'time zone parse_us_base_format' do
  before :each do
    @zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end
  it 'should parse an AM time' do
    date = @zone.parse_us_base_format '12/28/2008 04:25am'
    date.should == DateTime.new(2008, 12, 28, 9, 25) #9:25 UTC
  end
  it 'should parse a PM time' do
    date = @zone.parse_us_base_format '12/28/2008 02:22pm'
    date.should == DateTime.new(2008, 12, 28, 19, 22)
  end
  it 'should parse noon' do
    date = @zone.parse_us_base_format '12/28/2008 12:00pm'
    date.should == DateTime.new(2008, 12, 28, 17, 00)
  end
  it 'should parse midnight' do
    date = @zone.parse_us_base_format '12/28/2008 12:00am'
    date.should == DateTime.new(2008, 12, 28, 5, 00)
  end
  it 'should parse a daylight savings time' do
    date = @zone.parse_us_base_format '07/28/2008 04:25am'
    date.should == DateTime.new(2008, 7, 28, 8, 25) #8:25 UTC
  end
  it 'should parse a non-daylight savings time' do
    date = @zone.parse_us_base_format '12/28/2008 04:25am'
    date.should == DateTime.new(2008, 12, 28, 9, 25) #9:25 UTC
  end
  context 'formatting errors' do
    it 'should fail on 1 digit month' do
      @test_date = '6/28/2008 04:25am'
    end
    it 'should fail on 1 digit day' do
      @test_date = '06/8/2008 04:25am'
    end

    it 'should fail on 2 digit year' do
      @test_date = '06/28/08 04:25am'
    end

    it 'should fail on 1 digit hour' do
      @test_date = '06/28/2008 4:25am'
    end

    it 'should fail on 1 digit minute' do
      @test_date = '06/08/2008 04:5am'
    end

    it 'should fail on missing meridian' do
      @test_date = '06/28/2008 04:25'
    end
    after :each do 
      lambda {@zone.parse_us_base_format(@test_date)}.should raise_error ArgumentError
    end
  end
end

describe "hts_format" do
  it 'should format a standard hts number' do
    '1234567890'.hts_format.should == '1234.56.7890'
    # No length validations are done
    '12345678901234'.hts_format.should == '1234.56.78.901234'
    '1234'.hts_format.should == '1234'
    '12345'.hts_format.should == '12345'
    '123456'.hts_format.should == '1234.56'
    '1234567'.hts_format.should == '1234.567'
    '12345678'.hts_format.should == '1234.56.78'
    '123456789'.hts_format.should == '1234.56.789'
    '1234567890'.hts_format.should == '1234.56.7890'
    # Make sure we also allow alpha chars
    '1234Ab789b'.hts_format.should == '1234.Ab.789b'
  end
  it 'should not try to format values that are not hts numbers' do
    # Anything that's not period, numeric, alpha is not an hts number
    '!@#$%%^'.hts_format.should == '!@#$%%^'
  end
end
