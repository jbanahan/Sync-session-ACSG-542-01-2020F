require 'spec_helper'

describe OpenChain::EdiParserSupport do
  subject {
    Class.new { include OpenChain::EdiParserSupport }.new
  }

  let (:file_path) { 'spec/support/bin/ascena_apll_856.txt' }

  let (:segments) {
    REX12::Document.read file_path
  }

  let (:first_transaction) {
    REX12::Document.each_transaction(IO.read(file_path)).first
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
      expect(segs.map {|s| s.elements[1].value }.uniq).to eq ["856"]
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
      expect(segs.first.elements[0].value).to eq "GS"
    end

    it "finds all segments matching the given segment types" do
      segs = subject.find_segments segments, "GS", "GE"
      expect(segs.length).to eq 2
      expect(segs.first.elements[0].value).to eq "GS"
      expect(segs.second.elements[0].value).to eq "GE"
    end

    it "yields matching segments" do
      vals = []
      expect(subject.find_segments(segments, "GS") {|s| vals << s} ).to be_nil
      expect(vals.length).to eq 1
      expect(vals.first.elements[0].value).to eq "GS"
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
    let (:segments) { REX12::Document.read 'spec/fixtures/files/burlington_850_standard.edi'}

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
      expect(loops[0][0].elements[1].value).to eq "BD"
      expect(loops[1][0].elements[1].value).to eq "AA"
    end

    it "allows for multiple stop segments" do 
      # Only extract the "header" level segments 
      loops = subject.extract_loop segments, ["PER"], stop_segments: ["PO1", "FOB"]

      expect(loops.size).to eq 2
    end
  end

  describe "find_segment_qualified_value" do

    let (:segment) { REX12::Segment.new "SLN|1||I|3|EA|10.75|WE||IN|14734100|IT|87027|BO|QIXELS|IZ|QTY|PU|QIXELS S3 KINGDOM WEAPON|BL|QIXELS|VA|87027|VE|QIXELS|SZ|QTY", "|", "~", 1 }

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
      expect(seg.elements[2].value).to eq "0001"
    end

    it "yields the expected segment" do
      seg = nil
      expect(subject.find_segment(segments, "ST") {|s| seg = s }).to be_nil
      expect(seg).not_to be_nil
      expect(seg.elements[2].value).to eq "0001"
    end

    it "returns nil if segment is not found" do
      expect(subject.find_segment(segments, "BLAH")).to be_nil
    end
  end

  describe "extract_n1_loop" do

    let (:order_segment) {
      loops = subject.extract_loop(first_transaction_segments, ["HL", "PRF", "PO4", "N1", "N2", "N3", "N4", "PER"])
      loops.find {|l| l.first.elements[3].value == "O"}
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
      expect(n1.first.first.elements[1].value).to eq "TE"
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

      transactions = REX12::Document.each_transaction(io.read)
      expect(transactions.length).to eq 1
      expect(transactions.first.segments.length).to eq first_transaction.segments.length
    end

    it "allows for alternate segment terminators" do
      io = StringIO.new
      subject.write_transaction first_transaction, io, segment_terminator: "^"
      io.rewind
      data = io.read

      transactions = REX12::Document.each_transaction(data)
      expect(transactions.length).to eq 1
      expect(transactions.first.segments.length).to eq first_transaction.segments.length

      # So, read up to the first segment terminator from the data we read and make sure its the exact
      # same values as those in our original transaction
      data =~ /(.*?)\^/
      expect($1).to eq first_transaction.isa_segment.value
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
      expect(m.body.raw_source).to include "There was a problem processing the attached Parser EDI. A recreation of only the specific EDI transaction file the file that errored is attached."
      expect(m.attachments["file.edi"]).not_to be_nil
      file = m.attachments["file.edi"].read
      transaction = StringIO.new
      subject.write_transaction(first_transaction, transaction)
      transaction.rewind

      expect(m.attachments["file.edi"].read).to eq transaction.read
    end
  end
end