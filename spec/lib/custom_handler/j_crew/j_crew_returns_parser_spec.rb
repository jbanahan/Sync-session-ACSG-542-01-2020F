require 'spec_helper'

describe OpenChain::CustomHandler::JCrew::JCrewReturnsParser do

  subject { described_class.new nil }
  let (:hts_number) {"12345467890"}
  let (:mid) { "MANUFACTURER" }
  let (:coo) { "VN" }
  let (:part_number) {"62974"}
  let (:crew) { Factory(:importer, alliance_customer_number: "J0000") }
  let (:previous_entry) {
    entry = Factory(:entry, importer: crew, import_country: Factory(:country, iso_code: "US"), release_date: Time.zone.now)
    inv = Factory(:commercial_invoice, entry: entry, mfid: mid)
    line = Factory(:commercial_invoice_line, commercial_invoice: inv, part_number: part_number, country_origin_code: coo)
    tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: line, hts_code: hts_number)

    entry
  }
  let (:user) { Factory(:user) }

  before :each do
    previous_entry
  end

  describe "parse_and_send" do


    context "with_csv_file" do
      let (:file) { File.open("spec/fixtures/files/crew_returns.csv", "r") }

      let (:custom_file) {
        file = double("CustomFile")
        allow(file).to receive(:attached_file_name).and_return "file.csv"
        allow(file).to receive(:bucket).and_return "bucket"
        allow(file).to receive(:path).and_return "path"
        file
      }

      before :each do
        allow(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path", original_filename: "path").and_yield(file)
      end

      it "parses a csv file" do
        subject.parse_and_send custom_file, user
        expect(ActionMailer::Base.deliveries.size).to eq 1

        email = ActionMailer::Base.deliveries.first
        expect(email.subject).to eq "JCrew Returns File file.csv"
        expect(email.body.raw_source).to include "Attached is the processed J Crew Returns file."
        expect(email.attachments.size).to eq 1
        rows = CSV.parse(email.attachments.first.read)
        expect(rows.size).to eq 1
        expect(rows.first).to eq ["3700000183", "10", "1", "EA", "62974", "WD8983", "XL", "100% YD MENS COTTON WOVEN SHIRT", "6205202051", "MU", "20.7", "20.7", "USD", "416", "GB", hts_number, mid, coo]
      end

      it "handles restricted products" do
        import_restricted = described_class.prep_custom_definitions([:prod_import_restricted])[:prod_import_restricted]
        prod = Factory(:product, importer: crew, unique_identifier: "JCREW-#{part_number}")
        cv = prod.find_and_set_custom_value(import_restricted, true)
        cv.save!

        subject.parse_and_send custom_file, user
        rows = CSV.parse(ActionMailer::Base.deliveries.first.attachments.first.read)
        expect(rows.first[-3..-1]).to eq ["RESTRICTED", "RESTRICTED", "RESTRICTED"]
      end
    end
    
    context "pdf file" do
      let (:file) { File.open("spec/fixtures/files/crew_returns.pdf", "r") }

      let (:custom_file) {
        file = double("CustomFile")
        allow(file).to receive(:attached_file_name).and_return "file.pdf"
        allow(file).to receive(:bucket).and_return "bucket"
        allow(file).to receive(:path).and_return "path"
        file
      }

      before :each do
        allow(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path", original_filename: "path").and_yield(file)
      end

      it "parses a pdf file" do
        # Mock out the actual convert_pdf_to_text call so we don't have to rely on Xpdf being installed on the user machine / ci system
        expect(subject).to receive(:convert_pdf_to_text).and_return IO.read("spec/fixtures/files/crew_returns.txt")
        subject.parse_and_send custom_file, user
        expect(ActionMailer::Base.deliveries.size).to eq 1

        email = ActionMailer::Base.deliveries.first
        expect(email.subject).to eq "JCrew Returns File file.csv"
        expect(email.body.raw_source).to include "Attached is the processed J Crew Returns file."
        expect(email.attachments.size).to eq 1
        rows = CSV.parse(email.attachments.first.read)
        expect(rows.size).to eq 2
        expect(rows[0]).to eq ["Product ID", "COO", "HTS", "Description", "PO", "Qty", "Price", "Total Price", "Prior HTS", "Prior MID", "Prior COO"]
        expect(rows[1]).to eq ["62974", "CN", "6203424050", "MEN'S 100% COTTON WOVEN SHORT", "3700015360", "1", "8.95", "8.95", hts_number, mid, coo]
      end
    end
    

    context "with zip file" do
      let (:file) { File.open("spec/fixtures/files/crew_returns.zip", "r") }

      let (:custom_file) {
        file = double("CustomFile")
        allow(file).to receive(:attached_file_name).and_return "file.zip"
        allow(file).to receive(:bucket).and_return "bucket"
        allow(file).to receive(:path).and_return "path"
        file
      }

      before :each do
        allow(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "path", original_filename: "path").and_yield(file)
      end

      it "parses zip file" do
        subject.parse_and_send custom_file, user
        expect(ActionMailer::Base.deliveries.size).to eq 1

        email = ActionMailer::Base.deliveries.first
        expect(email.subject).to eq "JCrew Returns File file.zip"
        expect(email.body.raw_source).to include "Attached is the processed J Crew Returns file."
        expect(email.attachments.size).to eq 1

        entries = {}
        # Read the zip file we're sending to make sure the file inside of it was actually parsed
        # The data in it is the same as the standalone csv file.
        Zip::File.open_buffer(email.attachments.first.read) do |zip_file|
          zip_file.each do |entry|
            out = StringIO.new
            entry.get_input_stream do |input|
              out.write(input.read(Zip::Decompressor::CHUNK_SIZE, '')) until input.eof?
            end
            out.flush
            out.rewind
            entries[entry.name] = out
          end
        end

        expect(entries['crew_returns.csv']).not_to be_nil
        rows = CSV.parse(entries['crew_returns.csv'].read)
        expect(rows.size).to eq 1
        expect(rows.first).to eq ["3700000183", "10", "1", "EA", "62974", "WD8983", "XL", "100% YD MENS COTTON WOVEN SHIRT", "6205202051", "MU", "20.7", "20.7", "USD", "416", "GB", hts_number, mid, coo]
      end
    end
  end
  
end