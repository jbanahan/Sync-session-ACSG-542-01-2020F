require 'spec_helper'

describe OpenChain::XLClient do

  before :each do 
    @socket = mock "Socket"
    @path = 'somepath'
    @dummy_response = {"my"=>"response"}
    @client = OpenChain::XLClient.new @path, @socket
  end

  it 'should create socket if not supplied' do
    c = OpenChain::XLClient.new(@path)
    def c.sock; @socket; end
    c.sock.should respond_to 'send_string'
    c.sock.close
  end
  it 'should send a command and receive a response hash' do
    cmd = {"some"=>"cmd"}
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    r = @client.send cmd
    r.should == @dummy_response
  end
  it 'should send a new command' do
    cmd = {"command"=>"new","path"=>@path}
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    @client.new
  end
  it 'should send a get cell command' do
    cmd = {"command"=>"get_cell","path"=>@path,"payload"=>{"sheet"=>0,"row"=>1,"column"=>2}}
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    @client.get_cell 0, 1, 2
  end
  describe "set_cell" do
    after :each do
      cmd = {"command"=>"set_cell","path"=>@path,"payload"=>{"position"=>{"sheet"=>0,"row"=>1,"column"=>2},"cell"=>{"value"=>@value_content,"datatype"=>@datatype}}}
      expected_json = cmd.to_json
      @socket.should_receive(:send_string).with(expected_json).and_return(nil)
      @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
      @client.set_cell 0, 1, 2, @value

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
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    @client.create_sheet "a name"
  end
  it 'should send a save command without alternate location' do
    cmd = {"command"=>"save","path"=>@path,"payload"=>{"alternate_location"=>@path}}
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    @client.save
  end
  it 'should send a save command with alternate location' do
    cmd = {"command"=>"save","path"=>@path,"payload"=>{"alternate_location"=>'another/location'}}
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    @client.save 'another/location'
  end
  it 'should get a row' do
    t = Time.now
    cmd = {"command"=>"get_row","path"=>@path,"payload"=>{"sheet"=>0,"row"=>10}}
    expected_json = cmd.to_json
    return_array = [{"position"=>{"sheet"=>0,"row"=>10,"column"=>0},"cell"=>{"value"=>"abc","datatype"=>"string"}},
                    {"position"=>{"sheet"=>0,"row"=>10,"column"=>3},"cell"=>{"value"=>t.to_i,"datatype"=>"datetime"}}]
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(return_array.to_json)
    r = @client.get_row 0, 10
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
      expected_json = cmd.to_json
      @socket.should_receive(:send_string).with(expected_json).and_return(nil)
      @socket.should_receive(:recv_string).and_return({"result"=>10}.to_json)
      @client.last_row_number(0).should == 10
    end
    it 'should raise error' do
      @socket.should_receive(:send_string).and_return(nil)
      @socket.should_receive(:recv_string).and_return({"errors"=>["msg1","msg2"]}.to_json)
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

end
