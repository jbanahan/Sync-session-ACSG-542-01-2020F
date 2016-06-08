require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberPpqReport do

  describe "run_schedulable" do
    let (:entry) {
      tariff = Factory(:commercial_invoice_tariff, hts_code: "1111111111", 
                          commercial_invoice_line: Factory(:commercial_invoice_line, part_number: "Part", po_number: "PO", 
                            commercial_invoice: Factory(:commercial_invoice, mfid: "MID",
                              entry: Factory(:entry, customer_number: "LUMBER", customer_name: "LUMBER LIQUIDATORS INC", source_system: "Alliance", release_date: "2016-05-01", master_bills_of_lading: "MBOL1\nMBOL2", container_numbers: "CONT1\n CONT2", entry_number: "ENTNUM", arrival_date: Time.zone.parse("2016-04-30 05:00"))
                            )
                          )
                        )
      tariff.commercial_invoice_lacey_components.create! detailed_description: "DESC", quantity: 10, unit_of_measure: "UOM", name: "NAME", genus: "GENUS", species: "SPECIES", harvested_from_country: "CA", value: 100
      tariff.commercial_invoice_lacey_components.create! detailed_description: "DESC2", quantity: 20, unit_of_measure: "UOM2", name: "NAME2", genus: "GENUS2", species: "SPECIES2", harvested_from_country: "CN", value: 50
      tariff.commercial_invoice_line.entry
    }

    def validate_no_report_data attachment_name
      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first
      sheet = Spreadsheet.open(StringIO.new(m.attachments[attachment_name].read)).worksheets.first
      expect(sheet.rows.length).to eq 1
    end

    context "with_valid_run_dates" do
      around(:each) do |ex|
        Timecop.freeze(ActiveSupport::TimeZone["America/New_York"].parse("2016-05-02").in_time_zone("UTC")) do 
          ex.run
        end
      end

      it "sends report" do
        entry
        described_class.run_schedulable({'email_to' => ["user@there.com"]})

        expect(ActionMailer::Base.deliveries.length).to eq 1
        m = ActionMailer::Base.deliveries.first
        expect(m.to).to eq ["user@there.com"]
        expect(m.subject).to eq "PPQ Report 05/02/16"
        expect(m.body.raw_source).to include "Attached is the PPQ Report for 05/02/16."
        expect(m.attachments["PPQ Report 05-02-16.xls"]).not_to be_nil

        sheet = Spreadsheet.open(StringIO.new(m.attachments["PPQ Report 05-02-16.xls"].read)).worksheets.first
        expect(sheet.rows.length).to eq 3

        expect(sheet.row(0)).to eq ["Importer Name","Entry Number","B/L No(s)","Container No(s)","Arrival Date","Manufacturer ID","Part No","PO No","HTS No","Description", "Name of Constituent Element", "Quantity of Constituent Element","UOM","Percent of Constituent Element","PGA Line Value","Scientific Genus Name","Scientific Species Name","Source Country Code"]
        expect(sheet.row(1)).to eq ["LUMBER LIQUIDATORS INC", "ENTNUM", "MBOL1, MBOL2", "CONT1, CONT2", excel_date(Date.new(2016, 4, 30)), "MID", "Part", "PO", "1111.11.1111", "DESC", "NAME", 10, "UOM", 0, 100, "GENUS", "SPECIES", "CA"]
        expect(sheet.row(2)).to eq ["LUMBER LIQUIDATORS INC", "ENTNUM", "MBOL1, MBOL2", "CONT1, CONT2", excel_date(Date.new(2016, 4, 30)), "MID", "Part", "PO", "1111.11.1111", "DESC2", "NAME2", 20, "UOM2", 0, 50, "GENUS2", "SPECIES2", "CN"]
      end

      context "with invalid entry attribute" do 
        after :each do
          validate_no_report_data "PPQ Report 05-02-16.xls"
        end

        it "does not find non-Lumber entries" do
          entry.update_attributes! customer_number: "NOTLUMBER"
          described_class.run_schedulable({'email_to' => ["user@there.com"]})
        end

        it "does not find non-Kewill entries" do
          entry.update_attributes! source_system: "NOTALLIANCE"
          described_class.run_schedulable({'email_to' => ["user@there.com"]})
        end
      end
    end
    

    it "does not find entries before run period" do
      entry
      Timecop.freeze(ActiveSupport::TimeZone["America/New_York"].parse("2016-05-09").in_time_zone("UTC")) do 
        described_class.run_schedulable({'email_to' => ["user@there.com"]})
      end
      validate_no_report_data "PPQ Report 05-09-16.xls"
    end

    it "does not find entries after run period" do
      entry
      Timecop.freeze(ActiveSupport::TimeZone["America/New_York"].parse("2016-04-25").in_time_zone("UTC")) do 
        described_class.run_schedulable({'email_to' => ["user@there.com"]})
      end
      validate_no_report_data "PPQ Report 04-25-16.xls"
      
    end
  end
end