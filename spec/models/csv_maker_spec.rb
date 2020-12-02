describe CsvMaker do
  context "make_from_search_query" do
    before :each do
      @logged_date = DateTime.civil_from_format(:utc, 2014, 7, 15, 12, 26, 22)
      @entry = create(:entry, :first_it_date=>Date.new(2014, 7, 30), :file_logged_date=>@logged_date, :broker_reference => "x")
      @entry.reload # get right rails date objects
      @u = create(:master_user, :entry_view=>true, :time_zone=>"Hawaii")
      @search = SearchSetup.create!(:name=>'t', :user=>@u, :module_type=>'Entry')
      @search.search_columns.create!(:model_field_uid=>'ent_first_it_date', :rank=>1)
      @search.search_columns.create!(:model_field_uid=>'ent_file_logged_date', :rank=>2)
      @search.search_criterions.create! model_field_uid: 'ent_brok_ref', operator: "eq", value: "x"
      @query = SearchQuery.new @search, @u
      allow_any_instance_of(MasterSetup).to receive(:request_host).and_return "localhost"
    end

    it "should build a csv file from a search query" do
      opts_hash = {}
      raw_csv, data_row_count = CsvMaker.new.make_from_search_query(@query, opts_hash)
      csv = CSV.parse raw_csv
      expect(data_row_count).to eq 1
      expect(csv.length).to eq 2
      expect(csv[0]).to eq [ModelField.find_by_uid(:ent_first_it_date).label, ModelField.find_by_uid(:ent_file_logged_date).label]
      expect(csv[1]).to eq [@entry.first_it_date.strftime("%Y-%m-%d"), @entry.file_logged_date.in_time_zone("Hawaii").strftime("%Y-%m-%d %H:%M")]
      expect(opts_hash[:raise_max_results_error]).to eq(true)
    end

    it "should count 0 rows when csv is empty" do
      @entry.destroy
      *, data_row_count = CsvMaker.new.make_from_search_query(@query)
      expect(data_row_count).to eq 0
    end

    it "should add web links" do
      maker = CsvMaker.new(include_links: true, include_rule_links: true)
      csv = CSV.parse maker.make_from_search_query(@query).first
      expect(csv.length).to eq 2
      expect(csv[0]).to eq [ModelField.find_by_uid(:ent_first_it_date).label, ModelField.find_by_uid(:ent_file_logged_date).label, "Links", "Business Rule Links"]
      expect(csv[1]).to eq [@entry.first_it_date.strftime("%Y-%m-%d"), @entry.file_logged_date.in_time_zone("Hawaii").strftime("%Y-%m-%d %H:%M"), @entry.view_url, "http://localhost:3000/entries/#{@entry.id}/validation_results"]
    end

    it "should not include time" do
      csv = CSV.parse CsvMaker.new(no_time: true).make_from_search_query(@query).first
      expect(csv.length).to eq 2
      expect(csv[0]).to eq [ModelField.find_by_uid(:ent_first_it_date).label, ModelField.find_by_uid(:ent_file_logged_date).label]
      expect(csv[1]).to eq [@entry.first_it_date.strftime("%Y-%m-%d"), @entry.file_logged_date.in_time_zone("Hawaii").strftime("%Y-%m-%d")]
    end

    it "should strip newline characters" do
      val = "abc\ndef"
      create(:product, :unique_identifier=>val)
      ss = create(:search_setup, :module_type=>"Product", :user=>create(:master_user))
      ss.search_criterions.create! model_field_uid: "prod_uid", operator: "notnull"
      ss.search_columns.create!(:model_field_uid=>'prod_uid')
      r = CsvMaker.new.make_from_search_query(SearchQuery.new(ss, ss.user)).first
      arrays = CSV.parse r
      expect(arrays[1][0]).to eq("abc def")
    end
    it "should strip carriage return characters" do
      val = "abc\rdef"
      create(:product, :unique_identifier=>val)
      ss = create(:search_setup, :module_type=>"Product", :user=>create(:master_user))
      ss.search_criterions.create! model_field_uid: "prod_uid", operator: "notnull"
      ss.search_columns.create!(:model_field_uid=>'prod_uid')
      r = CsvMaker.new.make_from_search_query(SearchQuery.new(ss, ss.user)).first
      arrays = CSV.parse r
      expect(arrays[1][0]).to eq("abc def")
    end
    it "should strip crlf" do
      val = "abc\r\ndef"
      create(:product, :unique_identifier=>val)
      ss = create(:search_setup, :module_type=>"Product", :user=>create(:master_user))
      ss.search_criterions.create! model_field_uid: "prod_uid", operator: "notnull"
      ss.search_columns.create!(:model_field_uid=>'prod_uid')
      r = CsvMaker.new.make_from_search_query(SearchQuery.new(ss, ss.user)).first
      arrays = CSV.parse r
      expect(arrays[1][0]).to eq("abc  def")
    end

    it "should output nil values as blank" do
      @entry.update_attributes first_it_date: nil
      csv = CSV.parse CsvMaker.new.make_from_search_query(@query).first
      expect(csv.length).to eq 2
      expect(csv[1]).to eq ["", @entry.file_logged_date.in_time_zone("Hawaii").strftime("%Y-%m-%d %H:%M")]
    end

    it "raises an error if the report is not downloadable" do
      ss = create(:search_setup, :module_type=>"Product", :user=>create(:master_user))
      expect(ss).to receive(:downloadable?) {|e| e << "Error!"; false}

      expect {CsvMaker.new.make_from_search_query(SearchQuery.new(ss, ss.user))}.to raise_error "Error!"
    end
  end
end
