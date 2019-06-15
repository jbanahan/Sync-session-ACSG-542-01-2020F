describe OpenChain::KewillSqlProxyClient do
  before :each do
    @http_client = double("MockHttpClient")
    @c = described_class.new @http_client
    @proxy_config = {'auth_token' => "config_auth_token", "url" => "config_url"}
    allow(described_class).to receive(:proxy_config).and_return(@proxy_config)
  end


  describe "request_alliance_invoice_details" do
    it "requests invoice details from alliance" do
      request_context = {'content' => 'context'}
      request_body = {'job_params' => {:file_number=>123, :suffix=>"suffix"}, 'context' => request_context}
      expect(@http_client).to receive(:post).with("#{@proxy_config['url']}/job/invoice_details", request_body, {}, @proxy_config['auth_token'])
      
      @c.request_alliance_invoice_details "123", "suffix     ", request_context
    end

    it "strips blank suffixes down to blank string" do
      request_body = {'job_params' => {:file_number=>123, :suffix=>' '}}
      expect(@http_client).to receive(:post).with("#{@proxy_config['url']}/job/invoice_details", request_body, {}, @proxy_config['auth_token'])

      @c.request_alliance_invoice_details "123", "     "
    end

    it "doesn't send context if a blank one is provided" do
      request_body = {'job_params' => {:file_number=>123, :suffix=>'A'}}
      expect(@http_client).to receive(:post).with("#{@proxy_config['url']}/job/invoice_details", request_body, {}, @proxy_config['auth_token'])

      @c.request_alliance_invoice_details "123", "A"
    end

    it "raises error on errored post" do
      expect(@http_client).to receive(:post).and_raise "Error"
      expect{@c.request_alliance_invoice_details "123", "A"}.to raise_error "Error"
    end
  end

  describe "request_alliance_invoice_numbers_since" do
    it "requests invoice numbers since given date" do
      request_body = {'job_params' => {:invoice_date=>20140101}}
      expect(@http_client).to receive(:post).with("#{@proxy_config['url']}/job/find_invoices", request_body, {}, @proxy_config['auth_token'])

      @c.request_alliance_invoice_numbers_since Date.new(2014,1,1)
    end
  end

  describe "request_check_details" do
    it "requests check details" do
      request_body = {'job_params' => {file_number: 123, check_number: 456, check_date: 20141101, bank_number: 10, check_amount: 101}}

      expect(@http_client).to receive(:post).with("#{@proxy_config['url']}/job/check_details", request_body, {}, @proxy_config['auth_token'])
      @c.request_check_details "123", "456", Date.new(2014, 11, 1), "10", BigDecimal.new("1.01999").to_s
    end

    it "raises error on failed json post" do
      expect(@http_client).to receive(:post).and_raise "Error"
      expect{@c.request_check_details "123", "456", Date.new(2014, 11, 1), "10", BigDecimal.new("123")}.to raise_error "Error"
    end
  end

  describe "request_file_tracking_info" do
    it "requests files between given times" do
      start = Time.zone.now
      end_t = start + 1.hour

      request_body = {'job_params' => {start_date: start.strftime("%Y%m%d").to_i, end_date: end_t.strftime("%Y%m%d").to_i, end_time: end_t.strftime("%Y%m%d%H%M").to_i}, 'context'=>{results_as_array: true}}
      expect(@http_client).to receive(:post).with("#{@proxy_config['url']}/job/file_tracking", request_body, {}, @proxy_config['auth_token'])

      @c.request_file_tracking_info start, end_t
    end
  end

  describe "request_updated_entry_numbers" do
    it "requests updated entry data for given time period" do
      start = Time.zone.now.in_time_zone("Eastern Time (US & Canada)")
      end_t = start + 1.hour

      request_body = {'job_params' => {start_date: start.strftime("%Y%m%d%H%M"), end_date: end_t.strftime("%Y%m%d%H%M")}}
      expect(@http_client).to receive(:post).with("#{@proxy_config['url']}/job/updated_entries", request_body, {}, @proxy_config['auth_token'])
      @c.request_updated_entry_numbers start, end_t, ""
    end

    it "adds customer numbers to request if present" do
      start = Time.zone.now.in_time_zone("Eastern Time (US & Canada)")
      end_t = start + 1.hour

      request_body = {'job_params' => {start_date: start.strftime("%Y%m%d%H%M"), end_date: end_t.strftime("%Y%m%d%H%M"), customer_numbers: "CUST1,CUST2"}}
      expect(@http_client).to receive(:post).with("#{@proxy_config['url']}/job/updated_entries", request_body, {}, @proxy_config['auth_token'])
      @c.request_updated_entry_numbers start, end_t, ["CUST1", "CUST2"]
    end

    it "does not swallow errors ocurring during the request" do
      start = Time.zone.now.in_time_zone("Eastern Time (US & Canada)")
      end_t = start + 1.hour

      request_body = {'job_params' => {start_date: start.strftime("%Y%m%d%H%M"), end_date: end_t.strftime("%Y%m%d%H%M")}}
      expect(@http_client).to receive(:post).with("#{@proxy_config['url']}/job/updated_entries", request_body, {}, @proxy_config['auth_token']).and_raise "Error"
      
      expect {@c.request_updated_entry_numbers start, end_t, ""}.to raise_error "Error"
    end
  end

  describe "bulk_request_entry_data" do
    before :each do
      @entry = Factory(:entry,:source_system=>'Alliance',:broker_reference=>'123456')
    end

    it "uses primary key values to request entry data" do
      expect_any_instance_of(described_class).to receive(:request_entry_data).with "123456"
      described_class.bulk_request_entry_data primary_keys: [@entry.id]
    end

    it "skips non-alliance entries" do
      @entry.update_attributes! source_system: "Not Alliance"
      expect_any_instance_of(described_class).not_to receive(:request_entry_data).with "123456"
      described_class.bulk_request_entry_data primary_keys: [@entry.id]
    end

    it "uses s3 data to pull keys" do
      expect_any_instance_of(described_class).to receive(:request_entry_data).with "123456"
      expect(OpenChain::CoreModuleProcessor).to receive(:bulk_objects).with(CoreModule::ENTRY, primary_keys: nil, primary_key_file_bucket: "bucket", primary_key_file_path: "key").and_yield(1, @entry)
      described_class.bulk_request_entry_data s3_bucket: "bucket", s3_key: "key"
    end
  end

  describe "delayed_bulk_entry_data" do
    let(:s3_obj) {
      s3_obj = double("OpenChain::S3::UploadResult")
      allow(s3_obj).to receive(:key).and_return "key"
      allow(s3_obj).to receive(:bucket).and_return "bucket"
      s3_obj
    }
    let (:search_run) { SearchRun.create! search_setup_id: Factory(:search_setup).id }

    it "proxies requests with search runs in them" do
      expect(OpenChain::S3).to receive(:create_s3_tempfile).and_return s3_obj
      expect(described_class).to receive(:delay).and_return described_class
      expect(described_class).to receive(:bulk_request_entry_data).with(s3_bucket: "bucket", s3_key: "key")
      described_class.delayed_bulk_entry_data search_run.id, nil
    end

    it "passes primary keys directly through" do
      expect(described_class).to receive(:delay).and_return described_class
      expect(described_class).to receive(:bulk_request_entry_data).with(primary_keys: [1, 2, 3])
      described_class.delayed_bulk_entry_data nil, [1, 2, 3]
    end
  end

  describe "request_mid_updates" do
    it "sends a request for mid updates" do
      expect(subject).to receive(:request).with("mid_updates", {updated_date: 20161010}, {results_as_array: true}, {swallow_error: false})
      subject.request_mid_updates(Date.new(2016, 10, 10))
    end
  end

  describe "request_address_updates" do
    it "sends a request for address updates" do
      expect(subject).to receive(:request).with("address_updates", {updated_date: 20161010}, {results_as_array: true}, {swallow_error: false})
      subject.request_address_updates(Date.new(2016, 10, 10))
    end
  end

  describe "request_updated_statements" do
    it 'sends a request for updated statements' do 
      my_params = nil
      my_context = nil
      expect(subject).to receive(:request) do |path, params, context, opts|
        expect(path).to eq 'updated_statements_to_s3'
        expect(opts).to eq({swallow_error: false})
        my_params = params
        my_context = context
        nil
      end

      start_date = ActiveSupport::TimeZone["America/New_York"].parse("2017-11-28 12:00")
      end_date = ActiveSupport::TimeZone["America/New_York"].parse("2017-11-28 13:00")

      subject.request_updated_statements start_date.utc, end_date.utc, "bucket", "path", "queue"

      expect(my_params[:start_date]).to eq "201711281200"
      expect(my_params[:end_date]).to eq "201711281300"
      expect(my_params[:customer_numbers]).to be_nil

      expect(my_context[:s3_bucket]).to eq "bucket"
      expect(my_context[:s3_path]).to eq "path"
      expect(my_context[:sqs_queue]).to eq "queue"
    end

    it "sends a request for updated statements with customer numbers" do 
      my_params = nil
      expect(subject).to receive(:request) do |path, params, context, opts|
        my_params = params
        nil
      end

      subject.request_updated_statements Time.zone.now, Time.zone.now, "bucket", "path", "queue", customer_numbers: ["ABC", "123"]

      expect(my_params[:customer_numbers]).to eq "ABC,123"
    end
  end

  describe "request_daily_statements" do
    it "sends statements_to_s3 request" do
      my_params = nil
      my_context = nil
      expect(subject).to receive(:request) do |path, params, context, opts|
        expect(path).to eq 'statements_to_s3'
        expect(opts).to eq({swallow_error: false})
        my_params = params
        my_context = context
        nil
      end

      subject.request_daily_statements ["A", "B"], "bucket", "path", "queue"

      expect(my_context[:s3_bucket]).to eq "bucket"
      expect(my_context[:s3_path]).to eq "path"
      expect(my_context[:sqs_queue]).to eq "queue"

      expect(my_params[:daily_statement_numbers]).to eq ["A", "B"]
    end
  end

  describe "request_monthly_statements" do
    it "sends statements_to_s3 request" do
      my_params = nil
      my_context = nil
      expect(subject).to receive(:request) do |path, params, context, opts|
        expect(path).to eq 'statements_to_s3'
        expect(opts).to eq({swallow_error: false})
        my_params = params
        my_context = context
        nil
      end

      subject.request_monthly_statements ["A", "B"], "bucket", "path", "queue"

      expect(my_context[:s3_bucket]).to eq "bucket"
      expect(my_context[:s3_path]).to eq "path"
      expect(my_context[:sqs_queue]).to eq "queue"

      expect(my_params[:monthly_statement_numbers]).to eq ["A", "B"]
    end
  end

  describe "request_monthly_statements_between" do
    it "requests statements received between given dates" do
      my_params = nil
      my_context = nil
      expect(subject).to receive(:request) do |path, params, context, opts|
        expect(path).to eq 'monthly_statements_to_s3'
        expect(opts).to eq({swallow_error: false})
        my_params = params
        my_context = context
        nil
      end

      subject.request_monthly_statements_between Date.new(2017,12,1), Date.new(2017, 12, 2), "bucket", "path", "queue"

      expect(my_context[:s3_bucket]).to eq "bucket"
      expect(my_context[:s3_path]).to eq "path"
      expect(my_context[:sqs_queue]).to eq "queue"

      expect(my_params[:start_date]).to eq 20171201
      expect(my_params[:end_date]).to eq 20171202
    end

    it "handles customer_numbers param" do
      my_params = nil
      expect(subject).to receive(:request) do |path, params, context, opts|
        my_params = params
        nil
      end

      subject.request_monthly_statements_between Date.new(2017,12,1), Date.new(2017, 12, 2), "bucket", "path", "queue", customer_numbers: ["1", "2", "3"]
      expect(my_params[:customer_numbers]).to eq "1,2,3"
    end
  end

  describe "request_entry_data" do
    it "sends request for entry data to sql proxy system" do
      expect(subject).to receive(:aws_context_hash).with("json", filename_prefix: "12345", parser_class: OpenChain::CustomHandler::KewillEntryParser).and_return({hash: :data})
      expect(subject).to receive(:request).with('entry_data_to_s3', {file_no: 12345}, {hash: :data})
      subject.request_entry_data "12345"
    end
  end

  describe "request_updated_tariff_classifications" do
    it "sends request for tariff data to sql proxy system" do
      expect(subject).to receive(:request).with "updated_tariffs_to_s3", {start_date: 201901301225, end_date: 201901301330}, {s3_bucket: "bucket", s3_path: "path", sqs_queue: "queue"}, {swallow_error: false}

      subject.request_updated_tariff_classifications(Time.new(2019, 1, 30, 12, 25), Time.new(2019, 1, 30, 13, 30), "bucket", "path", "queue")
    end
  end

end