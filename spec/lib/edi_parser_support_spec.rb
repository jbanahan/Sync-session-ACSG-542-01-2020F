require 'spec_helper'

describe OpenChain::EdiParserSupport do
  subject {
    Class.new { include OpenChain::EdiParserSupport }.new
  }

  let (:file_path) { 'spec/support/bin/ascena_apll_856.txt' }

  let (:segments) {
    REX12.each_segment(file_path).to_a
  }

  let (:first_transaction) {
    REX12.each_transaction(file_path).first
  }

  let (:first_transaction_segments) {
    first_transaction.segments
  }

  describe "with_qualified_segments" do
    it "finds segments with a given value in the qualified field" do
      segs = []
      subject.with_qualified_segments(segments, "ST", 1, "856") { |s| segs << s}
      expect(segs.length).to eq 9
    end

    it "yields nothing if no values are found" do 
      segs = []
      subject.with_qualified_segments(segments, "ST", 1, "850") { |s| segs << s}
      expect(segs.length).to eq 0
    end
  end

  describe "find_elements_by_qualifier" do
    it "finds all segment values that have the given qualifier value" do
      # We're just pulling back the ST counter, so the values should be 001....009
      expect(subject.find_elements_by_qualifier(segments, "ST", "856", 1, 2)).to eq (1..9).map {|v| v.to_s.rjust(4, '0') }
    end

    it "skips values if value position is not present" do
      expect(subject.find_elements_by_qualifier(segments, "ST", "856", 1, 5)).to eq []
    end

    it "returns blank values if segment value is blank" do
      expect(subject.find_elements_by_qualifier(segments, "HL", "1", 1, 2)).to eq ["", "", "", "", "", "", "", "", ""]
    end
  end

  describe "find_segments_by_qualifier" do
    it "finds all segments that have the given qualifier value" do
      segs = subject.find_segments_by_qualifier(segments, "ST01", "856")
      expect(segs.length).to eq 9
      # THis is mostly just to ensure that the return value we get is as expected
      expect(segs.map {|s| s[1] }.uniq).to eq ["856"]
    end

    it "doesn't fail if edi position doesn't exist" do
      expect(subject.find_segments_by_qualifier(segments, "ST010", "856")).to eq []
    end
  end

  describe "find_values_by_qualifier" do
    it "finds all value elements relative to a qualifier, using default value index position 1 greater than qualifier coordinate" do
      # We're just pulling back the ST counter, so the values should be 001....009
      expect(subject.find_values_by_qualifier(segments, "ST01", "856")).to eq (1..9).map {|v| v.to_s.rjust(4, '0') }
    end

    it "finds all value elements relative to a qualifier, using explicit value index" do
      expect(subject.find_values_by_qualifier(segments, "ST01", "856", value_index: 1)).to eq 9.times.map {|v| "856" }
    end

    it "returns nothing if value index is bad" do
      expect(subject.find_values_by_qualifier(segments, "ST01", "856", value_index: 10)).to eq []
    end
  end

  describe "find_value_by_qualifier" do
    it "returns the first segment value that matches" do
      expect(subject.find_value_by_qualifier(segments, "REF01", "CR")).to eq "HK956641"
    end

    it "returns nil if nothing found" do
      expect(subject.find_value_by_qualifier(segments, "REF01", "CRTVQ")).to be_nil
    end
  end

  describe "find_ref_values" do
    it "returns all ref values that match" do
      expect(subject.find_ref_values(segments, "BM")).to eq ["XM1007980", "XM1007980", "XM1007980", "XM1007980", "XM1007980", "XM1007980", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990"]
    end

    it "returns blank list if nothing found" do
      expect(subject.find_ref_values(segments, "BMNN")).to eq []
    end
  end

  describe "find_ref_value" do
    it "returns first matching value" do
      expect(subject.find_ref_value(segments, "BM")).to eq "XM1007980"
    end

    it "returns nil if nothing found" do
      expect(subject.find_ref_value(segments, "BMNN")).to be_nil
    end
  end

  describe "find_element_values" do
    it "finds all values described by the given coordinate" do
      expect(subject.find_element_values(segments, "ST02")).to eq (1..9).map {|v| v.to_s.rjust(4, '0') }
    end

    it "retuns blank array if nothign found" do
      expect(subject.find_element_values(segments, "ST09")).to eq []
    end
  end

  describe "find_element_value" do
    it "finds first value described by the given coordinate" do
      expect(subject.find_element_value(segments, "ST02")).to eq "0001"
    end

    it "retuns blank array if nothign found" do
      expect(subject.find_element_value(segments, "ST09")).to be_nil
    end
  end

  describe "find_date_values" do
    it "finds and parses DTM segments using default values" do
      dates = subject.find_date_values(segments, "311")
      expect(dates.length).to eq 9
      expect(dates.first).to eq ActiveSupport::TimeZone["UTC"].parse("2016-11-18")
    end

    it "finds and parses DTM segments using time_zone as string" do
      dates = subject.find_date_values(segments, "311", time_zone: "America/New_York")
      expect(dates.first).to eq ActiveSupport::TimeZone["America/New_York"].parse("2016-11-18")
    end

    it "finds and parses DTM segments using given date_format" do
      dates = subject.find_date_values(segments, "311", date_format: "%Y%m%d")
      expect(dates.first).to eq ActiveSupport::TimeZone["UTC"].parse("2016-11-18")
    end

    it "finds and parses DTM segments using given date format and given timezone" do 
      dates = subject.find_date_values(segments, "311", date_format: "%Y%m%d", time_zone: "America/New_York")
      expect(dates.first).to eq ActiveSupport::TimeZone["America/New_York"].parse("2016-11-18")
    end
  end

  describe "find_date_value" do
    it "finds and parses DTM segment using default values" do
      expect(subject.find_date_value(segments, "311")).to eq ActiveSupport::TimeZone["UTC"].parse("2016-11-18")
    end

    it "finds and parses DTM segment using time_zone as string" do
      expect(subject.find_date_value(segments, "311", time_zone: "America/New_York")).to eq ActiveSupport::TimeZone["America/New_York"].parse("2016-11-18")
    end

    it "finds and parses DTM segment using given date_format" do
      expect(subject.find_date_value(segments, "311", date_format: "%Y%m%d")).to eq ActiveSupport::TimeZone["UTC"].parse("2016-11-18")
    end

    it "finds and parses DTM segment using given date format and given timezone" do 
      expect(subject.find_date_value(segments, "311", date_format: "%Y%m%d", time_zone: "America/New_York")).to eq ActiveSupport::TimeZone["America/New_York"].parse("2016-11-18")
    end
  end

  describe "parse_dtm_date_value" do
    # This test mostly exists to test values we don't have in EDI files (mainly ones with times in the values)
    it "parses a DTM value with a time" do
      expect(subject.parse_dtm_date_value("201701011230")).to eq ActiveSupport::TimeZone["UTC"].parse("2017-01-01 12:30")
    end

    it "parses a DTM value using a defined format" do
      expect(subject.parse_dtm_date_value("201701011230", date_format: "%Y%m%d%H%M")).to eq ActiveSupport::TimeZone["UTC"].parse("2017-01-01 12:30")
    end

    it "parses a DTM value using a defined format containing the timezone in it" do
      expect(subject.parse_dtm_date_value("201701011230-0500", date_format: "%Y%m%d%H%M%z")).to eq ActiveSupport::TimeZone["UTC"].parse("2017-01-01 17:30")
    end
  end

  describe "find_segments" do
    it "finds all segments matching the given segment type" do
      segs = subject.find_segments segments, "GS"
      expect(segs.length).to eq 1
      expect(segs.first[0]).to eq "GS"
    end

    it "finds all segments matching the given segment types" do
      segs = subject.find_segments segments, "GS", "GE"
      expect(segs.length).to eq 2
      expect(segs.first[0]).to eq "GS"
      expect(segs.second[0]).to eq "GE"
    end

    it "yields matching segments" do
      vals = []
      expect(subject.find_segments(segments, "GS") {|s| vals << s} ).to be_nil
      expect(vals.length).to eq 1
      expect(vals.first[0]).to eq "GS"
    end
  end

  describe "parse_edi_coordinate" do
    it "parses standard edi element descriptor into segment / index pair" do
      expect(subject.parse_edi_coordinate("BEG10")).to eq ["BEG", 10]
    end

    it "raises an error if bad coordinates are given" do
      expect { subject.parse_edi_coordinate("ABC") }.to raise_error ArgumentError, "Invalid EDI coordinate value received: 'ABC'."
    end
  end

  describe "extract_loop" do

    # Use the burlington po edi for this as it's more succint, and actually uncovered
    # a bug in the looping.
    let (:segments) { REX12.each_segment('spec/fixtures/files/burlington_850_standard.edi').to_a}

    it "extracts all described loops from given segments" do
      loops = subject.extract_loop segments, ["N1", "N2", "N3", "N4", "PER"]
      expect(loops.length).to eq 5

      n1 = loops.last
      # The last N1 in the file has an N1, N2, N3, N4, PER segment.
      expect(n1.length).to eq 5
      expect(n1[0].segment_type).to eq "N1"
      expect(n1[1].segment_type).to eq "N2"
      expect(n1[2].segment_type).to eq "N3"
      expect(n1[3].segment_type).to eq "N4"
      expect(n1[4].segment_type).to eq "PER"
    end

    it "uses the stop element to break processing when a specific segment is seen" do
      # Only extract the non-n1 level segments 
      loops = subject.extract_loop segments, ["PER"], stop_segments: "FOB"

      expect(loops.size).to eq 2
      expect(loops[0][0][1]).to eq "BD"
      expect(loops[1][0][1]).to eq "AA"
    end

    it "allows for multiple stop segments" do 
      # Only extract the "header" level segments 
      loops = subject.extract_loop segments, ["PER"], stop_segments: ["PO1", "FOB"]

      expect(loops.size).to eq 2
    end
  end

  describe "find_segment_qualified_value" do

    let (:segment) { REX12::Segment.new([REX12::Element.new("SLN", 0), REX12::Element.new("1", 1), REX12::Element.new("IT", 0), REX12::Element.new("87027", 1)], 1) }

    it "returns the qualfied element's value" do
      expect(subject.find_segment_qualified_value(segment, "IT")).to eq "87027"
    end

    it "returns nil if not found" do
      expect(subject.find_segment_qualified_value(segment, "BLAH")).to be_nil
    end
  end

  describe "find_segment" do

    it "returns the expected segment" do
      seg = subject.find_segment segments, "ST"
      expect(seg).not_to be_nil
      expect(seg[2]).to eq "0001"
    end

    it "yields the expected segment" do
      seg = nil
      expect(subject.find_segment(segments, "ST") {|s| seg = s }).to be_nil
      expect(seg).not_to be_nil
      expect(seg[2]).to eq "0001"
    end

    it "returns nil if segment is not found" do
      expect(subject.find_segment(segments, "BLAH")).to be_nil
    end
  end

  describe "extract_n1_loop" do

    let (:order_segment) {
      loops = subject.extract_loop(first_transaction_segments, ["HL", "PRF", "PO4", "N1", "N2", "N3", "N4", "PER"])
      loops.find {|l| l.first[3] == "O"}
    }

    it "extracts all n1 segments" do
      n1_loops = subject.extract_n1_loops(order_segment)
      expect(n1_loops.length).to eq 2

      l = n1_loops.first
      expect(l.length).to eq 5
      expect(l[0].segment_type).to eq "N1"
      expect(l[1].segment_type).to eq "N2"
      expect(l[2].segment_type).to eq "N3"
      expect(l[3].segment_type).to eq "N4"
      expect(l[4].segment_type).to eq "PER"
    end

    it "extracts specific qualified n1 segment" do
      n1 = subject.extract_n1_loops(order_segment, qualifier: "TE")
      expect(n1.length).to eq 1

      expect(n1.first.length).to eq 3
      expect(n1.first.first[1]).to eq "TE"
    end

    it "returns blank array if nothing found" do
      expect(subject.extract_n1_loops(order_segment, qualifier: "XX")).to eq []
    end
  end

  describe "iso_code" do
    it "returns isa code from transaction" do
      expect(subject.isa_code(first_transaction)).to eq "000004837"
    end
  end

  describe "write_transaction" do
    it "writes transaction to given IO stream" do
      io = StringIO.new
      subject.write_transaction first_transaction, io
      io.rewind

      transactions = REX12.each_transaction(io).to_a
      expect(transactions.length).to eq 1
      expect(transactions.first.segments.length).to eq first_transaction.segments.length
    end
  end

  describe "send_error_email" do
    let (:error) { 
      e = StandardError.new "Error"
      e.set_backtrace Kernel.caller
      e
    }

    it "sends an error email comprised of the transaction" do
      subject.send_error_email(first_transaction, error, "Parser", "file.edi")

      m = ActionMailer::Base.deliveries.first

      expect(m).not_to be_nil
      expect(m.subject).to eq "Parser EDI Processing Error (ISA: 000004837)"
      expect(m.to).to eq ["edisupport@vandegriftinc.com"]
      expect(m.body.raw_source).to include "There was a problem processing the attached Parser EDI. A re-creation of only the specific EDI transaction file the file that errored is attached."
      expect(m.attachments["file.edi"]).not_to be_nil
      file = m.attachments["file.edi"].read
      transaction = StringIO.new
      subject.write_transaction(first_transaction, transaction)
      transaction.rewind

      expect(m.attachments["file.edi"].read).to eq transaction.read
    end

    it "does not include a backtrace if instructed not to" do
      subject.send_error_email(first_transaction, error, "Parser", "file.edi", include_backtrace: false)

      m = ActionMailer::Base.deliveries.first

      expect(m.body.raw_source).not_to include ERB::Util.html_escape(error.backtrace.first)      
    end

    it "handles blank filenames" do
      # The attachment in this case just takes the tempfile name...which is fine, this just used
      # to crash the reporter and we don't want that.
      subject.send_error_email(first_transaction, error, "Parser", nil)
      m = ActionMailer::Base.deliveries.first

      expect(m).not_to be_nil
      expect(m.attachments.size).to eq 1
    end
  end

  describe "extract_hl_loops" do
    let (:file_path) { 'spec/fixtures/files/burlington_856.edi' }
    let (:segments) { REX12.each_segment(file_path).to_a }

    it "creates hl heirarchy structure" do
      heirarchy = subject.extract_hl_loops segments

      # The top level should be the shipment
      expect(heirarchy[:hl_level]).to eq "S"

      # It should have 10 segments below it
      expect(heirarchy[:segments].map {|s| s.segment_type}).to eq ["TD5", "TD5", "TD5", "TD5", "TD3", "REF", "REF", "DTM", "DTM", "DTM", "DTM", "N1", "N3", "N4", "N1", "N3", "N4"]

      # It should have 2 sub-hl Orders below it
      expect(heirarchy[:hl_children].length).to eq 2

      order = heirarchy[:hl_children].first
      expect(order[:hl_level]).to eq "O"
      expect(order[:segments].map {|s| s.segment_type}).to eq ["PRF", "TD1"]
      expect(order[:hl_children].length).to eq 2

      pack = order[:hl_children].first
      expect(pack[:hl_level]).to eq "P"
      expect(pack[:segments].map {|s| s.segment_type}).to eq ["MAN"]
      expect(pack[:hl_children].length).to eq 1

      item = pack[:hl_children].first
      expect(item[:hl_level]).to eq "I"
      expect(item[:segments].map {|s| s.segment_type}).to eq ["LIN", "SN1"]
    end

    it "stops at given stop segment" do
      # Just use a stop element that's in the hl loop to make sure it stops where we instruct
      heirarchy = subject.extract_hl_loops segments, stop_segments: "TD1"

      # The top level should be the shipment
      expect(heirarchy[:hl_level]).to eq "S"

      # It should have 10 segments below it
      expect(heirarchy[:segments].map {|s| s.segment_type}).to eq ["TD5", "TD5", "TD5", "TD5", "TD3", "REF", "REF", "DTM", "DTM", "DTM", "DTM", "N1", "N3", "N4", "N1", "N3", "N4"]

      # It should have 2 sub-hl Orders below it
      expect(heirarchy[:hl_children].length).to eq 1
      order = heirarchy[:hl_children].first
      expect(order[:hl_level]).to eq "O"
      expect(order[:segments].map {|s| s.segment_type}).to eq ["PRF"]
      expect(order[:hl_children].length).to eq 0
    end
  end

  describe "value" do 
    let (:segment) { segments.first }

    it "returns given element index's value" do
      expect(subject.value(segment, 6)).to eq "ACSPROD        "
    end

    it "handles Ranges" do
      expect(subject.value(segment, (6..7))).to eq ["ACSPROD        ", "02"]
    end

    it "handles nil" do
      expect(subject.value(nil, 1)).to be_nil
    end

    it "handles Ranges outside segment's size" do
      expect(subject.value(segment, (12..20))).to eq ["00401", "000004837", "0", "P", ">"]
    end
  end

  describe "all_segments_up_to" do
    it "returns all segments up to the given stop segment" do
      segments = subject.all_segments_up_to first_transaction.segments, "REF"
      expect(segments.map {|s| s.segment_type}).to eq ["ST", "BSN", "HL", "TD1"]
    end

    it "allows for passing multiple stop segments" do
      segments = subject.all_segments_up_to first_transaction.segments, ["TD1", "REF"]
      expect(segments.map {|s| s.segment_type}).to eq ["ST", "BSN", "HL"]
    end

    it "returns all segments if no stop-segment is encountered" do 
      expect(subject.all_segments_up_to(first_transaction.segments, "BLAH").length).to eq 48
    end
  end

  describe "parse" do 

    let (:edi_data) {
      "ISA^00^          ^00^          ^ZZ^INSD           ^01^014492501      ^170725^1040^U^00401^000001357^0^P^>\n" +
      "GS^SH^INSD^014492501^20170725^1040^1356^X^004010\n" +
      transaction_1 +
      transaction_2 +
      "GE^1^1356\n" +
      "IEA^1^000001357\n"
    }

    let (:single_transaction_edi) {
      "ISA^00^          ^00^          ^ZZ^INSD           ^01^014492501      ^170725^1040^U^00401^000001357^0^P^>\n" +
      "GS^SH^INSD^014492501^20170725^1040^1356^X^004010\n" +
      transaction_1 +
      "GE^1^1356\n" +
      "IEA^1^000001357\n"
    }

    let (:transaction_1) {
      "ST^856^13560001\n" +
      "BSN^00^BCVA17000324^20170725^1040^0003^SH\n" + 
      "SE^38^13560001\n"
    }

    let (:transaction_2) {
      "ST^856^13560002\n" +
      "BSN^00^BCVA17000324^20170725^1040^0003^SH\n" + 
      "SE^38^13560002\n"
    }

    it "parses edi data into multiple transactions and delays processing each transaction" do 
      expect(subject.class).to receive(:delay).exactly(2).times.and_return subject.class

      transactions = []
      expect(subject.class).to receive(:process_transaction).exactly(2).times do |transaction, opts|
        expect(opts).to eq({key: "value"})
        transactions << transaction
      end

      subject.class.parse(edi_data, key: "value")
      expect(transactions.length).to eq 2

      # Just make sure the transactions were received in the correct order
      expect(subject.find_element_value(transactions.first.segments, "ST02")).to eq "13560001"
      expect(subject.find_element_value(transactions.second.segments, "ST02")).to eq "13560002"
    end

    it "does not delay edi transactions that are sent 1 to a file" do
      expect(subject.class).not_to receive(:delay)
      expect(subject.class).to receive(:process_transaction).once

      subject.class.parse(single_transaction_edi, key: "value")
    end

    it "does not delay edi transactions if no_delay option is used" do
      expect(subject.class).not_to receive(:delay)
      expect(subject.class).to receive(:process_transaction).twice

      subject.class.parse(edi_data, key: "value", no_delay: true)
    end
  end

  describe "process_transaction" do
    let (:transaction) { instance_double(REX12::Transaction) }
    let (:parser) { double(subject.class) }
    let (:user) { User.new }
    let (:opts) { {bucket: "bucket", key: "path"} }

    before :each do 
      allow(subject.class).to receive(:new).and_return parser
    end

    context "with successful process_transaction" do
      it "calls process transaction" do
        expect(subject.class).to receive(:user).and_return user
        expect(parser).to receive(:process_transaction).with(user, transaction, last_file_bucket: opts[:bucket], last_file_path: opts[:key])
        subject.class.process_transaction(transaction, opts)
      end

      it "uses User.integration user method is not implemented" do
        expect(parser).to receive(:process_transaction).with(User.integration, transaction, last_file_bucket: opts[:bucket], last_file_path: opts[:key])
        subject.class.process_transaction(transaction, opts)
      end
    end

    context "with errors" do
      before :each do 
        allow(subject.class).to receive(:user).and_return user
      end

      it "re-raises errors in test" do
        expect(parser).to receive(:process_transaction).and_raise "Error"
        expect { subject.class.process_transaction(transaction, opts) }.to raise_error "Error"
      end

      context "not in test environment" do
        before :each do 
          allow(subject.class).to receive(:test?).and_return false
        end

        context "running as delayed_job" do
          before :each do
            expect(subject.class.respond_to?(:currently_running_as_delayed_job?)).to eq true
            allow(subject.class).to receive(:currently_running_as_delayed_job?).and_return true
          end

          it "re-raises errors non EDI errors if delayed job and attempts < max " do
            expect(parser).to receive(:process_transaction).and_raise "Error"
            expect(subject.class).to receive(:currently_running_delayed_job_attempts).and_return 4
            expect { subject.class.process_transaction(transaction, opts) }.to raise_error "Error"
          end

          it "emails if attempts > max with standard error is raised" do
            e = StandardError.new "Error"
            expect(parser).to receive(:process_transaction).and_raise e
            expect(parser).to receive(:parser_name).and_return "Parser"
            expect(subject.class).to receive(:currently_running_delayed_job_attempts).and_return 5
            expect(subject.class).to receive(:send_error_email).with(transaction, e, "Parser", "path", to_address: "bug@vandegriftinc.com")
            expect(e).to receive(:log_me).with ["File: path"]

            subject.class.process_transaction(transaction, opts)
          end

          it "emails immediately if EdiBusinessLogicError is raised" do
            e = OpenChain::EdiParserSupport::EdiBusinessLogicError.new "Error"

            expect(parser).to receive(:process_transaction).and_raise e
            expect(parser).to receive(:parser_name).and_return "Parser"
            expect(subject.class).not_to receive(:currently_running_as_delayed_job?)
            expect(subject.class).to receive(:send_error_email).with(transaction, e, "Parser", "path", include_backtrace: false)
            expect(e).not_to receive(:log_me)

            subject.class.process_transaction(transaction, opts)
          end

          it "emails immediately if EdiStructuralError is raised" do
            e = OpenChain::EdiParserSupport::EdiStructuralError.new "Error"

            expect(parser).to receive(:process_transaction).and_raise e
            expect(parser).to receive(:parser_name).and_return "Parser"
            expect(subject.class).not_to receive(:currently_running_as_delayed_job?)
            expect(subject.class).to receive(:send_error_email).with(transaction, e, "Parser", "path", include_backtrace: false)
            expect(e).not_to receive(:log_me)

            subject.class.process_transaction(transaction, opts)
          end
        end
      end
    end
  end

  describe "parser_name" do
    it "uses the class' demodularized name" do
      klazz = class_double(OpenChain::CustomHandler::Talbots::Talbots856Parser)

      expect(subject).to receive(:class).and_return klazz
      expect(klazz).to receive(:name).and_return OpenChain::CustomHandler::Talbots::Talbots856Parser.name
      expect(subject.parser_name).to eq "Talbots856Parser"
    end
  end

  describe "extract_n1_entity_data" do
    let (:n1_loop) { subject.extract_n1_loops(first_transaction_segments, qualifier: "VN").first }

    it "extracts data from an n1 segment into a hash" do
      h = subject.extract_n1_entity_data n1_loop
      expect(h[:entity_type]).to eq "VN"
      expect(h[:name]).to eq "SOUTH ASIA (new)"
      expect(h[:id_code_qualifier]).to eq "ZZ"
      expect(h[:id_code]).to eq "70289"

      expect(h[:names]).to eq ["Name", "Name2"]
      address = h[:address]

      expect(address).not_to be_nil
      expect(address.line_1).to eq "17/F SOUTH ASIS BLDG"
      expect(address.line_2).to eq "108 HOW MING STREET"
      expect(address.city).to eq "City"
      expect(address.state).to eq "State"
      expect(address.postal_code).to eq "Postal"
      expect(h[:country]).to eq "CN"
    end
  end

  describe "find_or_create_company_from_n1_data" do
    let (:n1_loop) { subject.extract_n1_loops(first_transaction_segments, qualifier: "VN").first }
    let (:n1_data) { subject.extract_n1_entity_data n1_loop }
    let! (:cn) { Factory(:country, iso_code: "CN") }
    let (:importer) { Company.where(importer: true, system_code: "Test").first }

    it "extracts data from an n1 segment into a hash" do
      expect(Lock).to receive(:acquire).with("Company-70289", yield_in_transaction: false).and_yield

      company = subject.find_or_create_company_from_n1_data n1_data, company_type_hash: {factory: true}
      expect(company.persisted?).to eq true
      expect(company.system_code).to eq "70289"
      expect(company.factory).to eq true
      expect(company.name).to eq "SOUTH ASIA (new)"
      expect(company.name_2).to eq "Name"
      expect(company.addresses.length).to eq 1
      address = company.addresses.first
      expect(address.line_1).to eq "17/F SOUTH ASIS BLDG"
      expect(address.line_2).to eq "108 HOW MING STREET"
      expect(address.city).to eq "City"
      expect(address.state).to eq "State"
      expect(address.postal_code).to eq "Postal"
      expect(address.country).to eq cn
    end

    it "allows passing other attributes to add to the company" do
      company = subject.find_or_create_company_from_n1_data n1_data, company_type_hash: {factory: true}, other_attributes: {mid: "MID", irs_number: "12345"}
      expect(company.mid).to eq "MID"
      expect(company.irs_number).to eq "12345"
    end

    it "does not update information if company already exists" do
      existing = Factory(:company, factory: true, system_code: "70289", name: "Test")

      company = subject.find_or_create_company_from_n1_data n1_data, company_type_hash: {factory: true}

      expect(company).to eq existing

      existing.reload
      expect(existing.name).to eq "Test"
      expect(existing.addresses.length).to eq 0
    end

    it "uses system code prefix" do
      expect(Lock).to receive(:acquire).with("Company-Prefix-70289", yield_in_transaction: false).and_yield

      company = subject.find_or_create_company_from_n1_data n1_data, company_type_hash: {factory: true}, system_code_prefix: "Prefix"
      expect(company.system_code).to eq "Prefix-70289"
    end

    it "links to given company" do
      importer = Factory(:importer)
      company = subject.find_or_create_company_from_n1_data n1_data, company_type_hash: {factory: true}, link_to_company: importer
      expect(importer.linked_companies).to include company      
    end
  end

  describe "find_or_create_address_from_n1_data" do
    let (:n1_loop) { subject.extract_n1_loops(first_transaction_segments, qualifier: "VN").first }
    let (:n1_data) { subject.extract_n1_entity_data n1_loop }
    let! (:cn) { Factory(:country, iso_code: "CN") }
    let (:company) { Factory(:importer, system_code: "Test") }

    it "creates a new address" do
      expect(Lock).to receive(:acquire).with("Address-70289", yield_in_transaction: false).and_yield

      address = subject.find_or_create_address_from_n1_data n1_data, company
      expect(address.persisted?).to eq true
      expect(address.system_code).to eq "70289"
      expect(address.name).to eq "SOUTH ASIA (new)"
      expect(address.line_1).to eq "17/F SOUTH ASIS BLDG"
      expect(address.line_2).to eq "108 HOW MING STREET"
      expect(address.city).to eq "City"
      expect(address.state).to eq "State"
      expect(address.postal_code).to eq "Postal"
      expect(address.country).to eq cn

      expect(company.addresses).to include address
    end
  end

end
