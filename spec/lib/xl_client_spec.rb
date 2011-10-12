require 'spec_helper'

describe OpenChain::XLClient do

  before :each do 
    @socket = mock "Socket"
    @path = 'somepath'
    @dummy_response = {"my"=>"response"}
  end

  it 'should send a command and receive a response hash' do
    cmd = {"some"=>"cmd"}
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    r = OpenChain::XLClient.new(@socket,@path).send cmd
    r.should == @dummy_response
  end
  it 'should send a new command' do
    cmd = {"command"=>"new","path"=>@path}
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    OpenChain::XLClient.new(@socket,@path).new
  end
  it 'should send a get cell command' do
    cmd = {"command"=>"get_cell","path"=>@path,"payload"=>{"sheet"=>0,"row"=>1,"column"=>2}}
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    OpenChain::XLClient.new(@socket,@path).get_cell 0, 1, 2
  end
  it 'should send a set cell command' do
    cmd = {"command"=>"set_cell","path"=>@path,"payload"=>{"position"=>{"sheet"=>0,"row"=>1,"column"=>2},"cell"=>{"value"=>'abcd',"datatype"=>"string"}}}
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    OpenChain::XLClient.new(@socket,@path).set_cell 0, 1, 2, 'abcd', 'string'
  end
  it 'should send a create_sheet command' do
    cmd = {"command"=>"create_sheet","path"=>@path,"payload"=>{"name"=>"a name"}}
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    OpenChain::XLClient.new(@socket,@path).create_sheet "a name"
  end
  it 'should send a save command without alternate location' do
    cmd = {"command"=>"save","path"=>@path,"payload"=>{"alternate_location"=>@path}}
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    OpenChain::XLClient.new(@socket,@path).save
  end
  it 'should send a save command with alternate location' do
    cmd = {"command"=>"save","path"=>@path,"payload"=>{"alternate_location"=>'another/location'}}
    expected_json = cmd.to_json
    @socket.should_receive(:send_string).with(expected_json).and_return(nil)
    @socket.should_receive(:recv_string).and_return(@dummy_response.to_json)
    OpenChain::XLClient.new(@socket,@path).save 'another/location'
  end

end
