describe 'time zone parse_us_base_format' do
  before :each do
    @zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end
  it 'should parse an AM time' do
    date = @zone.parse_us_base_format '12/28/2008 04:25am'
    expect(date).to eq(DateTime.new(2008, 12, 28, 9, 25)) #9:25 UTC
  end
  it 'should parse a PM time' do
    date = @zone.parse_us_base_format '12/28/2008 02:22pm'
    expect(date).to eq(DateTime.new(2008, 12, 28, 19, 22))
  end
  it 'should parse noon' do
    date = @zone.parse_us_base_format '12/28/2008 12:00pm'
    expect(date).to eq(DateTime.new(2008, 12, 28, 17, 00))
  end
  it 'should parse midnight' do
    date = @zone.parse_us_base_format '12/28/2008 12:00am'
    expect(date).to eq(DateTime.new(2008, 12, 28, 5, 00))
  end
  it 'should parse a daylight savings time' do
    date = @zone.parse_us_base_format '07/28/2008 04:25am'
    expect(date).to eq(DateTime.new(2008, 7, 28, 8, 25)) #8:25 UTC
  end
  it 'should parse a non-daylight savings time' do
    date = @zone.parse_us_base_format '12/28/2008 04:25am'
    expect(date).to eq(DateTime.new(2008, 12, 28, 9, 25)) #9:25 UTC
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
      expect {@zone.parse_us_base_format(@test_date)}.to raise_error ArgumentError
    end
  end
end

describe "hts_format" do
  it 'should format a standard hts number' do
    expect('1234567890'.hts_format).to eq('1234.56.7890')
    # No length validations are done
    expect('12345678901234'.hts_format).to eq('1234.56.78.901234')
    expect('1234'.hts_format).to eq('1234')
    expect('12345'.hts_format).to eq('12345')
    expect('123456'.hts_format).to eq('1234.56')
    expect('1234567'.hts_format).to eq('1234.567')
    expect('12345678'.hts_format).to eq('1234.56.78')
    expect('123456789'.hts_format).to eq('1234.56.789')
    expect('1234567890'.hts_format).to eq('1234.56.7890')
    # Make sure we also allow alpha chars
    expect('1234Ab789b'.hts_format).to eq('1234.Ab.789b')
  end
  it 'should not try to format values that are not hts numbers' do
    # Anything that's not period, numeric, alpha is not an hts number
    expect('!@#$%%^'.hts_format).to eq('!@#$%%^')
  end
end

describe "log_me" do

  it "delays an email send if log_me call has no attachments" do
    m = double("OpenMailer")
    expect(OpenMailer).to receive(:send_generic_exception) do |exception, messages, message, backtrace| 
      expect(exception).to eq "StandardError"
      expect(messages.first).to eq "Testing"
      expect(messages.second).to match "Error Database ID: "
      expect(message).to eq "Testing"
      expect(backtrace).to be_a(Array)
      m
    end
    expect(m).to receive(:deliver_later)

    begin
      raise StandardError, "Testing"
    rescue => e
      e.log_me ["Testing"]
    end
  end

  it "immediately sends exception if attachment paths has a value" do
    mail = double("mail")
    expect(OpenMailer).to receive(:send_generic_exception) do |exception, messages, message, backtrace, files| 
      expect(exception).to eq "StandardError"
      expect(messages.first).to eq "Testing"
      expect(messages.second).to match "Error Database ID: "
      expect(message).to eq "Testing"
      expect(backtrace).to be_a(Array)
      expect(files).to eq ["Attachment Path"]
      mail
    end

    expect(mail).to receive(:deliver_now)

    begin
      raise StandardError, "Testing"
    rescue => e
      e.log_me ["Testing"], ["Attachment Path"]
    end
  end

  it "immediately sends exception if send_now is true" do
    mail = double("mail")
    expect(OpenMailer).to receive(:send_generic_exception).and_return mail
    expect(mail).to receive(:deliver_now)

    begin
      raise StandardError, "Testing"
    rescue => e
      e.log_me ["Testing"], [], true
    end
  end

  describe "deep_dup" do
    # This just verifies that hashes + arrays are deep_dup'ed correctly
    # This was an error that we monkey-patched in Rails 3 (shouldn't be needed in Rails 4)
    it "correctly deep_dups hashes with arrays in them" do
      orig = {'key' => [{'inner_key' => 'inner_value'}]}
      orig_dupe = orig.deep_dup
      orig_dupe['key'][0]['new_key'] = 'new_value'
      expect(orig['key'][0]['new_key']).to be_nil
    end
  end
end

describe "to_boolean" do

  ["true", "tRuE", "1", "T", "on"].each do |v|
    it "handles '#{v}' value as true" do
      expect(v.to_boolean).to eq true
    end
  end

  ["false", "somethingelse"].each do |v|
    it "handles '#{v}' value as false" do
      expect(v.to_boolean).to eq false
    end
  end
end
