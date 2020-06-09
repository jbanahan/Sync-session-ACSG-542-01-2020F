describe OpenChain::XLClient do

  subject { described_class.new "somepath", {scheme: "s3", bucket: "bucket"} }

  let! (:master_setup) do
    ms = stub_master_setup
    allow(MasterSetup).to receive(:secrets).and_return xl_config
    ms
  end

  let (:xl_config) do
    {
      "xl_server" => {
        "base_url" => "http://localhost:22001"
      }
    }
  end
  let (:error_response) { {"errors" => "Error"} }
  let (:dummy_response) { {"cell" => {"my" => "response"}} }
  let (:init_path) { 'somepath' }
  let (:path) { "s3://bucket.s3.amazonaws.com/somepath" }

  describe "initialize" do
    it "modifies plain paths to an s3 one" do
      c = described_class.new "whatever/file.txt"
      expect(c.path).to eq "s3://#{Rails.configuration.paperclip_defaults[:bucket]}.s3.amazonaws.com/whatever/file.txt"
    end

    it "accepts URI as a path and doesn't change it" do
      c = described_class.new "scheme://whatever/file.txt"
      expect(c.path).to eq "scheme://whatever/file.txt"
    end

    it "uses passed in scheme" do
      c = described_class.new "whatever/file.txt", scheme: "blah", bucket: "argh"
      expect(c.path).to eq "blah:///whatever/file.txt"
    end

    it "uses passed in bucket with s3 schemes" do
      c = described_class.new "whatever/file.txt", bucket: "argh"
      expect(c.path).to eq "s3://argh.s3.amazonaws.com/whatever/file.txt"
    end
  end

  context "error handling" do
    it "raises error if raise_errors is enabled" do
      cmd = {"command" => "new", "path" => path}
      subject.raise_errors = true
      expect(subject).to receive(:send_command).with(cmd).and_return("errors" => ["BAD"])
      expect {subject.send(cmd)}.to raise_error OpenChain::XLClientError
    end

    it "does not raise error if raise_errors is not enabled" do
      cmd = {"command" => "new", "path" => path}
      resp = {'errors' => 'BAD'}
      expect(subject).to receive(:send_command).with(cmd).and_return(resp)
      expect(subject.send(cmd)).to eq(resp)
    end
  end

  describe "new_from_attachable" do
    it "initializes with attached path" do
      attachable = instance_double(Attachment)
      attached = instance_double(Paperclip::Attachment)
      expect(attachable).to receive(:attached).and_return(attached)
      expect(attached).to receive(:path).and_return 'mypath'
      x = described_class.new('mypath')
      expect(described_class).to receive(:new).with('mypath').and_return(x)
      expect(described_class.new_from_attachable(attachable)).to be x
    end
  end

  describe "all_row_values" do
    it "yields for all rows based on last_row_number" do
      expect(subject).to receive(:last_row_number).with(0).and_return(2)
      expect(subject).to receive(:get_rows).with(row: 0, sheet: 0, number_of_rows: 1).and_return([['a']])
      expect(subject).to receive(:get_rows).with(row: 1, sheet: 0, number_of_rows: 1).and_return([['b']])
      expect(subject).to receive(:get_rows).with(row: 2, sheet: 0, number_of_rows: 1).and_return([['c']])
      v = []
      subject.all_row_values(sheet_number: 0, starting_row_number: 0, chunk_size: 1) do |r|
        v << r
      end
      expect(v).to eq [['a'], ['b'], ['c']]
    end

    it "returns array of arrays if no block given" do
      expect(subject).to receive(:last_row_number).with(0).and_return(2)
      expect(subject).to receive(:get_rows).with(row: 0, sheet: 0, number_of_rows: 1).and_return([['a']])
      expect(subject).to receive(:get_rows).with(row: 1, sheet: 0, number_of_rows: 1).and_return([['b']])
      expect(subject).to receive(:get_rows).with(row: 2, sheet: 0, number_of_rows: 1).and_return([['c']])
      v = subject.all_row_values(sheet_number: 0, starting_row_number: 0, chunk_size: 1)
      expect(v).to eq [['a'], ['b'], ['c']]
    end

    it "steps does not over-request rows" do
      # returning 10 here means there's actually 11 rows of data to grab
      expect(subject).to receive(:last_row_number).with(0).and_return(10)
      expect(subject).to receive(:get_rows).with(row: 0, sheet: 0, number_of_rows: 3).and_return([['a']])
      expect(subject).to receive(:get_rows).with(row: 3, sheet: 0, number_of_rows: 3).and_return([['b']])
      expect(subject).to receive(:get_rows).with(row: 6, sheet: 0, number_of_rows: 3).and_return([['c']])
      expect(subject).to receive(:get_rows).with(row: 9, sheet: 0, number_of_rows: 2).and_return([['d']])
      v = subject.all_row_values(sheet_number: 0, starting_row_number: 0, chunk_size: 3)
      expect(v).to eq [['a'], ['b'], ['c'], ['d']]
    end

    it "stops polling for more rows if stop_polling is thrown from block" do
      expect(subject).to receive(:last_row_number).with(0).and_return(10)
      expect(subject).to receive(:get_rows).with(row: 0, sheet: 0, number_of_rows: 3).and_return([['a']])
      subject.all_row_values(sheet_number: 0, starting_row_number: 0, chunk_size: 3) do |row|
        expect(row).to eq ["a"]
        throw :stop_polling
      end
    end
  end

  it 'sends a new command' do
    cmd = {"command" => "new", "path" => path}
    expect(subject).to receive(:send).with(cmd).and_return(dummy_response)
    expect(subject.new).to eq(dummy_response)
  end

  it 'sends a get cell command' do
    cell_response = {"cell" => {"value" => "val", "datatype" => "string"}}
    cmd = {"command" => "get_cell", "path" => path, "payload" => {"sheet" => 0, "row" => 1, "column" => 2}}
    expect(subject).to receive(:send).with(cmd).and_return(cell_response)
    expect(subject.get_cell(0, 1, 2)).to eq("val")
  end

  it 'sends a get cell command and return raw response' do
    cmd = {"command" => "get_cell", "path" => path, "payload" => {"sheet" => 0, "row" => 1, "column" => 2}}
    expect(subject).to receive(:send).with(cmd).and_return(dummy_response)
    expect(subject.get_cell(0, 1, 2, false)).to eq(dummy_response["cell"])
  end

  it 'sends a get cell command and handle errors' do
    cell_response = {"errors" => ["Error 1", "Error 2"]}
    cmd = {"command" => "get_cell", "path" => path, "payload" => {"sheet" => 0, "row" => 1, "column" => 2}}
    expect(subject).to receive(:send).with(cmd).and_return(cell_response)
    expect {subject.get_cell(0, 1, 2)}.to raise_error "Error 1\nError 2"
  end

  it "sends a get cell command and handle datetime translation" do
    now = Time.zone.now
    cell_response = {"cell" => {"value" => now.to_i, "datatype" => "datetime"}}
    cmd = {"command" => "get_cell", "path" => path, "payload" => {"sheet" => 0, "row" => 1, "column" => 2}}
    expect(subject).to receive(:send).with(cmd).and_return(cell_response)
    expect(subject.get_cell(0, 1, 2)).to eq(Time.zone.at(now.to_i))
  end

  describe "set_cell" do

    def command value_content, datatype
      {"command" => "set_cell", "path" => path, "payload" =>
          {"position" => {"sheet" => 0, "row" => 1, "column" => 2}, "cell" => {"value" => value_content, "link" => nil, "datatype" => datatype}}}
    end

    it 'handles strings' do
      expect(subject).to receive(:send).with(command("abcd", "string")).and_return(dummy_response)
      expect(subject.set_cell(0, 1, 2, "abcd")).to eq(dummy_response)
    end

    it 'handles Time' do
      now = Time.zone.now
      expect(subject).to receive(:send).with(command(now.to_i, "datetime")).and_return(dummy_response)
      expect(subject.set_cell(0, 1, 2, now)).to eq(dummy_response)
    end

    it 'handles Date' do
      value = Date.new(2010, 11, 11)
      expect(subject).to receive(:send).with(command(value.to_time.to_i, "datetime")).and_return(dummy_response)
      expect(subject.set_cell(0, 1, 2, value)).to eq(dummy_response)
    end

    it 'handles numbers' do
      expect(subject).to receive(:send).with(command(10.4, "number")).and_return(dummy_response)
      expect(subject.set_cell(0, 1, 2, 10.4)).to eq(dummy_response)
    end
  end

  it 'sends a create_sheet command' do
    cmd = {"command" => "create_sheet", "path" => path, "payload" => {"name" => "a name"}}
    expect(subject).to receive(:send).with(cmd).and_return(dummy_response)
    expect(subject.create_sheet("a name")).to eq(dummy_response)
  end

  it 'sends a save command without alternate location' do
    cmd = {"command" => "save", "path" => path, "payload" => {"alternate_location" => path}}
    expect(subject).to receive(:send).with(cmd).and_return(dummy_response)
    expect(subject.save).to eq(dummy_response)
  end

  it 'sends a save command with alternate location' do
    cmd = {"command" => "save", "path" => path, "payload" => {"alternate_location" => 's3://bucket.s3.amazonaws.com/another/location'}}
    expect(subject).to receive(:send).with(cmd).and_return(dummy_response)
    expect(subject.save('another/location')).to eq(dummy_response)
  end

  it 'sends a save command with alternate location using a URI' do
    cmd = {"command" => "save", "path" => path, "payload" => {"alternate_location" => 'file:///another/location'}}
    expect(subject).to receive(:send).with(cmd).and_return(dummy_response)
    expect(subject.save('file:///another/location')).to eq(dummy_response)
  end

  it 'copies a row' do
    cmd = {"command" => "copy_row", "path" => path, "payload" => {"sheet" => 0, "source_row" => 1, "destination_row" => 3}}
    expect(subject).to receive(:send).with(cmd).and_return(dummy_response)
    expect(subject).to receive(:process_row_response).with(dummy_response).and_return(dummy_response)
    subject.copy_row 0, 1, 3
  end

  it 'gets a row as column hash' do
    t = Time.zone.now
    row_response = [{"position" => {"sheet" => 0, "row" => 10, "column" => 0}, "cell" => {"value" => "abc", "datatype" => "string"}},
                    {"position" => {"sheet" => 0, "row" => 10, "column" => 3}, "cell" => {"value" => t.to_i, "datatype" => "datetime"}}]
    expected_val = {0 => {"value" => "abc", "datatype" => "string"}, 3 => {"value" => Time.zone.at(t.to_i), "datatype" => "datetime"}}
    expect(subject).to receive(:get_row).with(0, 1).and_return(row_response)
    expect(subject.get_row_as_column_hash(0, 1)).to eq(expected_val)
  end

  it 'gets a row' do
    t = Time.zone.now
    cmd = {"command" => "get_row", "path" => path, "payload" => {"sheet" => 0, "row" => 10}}
    return_array = [{"position" => {"sheet" => 0, "row" => 10, "column" => 0}, "cell" => {"value" => "abc", "datatype" => "string"}},
                    {"position" => {"sheet" => 0, "row" => 10, "column" => 3}, "cell" => {"value" => t.to_i, "datatype" => "datetime"}}]
    expect(subject).to receive(:send).with(cmd).and_return(return_array)
    r = subject.get_row(0, 10)
    expect(r.size).to eq(2)
    first_cell = r[0]
    expect(first_cell['position']['column']).to eq(0)
    expect(first_cell['cell']['value']).to eq("abc")
    expect(first_cell['cell']['datatype']).to eq("string")
    second_cell = r[1]
    expect(second_cell['position']['column']).to eq(3)
    expect(second_cell['cell']['value']).to eq(Time.zone.at(t.to_i))
    expect(second_cell['cell']['datatype']).to eq("datetime")
  end

  it "returns a row's cell values as an array" do
    t = Time.zone.now
    cmd = {"command" => "get_row", "path" => path, "payload" => {"sheet" => 0, "row" => 10}}
    return_array = [{"position" => {"sheet" => 0, "row" => 10, "column" => 0}, "cell" => {"value" => "abc", "datatype" => "string"}},
                    {"position" => {"sheet" => 0, "row" => 10, "column" => 3}, "cell" => {"value" => t.to_i, "datatype" => "datetime"}}]
    expect(subject).to receive(:send).with(cmd).and_return(return_array)
    r = subject.get_row_values(0, 10)
    expect(r).to eq(["abc", nil, nil, Time.zone.at(t.to_i)])
  end

  it "returns empty array if get_row_as_column_hash returns empty hash" do
    expect(subject).to receive(:get_row).with(0, 10).and_return({})
    expect(subject.get_row_values(0, 10)).to eq([])
  end

  describe 'last_row_number' do
    it 'returns the integer response' do
      cmd = {"command" => "last_row_number", "path" => path, "payload" => {"sheet_index" => 0}}
      expect(subject).to receive(:send).with(cmd).and_return({'result' => 10})
      expect(subject.last_row_number(0)).to eq(10)
    end

    it 'raises error' do
      err = {"errors" => ["msg1", "msg2"]}
      expect(subject).to receive(:send).and_return(err)
      expect {subject.last_row_number(0)}.to raise_error "msg1\nmsg2"
    end
  end

  describe 'find_cell_in_row' do
    let (:row) do
      [{"position" => {"sheet" => 0, "row" => 10, "column" => 0}, "cell" => {"value" => "abc", "datatype" => "string"}},
       {"position" => {"sheet" => 0, "row" => 10, "column" => 3}, "cell" => {"value" => Time.zone.now, "datatype" => "datetime"}}]
    end

    it 'finds a cell' do
      r = described_class.find_cell_in_row row, 0
      expect(r["value"]).to eq("abc")
      expect(r["datatype"]).to eq("string")
    end

    it 'returns nil for missing cell' do
      expect(described_class.find_cell_in_row(row, 1)).to be_nil
    end
  end

  describe 'charset handling in send' do
    it 'specifies application/json and UTF-8 charset as Content-Type in the request and parse response charset' do
      command = {"test" => "test"}
      uri = URI("http://test/process")
      expect(subject).to receive(:request_uri).and_return uri

      # Mock out the actual Net::HTTP stuff (since we don't have an actual mock http server to run)
      http = instance_double(Net::HTTP)
      expect(Net::HTTP).to receive(:start).with(uri.host, uri.port).and_yield http
      expect(http).to receive(:read_timeout=).with 600

      response = instance_double(Net::HTTPResponse)
      # The response_body simulates the actual response string sent back by the server
      # Which is actually a UTF-8 character stream , but Net::HTTP
      # won't automatically set it as so and leaves the body encoding
      # as Binary (hence the setting here).  Binary is the default encoding for anything read
      # from a socket.
      response_body = '{"response": "31¢"}'.force_encoding Encoding::BINARY
      allow(response).to receive(:body).and_return response_body

      expect(http).to receive(:request) do |request|
        expect(request['Content-Type']).to eq("application/json; charset=#{command.to_json.encoding}")
        expect(request.body).to eq(command.to_json)
        response
      end

      # Make sure the correct response encoding is read and set
      # This is the expected response content-type from the xlserver
      ct = "application/json; charset=UTF-8"
      expect(response).to receive(:[]).with('content-type').and_return ct

      r = subject.send command

      # response_body should have been forced to UTF-8 encoding since that's the content type
      # charset sent in of the response (it's originally set to binary above)
      expect(response_body.encoding.to_s).to eq("UTF-8")
      expect(r['response']).to eq("31¢")
    end

    it 'handles missing charset in response' do
      response = instance_double(Net::HTTPResponse)
      expect(Net::HTTP).to receive(:start).and_return response
      expect(response).to receive(:[]).with('content-type').and_return 'application/json'
      response_body = '{"response": "31¢"}'.force_encoding Encoding::BINARY
      allow(response).to receive(:body).and_return response_body

      expect(JSON).to receive(:parse) do |body|
        expect(body.encoding.to_s).to eq(Encoding::BINARY.to_s)
      end

      subject.send({"test" => "test"})
    end

    it 'handles invalid charsets by leaving encoding as binary' do
      response = instance_double(Net::HTTPResponse)
      expect(Net::HTTP).to receive(:start).and_return response
      expect(response).to receive(:[]).with('content-type').and_return 'application/json; charset=My-NonExistant-Charset'
      response_body = '{"response": "31¢"}'.force_encoding Encoding::BINARY
      allow(response).to receive(:body).and_return response_body

      expect(JSON).to receive(:parse) do |body|
        expect(body.encoding.to_s).to eq(Encoding::BINARY.to_s)
      end

      subject.send({"test" => "test"})
    end
  end

  describe "string_value" do

    it "converts numeric values to string, trimming trailing zeros" do
      expect(described_class.string_value(123.0)).to eq "123"
      expect(described_class.string_value(BigDecimal("123.0"))).to eq "123"
      expect(described_class.string_value(123)).to eq "123"

      expect(described_class.string_value(123.10)).to eq "123.1"
      expect(described_class.string_value(BigDecimal("123.10"))).to eq "123.1"
    end

    it "passthroughs string values" do
      # It shouldn't even touch string objects - straight pass-through
      a = "1"
      expect(described_class.string_value(a)).to be a
    end

    it "to_ses non-Numeric/non-String values" do
      expect(described_class.string_value(Date.new(2013, 8, 10))).to eq Date.new(2013, 8, 10).to_s
      expect(described_class.string_value({test: "test"})).to eq({test: "test"}.to_s)
    end
  end

  describe "clone_sheet" do
    it "sends clone_sheet command" do
      expect(subject).to receive(:send).with({"command" => "clone_sheet", "path" => path, "payload" => {"source_index" => 1}}).and_return({'sheet_index' => 10})
      expect(subject.clone_sheet(1)).to eq 10
    end

    it "sends clone_sheet command with sheet name" do
      expect(subject).to receive(:send).with({"command" => "clone_sheet", "path" => path, "payload" => {"source_index" => 1, "name" => "Sheet Name"}})
                                       .and_return({'sheet_index' => 2})
      expect(subject.clone_sheet(1, "Sheet Name")).to eq 2
    end

    it "raises an error if errors are returned" do
      expect(subject).to receive(:send).with({"command" => "clone_sheet", "path" => path, "payload" => {"source_index" => 1}}).and_return error_response
      expect {subject.clone_sheet 1}.to raise_error "Error"
    end
  end

  describe "delete_sheet" do
    it "sends delete sheet command" do
      expect(subject).to receive(:send).with({"command" => "delete_sheet", "path" => path, "payload" => {"index" => 1}})
      expect(subject.delete_sheet(1)).to be_nil
    end

    it "handles error responses" do
      expect(subject).to receive(:send).and_return error_response
      expect {subject.delete_sheet 1}.to raise_error "Error"
    end
  end

  describe "delete_sheet_by_name" do
    it "sends delete sheet command" do
      expect(subject).to receive(:send).with({"command" => "delete_sheet", "path" => path, "payload" => {"name" => "Sheet Name"}})
      expect(subject.delete_sheet_by_name('Sheet Name')).to be_nil
    end

    it "handles error responses" do
      expect(subject).to receive(:send).and_return error_response
      expect {subject.delete_sheet_by_name 'Sheet Name'}.to raise_error "Error"
    end
  end

  describe "set_row_color" do
    it "sends correct command" do
      expect(subject).to receive(:send).with({"command" => 'set_color', "path" => path, "payload" => {"position" => {"sheet" => 0, "row" => 1}, "color" => "BLUE"}})
                                       .and_return({"result" => "success"})
      subject.set_row_color 0, 1, "blue"
    end

    it "handles errors" do
      expect(subject).to receive(:send).with({"command" => 'set_color', "path" => path, "payload" => {"position" => {"sheet" => 0, "row" => 1}, "color" => "BLUE"}})
                                       .and_return error_response
      expect {subject.set_row_color 0, 1, "blue"}.to raise_error "Error"
    end
  end

  describe "set_cell_color" do
    it "sends correct command" do
      expect(subject).to receive(:send).with({"command" => 'set_color', "path" => path,
                                              "payload" => {"position" => {"sheet" => 0, "row" => 1, "column" => 2}, "color" => "BLUE"}})
                                       .and_return({"result" => "success"})
      subject.set_cell_color 0, 1, 2, "blue"
    end

    it "handles errors" do
      expect(subject).to receive(:send).with({"command" => 'set_color',
                                              "path" => path,
                                              "payload" => {"position" =>
                                                {"sheet" => 0, "row" => 1, "column" => 2}, "color" => "BLUE"}})
                                       .and_return error_response
      expect {subject.set_cell_color 0, 1, 2, "blue"}.to raise_error "Error"
    end
  end

end
