require 'spec_helper'

describe OpenChain::CustomHandler::PoloEfocusProductGenerator do
  describe :generate do
    it "should create xls file, and ftp it" do
      h = described_class.new
      h.should_receive(:sync_xls).and_return('x')
      h.should_receive(:ftp_file).with('x').and_return('y')
      h.generate.should eq 'y'
    end
  end
  describe :sync_xls do
    before :each do
      @us = Factory(:country,:iso_code=>'US')
      @match_product = Factory(:classification,:country_id=>@us.id).product
      @barthco_cust = Factory(:custom_definition,:id=>1,:module_type=>'Product',:label=>'Barthco Customer ID')
      @match_product.update_custom_value! @barthco_cust, '100'
    end
    after :each do
      @tmp.unlink if @tmp
    end
    it "should create workbook from results" do
      @tmp = described_class.new.sync_xls
      sheet = Spreadsheet.open(@tmp).worksheet(0)
      r = sheet.row(0)
      r[2].should == ModelField.find_by_uid(:class_cntry_iso).label
      r[5].should == ModelField.find_by_uid(:prod_uid).label
      r = sheet.row(1)
      r[2].should == "US"
      r[5].should == @match_product.unique_identifier
    end
    it "should write sync_records for products" do
      @tmp = described_class.new.sync_xls
      @match_product.reload
      sr = @match_product.sync_records.find_by_trading_partner(described_class::SYNC_CODE)
      sr.sent_at.should < sr.confirmed_at
    end
  end
  describe :ftp_file do
    it "should send file to OHL and unlink" do
      t = mock("tmpfile")
      t.should_receive(:unlink)
      FtpSender.should_receive(:send_file).with('ftp.freightek.com','polo','polo541xm',t,{:folder=>'/ProductUpload'})
      described_class.new.ftp_file t
    end
  end
  describe :result_table do
    before :each do
      @us = Factory(:country,:iso_code=>'US')
    end
    context "simple tests" do
      before :each do
        @match_product = Factory(:classification,:country_id=>@us.id).product
        @barthco_cust = Factory(:custom_definition,:id=>1,:module_type=>'Product',:label=>'Barthco Customer ID')
        @match_product.update_custom_value! @barthco_cust, '100'
      end
      it 'should not return product without US classification' do
        dont_find = Factory(:classification).product
        dont_find.update_custom_value! @barthco_cust, '100'
        r = described_class.new.result_table
        r.count.should == 1
        r.first[5].should == @match_product.unique_identifier
      end
      it 'should not return multiple rows for multiple country classifications' do
        other_country_class = Factory(:classification,:product=>@match_product)
        r = described_class.new.result_table
        r.count.should == 1
        r.first[5].should == @match_product.unique_identifier
      end
      it "should not return products that don't need sync" do
        dont_find = Factory(:classification,:country_id=>@us.id).product
        dont_find.update_custom_value! @barthco_cust, '100'
        dont_find.sync_records.create!(:trading_partner=>described_class::SYNC_CODE,:sent_at=>1.minute.ago,:confirmed_at=>1.second.ago)
        dont_find.update_attributes(:updated_at=>1.day.ago)
        r = described_class.new.result_table
        r.count.should == 1
        r.first[5].should == @match_product.unique_identifier
      end
      it "should not return products without barthco customer ids" do
        @match_product.custom_values.destroy_all
        described_class.new.result_table.count.should == 0
      end
    end
    context "Full DB Prep" do #VERY TIME CONSUMING
      it 'should make_row_array' do
        @fields =
          [["*cf_1","Barthco Customer ID","Product"],
          ["*cf_2","Season","Product"],
          ["class_cntry_iso","NULL","NULL"],
          ["*cf_3","Product Area","Product"],
          ["*cf_4","Board Number","Product"],
          ["prod_uid","NULL","NULL"],
          ["*cf_6","Fiber Content %s","Product"],
          ["prod_name","NULL","NULL"],
          ["_blank","NULL","NULL"],
          ["*cf_8","Knit / Woven?","Product"],
          ["hts_hts_1","NULL","NULL"],
          ["hts_hts_1_qc","NULL","NULL"],
          ["hts_hts_1_gr","NULL","NULL"],
          ["hts_hts_2","NULL","NULL"],
          ["hts_hts_2_qc","NULL","NULL"],
          ["hts_hts_2_gr","NULL","NULL"],
          ["*cf_9","Stitch Count / 2cm Vertical","Product"],
          ["*cf_10","Stitch Count / 2cm Horizontal","Product"],
          ["*cf_11","Grams / Square Meter","Product"],
          ["*cf_12","Knit Type (Jersey, mesh, etc)","Product"],
          ["*cf_13","Type of Bottom (Hemmed, ribbed,etc)","Product"],
          ["*cf_14","Functional Neck Closure","Product"],
          ["*cf_15","Significantly Napped","Product"],
          ["*cf_16","Back Type / Shape","Product"],
          ["*cf_17","Defined Armholes","Product"],
          ["*cf_18","Strap Width (in.)","Product"],
          ["*cf_19","Pass Water Resistant Test AATC351995","Product"],
          ["*cf_20","Type of Coating","Product"],
          ["*cf_21","Padding or Filling?","Product"],
          ["*cf_22","Meets Down Requirments","Product"],
          ["*cf_23","Tightening at Waist (Cord, Ribbing, etc)","Product"],
          ["*cf_24","Denim","Product"],
          ["*cf_25","Denim color","Product"],
          ["*cf_26","Corduroy","Product"],
          ["*cf_27","Shearling","Product"],
          ["*cf_28","Total # of Back Panels","Product"],
          ["*cf_29","Short Fall Above Knee","Product"],
          ["*cf_30","Mesh Lining","Product"],
          ["*cf_31","Full Elastic Waistband","Product"],
          ["*cf_32","Full Functional Drawstring","Product"],
          ["*cf_33","Cover Crown Of Head","Product"],
          ["*cf_34","Wholly or Partially Braid","Product"],
          ["*cf_35","Yarn Dyed","Product"],
          ["*cf_36","# of Colors in Warp / Weft","Product"],
          ["*cf_37","Piece Dyed","Product"],
          ["*cf_38","Printed","Product"],
          ["*cf_39","Solid","Product"],
          ["*cf_40","Ounces / Sq Yd","Product"],
          ["*cf_41","Size Scale (S/M/L or 15/16/17)","Product"],
          ["*cf_42","Type of Fabric (velour, velvet, etc)","Product"],
          ["*cf_43","Weight of Fabric","Product"],
          ["*cf_44","Form Fitting or Loose Fitting","Product"],
          ["*cf_45","Functional Open Fly","Product"],
          ["*cf_46","Fly Covered With Open Placket","Product"],
          ["*cf_47","Tightening At Cuffs","Product"],
          ["*cf_48","Embellishments or Ornamentation","Product"],
          ["*cf_49","Sizing","Product"],
          ["*cf_50","Sold In Sleepwear Dept.","Product"],
          ["*cf_51","# pcs. in set","Product"],
          ["*cf_52","If more than 1 pc, sold as set?","Product"],
          ["*cf_53","Footwear Upper","Product"],
          ["*cf_54","Footwear Outsole","Product"],
          ["*cf_55","Welted","Product"],
          ["*cf_56","Covers Ankle","Product"],
          ["*cf_57","Length (cm)","Product"],
          ["*cf_58","Width (cm)","Product"],
          ["*cf_59","Height (cm)","Product"],
          ["*cf_60","Secure Closure","Product"],
          ["*cf_61","Closure Type","Product"],
          ["*cf_62","Multiple Compartment","Product"],
          ["*cf_63","Fourchettes for Gloves","Product"],
          ["*cf_64","Lined for Gloves","Product"],
          ["*cf_65","Seamed","Product"],
          ["*cf_66","Components","Product"],
          ["*cf_67","Cost of Component","Product"],
          ["*cf_68","Weight of Components","Product"],
          ["*cf_69","Material Content of Posts - Earrings","Product"],
          ["*cf_70","Filled","Product"],
          ["*cf_71","Type of Fill","Product"],
          ["*cf_72","Coated","Product"],
          ["_blank","NULL","NULL"],
          ["*cf_73","Semi-Precious","Product"],
          ["*cf_74","Type of Semi-Precious","Product"],
          ["*cf_75","Telescopic Shaft","Product"],
          ["*cf_76","Unit Price","Product"],
          ["prod_ven_syscode","NULL","NULL"],
          ["*cf_78","Country of Origin","Product"],
          ["*cf_79","Fish & Wildlife","Product"],
          ["*cf_80","Common Name (F&W)","Product"],
          ["*cf_81","Scientific Name","Product"],
          ["*cf_82","Origin of Wildlife","Product"],
          ["*cf_83","Source Indicator","Product"],
          ["*cf_84","Royalty %","Product"],
          ["*cf_102","Chart Comments","Product"],
          ["*cf_85","Binding Ruling Number","Classification"],
          ["*cf_86","Binding Ruling Type","Classification"],
          ["*cf_87","MID","Classification"],
          ["*cf_88","FDA Product Code","Classification"],
          ["*cf_89","Effective Date","Product"],
          ["*cf_90","Price UOM","Product"],
          ["*cf_91","Special Program Indicator","Classification"],
          ["*cf_92","CVD Case #","Classification"],
          ["*cf_93","ADD Case #","Classification"],
          ["*cf_94","PTP Code","Product"],
          ["*cf_95","Terms of Sale","Product"],
          ["*cf_131","Set Type","Classification"]]
   
        @custom_defs = {}
        @fields.each do |f|
          if f[0].match(/\*cf_/)
            cd = Factory(:custom_definition,:module_type=>f[2],:id=>f[0].split("_").last.to_i,:label=>f[1])
            @custom_defs[cd.id] = cd
          end
        end
        @product_to_send = Factory(:product,:unique_identifier=>'PUIDGD',
          :name=>"MYNAME",:vendor=>Factory(:company,:system_code=>"XYZ"))
        @classification = @product_to_send.classifications.create!(:country_id=>@us.id)
        @hts = @classification.tariff_records.create!(:hts_1=>'1234567890',:hts_2=>'9876543210')
        cust_vals = []
        @custom_defs.each do |id,d|
          obj = nil
          case d.module_type
          when 'Product'
            obj = @product_to_send
          when 'Classification'
            obj = @classification
          end
          v = obj.custom_values.build(:custom_definition_id => id)
          v.value = "#{d.id}-#{d.label}"
          cust_vals << v
        end
        CustomValue.batch_write! cust_vals
        @hard_code_values = {'class_cntry_iso'=>'US',
          'prod_uid'=>@product_to_send.unique_identifier,
          'prod_name'=>@product_to_send.name,
          'hts_hts_1'=>@hts.hts_1,
          'hts_hts_2'=>@hts.hts_2,
          'prod_ven_syscode'=>@product_to_send.vendor.system_code
        }
        rt = described_class.new.result_table
        rt.size.should == 1
        expected_values = []
        @fields.each do |f|
          case f[0]
          when /\*cf_/
            expected_values << "#{f[0].split("_").last}-#{f[1]}"
          else
            if @hard_code_values[f[0]]
              expected_values << @hard_code_values[f[0]]
            else
              expected_values << ''
            end
          end
        end
        rt.to_a.first.should == expected_values
      end
    end
  end
end
