require 'spec_helper'

describe OpenChain::AscenaInvoiceValidatorHelper do

  before(:each) do
    @ent = Factory(:entry, commercial_invoice_numbers: "123456789\n 987654321")
    @validator = described_class.new
    
    #fenix
    #6106200010-US quantity: 10, value: 300
    #6106200010-CN quantity: 10, value: 450
    #1206200010-CN quantity: 15, value: 50

    #unrolled
    #6106200010-US quantity: 10, value: 300
    #6106200010-CN quantity: 10, value: 450
    #1206200010-CN quantity: 15, value: 50
    
    fenix_inv_1 = Factory(:commercial_invoice, entry: @ent, invoice_number: '123456789', importer_id: 1137)  
    
      @fenix_inv_1_ln_1 = Factory(:commercial_invoice_line, commercial_invoice: fenix_inv_1, country_origin_code: "US", quantity: 10, value: 300)
        fenix_inv_1_ln_1_tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: @fenix_inv_1_ln_1, hts_code: "6106200010")

      @fenix_inv_1_ln_2 = Factory(:commercial_invoice_line, commercial_invoice: fenix_inv_1, country_origin_code: "CN", quantity: 15, value: 50)
        fenix_inv_1_ln_2_tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: @fenix_inv_1_ln_2, hts_code: "1206200010")

    fenix_inv_2 = Factory(:commercial_invoice, entry: @ent, invoice_number: '987654321')
      
      fenix_inv_2_ln_1 = Factory(:commercial_invoice_line, commercial_invoice: fenix_inv_2, country_origin_code: "CN", quantity: 10, value: 450 )
        fenix_inv_1_ln_1_tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: fenix_inv_2_ln_1, hts_code: "6106200010")
    
    
    unrolled_inv_1 = Factory(:commercial_invoice, entry: nil, invoice_number: '123456789', importer_id: 1137)
    
      unrolled_inv_1_ln_1 = Factory(:commercial_invoice_line, commercial_invoice: unrolled_inv_1, country_origin_code: "US", quantity: 7, value: 150, part_number: '1278-603-494')
        unrolled_inv_1_ln_1_tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: unrolled_inv_1_ln_1, hts_code: "6106200010")

      unrolled_inv_1_ln_2 = Factory(:commercial_invoice_line, commercial_invoice: unrolled_inv_1, country_origin_code: "US", quantity: 3, value: 150, part_number: '5847-603-494')
        unrolled_inv_1_ln_2_tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: unrolled_inv_1_ln_2, hts_code: "6106200010")

      unrolled_inv_1_ln_3 = Factory(:commercial_invoice_line, commercial_invoice: unrolled_inv_1, country_origin_code: "CN", quantity: 5, value: 50, part_number: '6177-603-494')
        unrolled_inv_1_ln_3_tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: unrolled_inv_1_ln_3, hts_code: "6106200010")

      unrolled_inv_1_ln_4 = Factory(:commercial_invoice_line, commercial_invoice: unrolled_inv_1, country_origin_code: "CN", quantity: 7, value: 20, part_number: '4352-603-494')
        unrolled_inv_1_ln_4_tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: unrolled_inv_1_ln_4, hts_code: "1206200010")

    unrolled_inv_2 = Factory(:commercial_invoice, entry: nil, invoice_number: '987654321', importer_id: 1137)
    
      unrolled_inv_2_ln_1 = Factory(:commercial_invoice_line, commercial_invoice: unrolled_inv_2, country_origin_code: "CN", quantity: 5, value: 20, part_number: '1278-603-494')
        unrolled_inv_2_ln_1_tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: unrolled_inv_2_ln_1, hts_code: "1206200010")

      unrolled_inv_2_ln_2 = Factory(:commercial_invoice_line, commercial_invoice: unrolled_inv_2, country_origin_code: "CN", quantity: 3, value: 10, part_number: '1278-603-494')
        unrolled_inv_2_ln_2_tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: unrolled_inv_2_ln_2, hts_code: "1206200010")

      unrolled_inv_2_ln_3 = Factory(:commercial_invoice_line, commercial_invoice: unrolled_inv_2, country_origin_code: "CN", quantity: 4, value: 250, part_number: '1278-603-494')
        unrolled_inv_2_ln_3_tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: unrolled_inv_2_ln_3, hts_code: "6106200010")

      unrolled_inv_2_ln_4 = Factory(:commercial_invoice_line, commercial_invoice: unrolled_inv_2, country_origin_code: "CN", quantity: 1, value: 150, part_number: '1278-603-494')
        unrolled_inv_2_ln_4_tariff = Factory(:commercial_invoice_tariff, commercial_invoice_line: unrolled_inv_2_ln_4, hts_code: "6106200010")
  end

  describe "run_queries" do
    it "executes #gather_unrolled and :gather_entry" do
      @validator.should_receive(:gather_unrolled).with %Q("123456789", "987654321")
      @validator.should_receive(:gather_entry).with @ent
      @validator.run_queries @ent
    end
  end

  describe "total_value_per_hts_coo_diff" do
    it "returns empty if the total value per HTS on the unrolled invoices matches the corresponding Fenix entry" do 
      @validator.run_queries @ent
      expect(@validator.total_value_per_hts_coo_diff).to be_empty
    end

    it "compares the affected HTS numbers if the total value per HTS on the unrolled invoices doesn't match the corresponding Fenix entry" do
      @fenix_inv_1_ln_1.update_attributes(value: 310)
      @fenix_inv_1_ln_2.update_attributes(value: 100) 
      @validator.run_queries @ent
      expect(@validator.total_value_per_hts_coo_diff).to eq "Total value per HTS/country-of-origin:\n" \
                                                            "Expected 6106200010/US = 300.00, found 6106200010/US = 310.00\n" \
                                                            "Expected 1206200010/CN = 50.00, found 1206200010/CN = 100.00\n"
    end
  end

  describe "total_qty_per_hts_coo_diff" do
    it "returns empty if the total quantity per HTS on the unrolled invoices matches the corresponding Fenix entry" do 
      @validator.run_queries @ent
      expect(@validator.total_qty_per_hts_coo_diff).to be_empty
    end

    it "compares the affected HTS numbers if the total quantity per HTS on the unrolled invoices doesn't match the corresponding Fenix entry" do
      @fenix_inv_1_ln_1.update_attributes(quantity: 8)
      @fenix_inv_1_ln_2.update_attributes(quantity: 1) 
      @validator.run_queries @ent
      expect(@validator.total_qty_per_hts_coo_diff).to eq "Total quantity per HTS/country-of-origin:\n" \
                                                          "Expected 6106200010/US = 10.0, found 6106200010/US = 8.0\n" \
                                                          "Expected 1206200010/CN = 15.0, found 1206200010/CN = 1.0\n"
    end
  end

  describe "total_value_diff" do
    it "returns empty if the total value of the unrolled invoices matches that of the corresponding Fenix entry" do 
      @validator.run_queries @ent
      expect(@validator.total_value_diff).to be_empty
    end

    it "compares the total values if the total value of the unrolled invoices doesn't match that of the corresponding Fenix entry" do
      @fenix_inv_1_ln_1.update_attributes(value: 310) 
      @validator.run_queries @ent
      expect(@validator.total_value_diff).to eq "Expected total value = 800.00, found total value = 810.00\n"
    end
  end

  describe "total_qty_diff" do
    it "returns empty if the total quantity of the unrolled invoices matches the corresponding Fenix entry" do 
      @validator.run_queries @ent
      expect(@validator.total_qty_diff).to be_empty
    end

    it "compares the total quantities if the total quantity of the unrolled invoices doesn't match the corresponding Fenix entry" do
      @fenix_inv_1_ln_1.update_attributes(quantity: 8) 
      @validator.run_queries @ent
      expect(@validator.total_qty_diff).to eq "Expected total quantity = 35.0, found total quantity = 33.0\n"
    end
  end

  describe "hts_set_diff" do
    it "returns empty if the unrolled invoices contain the same HTS numbers as the corresponding Fenix entry" do 
      @validator.run_queries @ent
      expect(@validator.hts_set_diff).to be_empty
    end

    it "compares the HTS sets if the unrolled invoices don't contain the same HTS numbers as the corresponding Fenix entry" do
      @fenix_inv_1_ln_1.commercial_invoice_tariffs.first.update_attributes(hts_code: "1111111111") 
      @fenix_inv_1_ln_2.commercial_invoice_tariffs.first.update_attributes(hts_code: "2222222222")
      @validator.run_queries @ent
      expect(@validator.hts_set_diff).to eq "Missing HTS code(s): 1206200010\nUnexpected HTS code(s): 1111111111, 2222222222\n"
    end
  end

  describe "style_set_match" do
    it "returns empty if the unrolled invoices don't contain any of the specified styles" do 
      @validator.run_queries @ent
      style_set = ['1111'].to_set
      expect(@validator.style_set_match(style_set)).to be_empty
    end

    it "returns list of if the unrolled invoices contain any of the specified styles" do 
      @validator.run_queries @ent
      style_set = ['5847', '6177'].to_set
      expect(@validator.style_set_match(style_set)).to eq "Flagged style(s): 5847, 6177\n"
    end
  end

  describe "create_diff_messages" do  
    it "returns list of discrepancies" do
      unrolled = [["12345/CN", 10],["54321/US", 15], ["24681/US", 8]].to_set
      fenix = [["54321/US", 11], ["24681/US", 17], ["99999/ID", 9]].to_set
      unrolled_diff_set = double()
      fenix_diff_set = double()

      @validator.should_receive(:relative_complement).with(fenix_diff_set, unrolled_diff_set).and_return unrolled
      @validator.should_receive(:relative_complement).with(unrolled_diff_set, fenix_diff_set).and_return fenix
      expect(@validator.create_diff_messages unrolled_diff_set, fenix_diff_set).to eq "Expected 12345/CN = 10, found 12345/CN = 0\n" \
                                                                                      "Expected 54321/US = 15, found 54321/US = 11\n" \
                                                                                      "Expected 24681/US = 8, found 24681/US = 17\n" \
                                                                                      "Did not expect to find 99999/ID = 9\n"
    end

   it "returns empty if both sets are empty" do
      expect(@validator.create_diff_messages Set.new({}), Set.new({})).to be_empty
   end
  end

end