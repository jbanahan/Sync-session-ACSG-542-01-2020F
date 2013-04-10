# encoding: UTF-8
require 'spec_helper'

describe OpenChain::XLClient do

  before :each do 
    @path = 'somepath'
    @dummy_response = {"my"=>"response"}
    @client = OpenChain::XLClient.new @path
  end

  context "error handling" do
    it "should raise error if raise_errors is enabled" do
      cmd = {"command"=>"new","path"=>@path}
      @client.raise_errors = true
      @client.should_receive(:private_send).with(cmd).and_return("errors"=>["BAD"])
      lambda {@client.send(cmd)}.should raise_error OpenChain::XLClientError
    end
    it "should not raise error if raise_errors is not enabled" do
      cmd = {"command"=>"new","path"=>@path}
      resp = {'errors'=>'BAD'}
      @client.should_receive(:private_send).with(cmd).and_return(resp)
      @client.send(cmd).should == resp
    end
  end
  it 'should send a new command' do
    cmd = {"command"=>"new","path"=>@path}
    @client.should_receive(:send).with(cmd).and_return(@dummy_response)
    @client.new.should == @dummy_response
  end
  it 'should send a get cell command' do
    cmd = {"command"=>"get_cell","path"=>@path,"payload"=>{"sheet"=>0,"row"=>1,"column"=>2}}
    @client.should_receive(:send).with(cmd).and_return(@dummy_response)
    @client.get_cell( 0, 1, 2 ).should == @dummy_response
  end
  describe "set_cell" do
    after :each do
      cmd = {"command"=>"set_cell","path"=>@path,"payload"=>{"position"=>{"sheet"=>0,"row"=>1,"column"=>2},"cell"=>{"value"=>@value_content,"datatype"=>@datatype}}}
      @client.should_receive(:send).with(cmd).and_return(@dummy_response)
      @client.set_cell(  0, 1, 2, @value ).should == @dummy_response

    end
    it 'should handle strings' do
      @value_content = @value = "abcd"
      @datatype = "string"
    end
    it 'should handle Time' do
      @value = Time.now
      @value_content = @value.to_i
      @datatype = "datetime"
    end
    it 'should handle Date' do
      @value = Date.new(2010,11,11)
      @value_content = @value.to_time.to_i
      @datatype = "datetime"
    end
    it 'should handle x ago' do
      @value = 3.seconds.ago
      @value_content = @value.to_i
      @datatype = "datetime"
    end
    it 'should handle numbers' do
      @value_content = @value = 10.4
      @datatype = "number"
    end
  end
  it 'should send a create_sheet command' do
    cmd = {"command"=>"create_sheet","path"=>@path,"payload"=>{"name"=>"a name"}}
    @client.should_receive(:send).with(cmd).and_return(@dummy_response)
    @client.create_sheet(  "a name" ).should == @dummy_response
  end
  it 'should send a save command without alternate location' do
    cmd = {"command"=>"save","path"=>@path,"payload"=>{"alternate_location"=>@path}}
    @client.should_receive(:send).with(cmd).and_return(@dummy_response)
    @client.save.should == @dummy_response
  end
  it 'should send a save command with alternate location' do
    cmd = {"command"=>"save","path"=>@path,"payload"=>{"alternate_location"=>'another/location'}}
    @client.should_receive(:send).with(cmd).and_return(@dummy_response)
    @client.save(  'another/location' ).should == @dummy_response
  end
  it 'should copy a row' do
    cmd = {"command"=>"copy_row","path"=>@path,"payload"=>{"sheet"=>0,"source_row"=>1,"destination_row"=>3}}
    @client.should_receive(:send).with(cmd).and_return(@dummy_response)
    @client.should_receive(:process_row_response).with(@dummy_response).and_return(@dummy_response)
    @client.copy_row 0, 1, 3
  end
  it 'should get a row as column hash' do
    t = Time.now
    row_response = [{"position"=>{"sheet"=>0,"row"=>10,"column"=>0},"cell"=>{"value"=>"abc","datatype"=>"string"}},
                    {"position"=>{"sheet"=>0,"row"=>10,"column"=>3},"cell"=>{"value"=>t.to_i,"datatype"=>"datetime"}}]
    expected_val = {0=>{"value"=>"abc","datatype"=>"string"},3=>{"value"=>t.to_i,"datatype"=>"datetime"}}
    @client.should_receive(:get_row).with(0,1).and_return(row_response)
    @client.get_row_as_column_hash(0,1).should == expected_val
  end
  it 'should get a row' do
    t = Time.now
    cmd = {"command"=>"get_row","path"=>@path,"payload"=>{"sheet"=>0,"row"=>10}}
    return_array = [{"position"=>{"sheet"=>0,"row"=>10,"column"=>0},"cell"=>{"value"=>"abc","datatype"=>"string"}},
                    {"position"=>{"sheet"=>0,"row"=>10,"column"=>3},"cell"=>{"value"=>t.to_i,"datatype"=>"datetime"}}]
    @client.should_receive(:send).with(cmd).and_return(return_array)
    r = @client.get_row(0, 10 )
    r.should have(2).results
    first_cell = r[0]
    first_cell['position']['column'].should == 0
    first_cell['cell']['value'].should == "abc"
    first_cell['cell']['datatype'].should == "string"
    second_cell = r[1]
    second_cell['position']['column'].should == 3
    second_cell['cell']['value'].to_i.should == t.to_i
    second_cell['cell']['datatype'].should == "datetime"
  end
  describe 'last_row_number' do
    it 'should return the integer response' do
      cmd = {"command"=>"last_row_number","path"=>@path,"payload"=>{"sheet_index"=>0}}
      @client.should_receive(:send).with(cmd).and_return({'result'=>10})
      @client.last_row_number(0).should == 10
    end
    it 'should raise error' do
      err = {"errors"=>["msg1","msg2"]}
      @client.should_receive(:send).and_return(err)
      lambda {@client.last_row_number(0)}.should raise_error "msg1\nmsg2"
    end
  end

  describe 'find_cell_in_row' do
    before :each do 
      @row = [{"position"=>{"sheet"=>0,"row"=>10,"column"=>0},"cell"=>{"value"=>"abc","datatype"=>"string"}},
              {"position"=>{"sheet"=>0,"row"=>10,"column"=>3},"cell"=>{"value"=>Time.now,"datatype"=>"datetime"}}]
    end
    it 'should find a cell' do
      expected = {"value"=>"abc","datatype"=>"string"}
      r = OpenChain::XLClient.find_cell_in_row @row, 0
      r["value"].should == "abc"
      r["datatype"].should == "string"
    end
    it 'should return nil for missing cell' do
      OpenChain::XLClient.find_cell_in_row(@row,1).should be_nil
    end
  end

  describe 'charset handling in send' do
    it 'should specify application/json and UTF-8 charset as Content-Type in the request and parse response charset' do
      command = {"test" => "test"}
      uri = URI("#{YAML.load(IO.read('config/xlserver.yml'))[Rails.env]['base_url']}/process")
      
      #Mock out the actual Net::HTTP stuff (since we don't have an actual mock http server to run)
      http = double("Net::HTTP")
      Net::HTTP.should_receive(:start).with(uri.host, uri.port).and_yield http
      http.should_receive(:read_timeout=).with 600

      response = double("response")
      # The response_body simulates the actual response string sent back by the server
      # Which is actually a UTF-8 character stream , but Net::HTTP 
      # won't automatically set it as so and leaves the body encoding 
      # as Binary (hence the setting here).  Binary is the default encoding for anything read
      # from a socket.
      response_body = '{"response": "31¢"}'.force_encoding Encoding::BINARY
      response.stub(:body).and_return response_body

      http.should_receive(:request) do |request|
        request['Content-Type'].should == "application/json; charset=#{command.to_json.encoding.to_s}"
        request.body.should == command.to_json
        response
      end

      # Make sure the correct response encoding is read and set
      # This is the expected response content-type from the xlserver
      ct = "application/json; charset=UTF-8"
      response.should_receive(:[]).with('content-type').and_return ct

      r = @client.send command

      # response_body should have been forced to UTF-8 encoding since that's the content type
      # charset sent in of the response (it's originally set to binary above)
      response_body.encoding.to_s.should == "UTF-8"
      r['response'].should == "31¢"
    end

    it 'should handle missing charset in response' do 
      response = double("response")
      Net::HTTP.should_receive(:start).and_return response
      response.should_receive(:[]).with('content-type').and_return 'application/json'
      response_body = '{"response": "31¢"}'.force_encoding Encoding::BINARY
      response.stub(:body).and_return response_body

      r = @client.send({"test" => "test"})

      # The response charset should just be left alone
      response_body.encoding.to_s.should == Encoding::BINARY.to_s
    end

    it 'should handle invalid charsets by leaving encoding as binary' do
      response = double("response")
      Net::HTTP.should_receive(:start).and_return response
      response.should_receive(:[]).with('content-type').and_return 'application/json; charset=My-NonExistant-Charset'
      response_body = '{"response": "31¢"}'.force_encoding Encoding::BINARY
      response.stub(:body).and_return response_body

      r = @client.send({"test" => "test"})

      # The response charset should just be left alone
      response_body.encoding.to_s.should == Encoding::BINARY.to_s
    end
  end

end
