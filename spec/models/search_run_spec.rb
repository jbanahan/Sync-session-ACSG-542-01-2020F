describe SearchRun do
  before :each do
    @u = create(:master_user)
  end
  describe "find_last_run" do
    it "should find newest for module & user" do
      find_me = create(:search_setup, :user=>@u, :module_type=>"Product")
      too_old = create(:search_setup, :user=>@u, :module_type=>"Product")
      wrong_module = create(:search_setup, :user=>@u, :module_type=>"Order")
      wrong_user = create(:search_setup, :module_type=>"Product")

      too_old.search_runs.create!(:last_accessed=>3.days.ago, :user_id=>@u.id)
      find_me.search_runs.create!(:last_accessed=>2.days.ago, :user_id=>@u.id)
      wrong_module.search_runs.create!(:last_accessed=>1.day.ago, :user_id=>@u.id)
      wrong_user.search_runs.create!(:last_accessed=>1.day.ago, :user_id=>wrong_user.user_id)

      expect(SearchRun.find_last_run(@u, CoreModule::PRODUCT)).to eq(find_me.search_runs.first)
    end
    it "should not be read only" do
      find_me = create(:search_setup, :user=>@u, :module_type=>"Product")
      find_me.touch
      expect(SearchRun.find_last_run(@u, CoreModule::PRODUCT)).not_to be_readonly
    end
  end
  describe "parent" do
    before :each do
      @cf = create(:custom_file)
    end
    it "should return search setup if it exists" do
      ss = create(:search_setup)
      im = create(:imported_file)
      sr = SearchRun.create(:search_setup_id=>ss.id, :imported_file_id=>im.id, :custom_file_id=>@cf.id)
      expect(sr.parent).to eq(ss)
    end
    it "should return imported_file if it exists and search setup doesn't" do
      im = create(:imported_file)
      sr = SearchRun.create(:imported_file_id=>im.id, :custom_file_id=>@cf.id)
      expect(sr.parent).to eq(im)
    end
    it "should return custom_file if it exists and search_setup/imported_file don't" do
      sr = SearchRun.create(:custom_file_id=>@cf.id)
      expect(sr.parent).to eq(@cf)
    end
  end
  describe "find_all_object_keys / total_objects" do
    before :each do
      @p1 = create(:product)
      @p2 = create(:product)
      @p3 = create(:product)
    end
    it "should find based on search_setup" do
      ss = create(:search_setup, :module_type=>"Product", :user=>@u)
      sr = ss.search_runs.create!
      products = []
      sr.find_all_object_keys {|k| products << Product.find(k)}
      expect(products).to eq([@p1, @p2, @p3])
      expect(sr.total_objects).to eq(3)
    end
    it "should return a sized Enumerator if no block is given" do
      ss = create(:search_setup, :module_type=>"Product", :user=>@u)
      sr = ss.search_runs.create!

      keys = sr.find_all_object_keys

      expect(keys.size).to eq 3
      expect(keys.class).to eq Enumerator
      products = []
      keys.each {|k| products << Product.find(k)}
      expect(products).to eq [@p1, @p2, @p3]
    end

    it "should find based on imported_file" do
      fir = create(:file_import_result, :imported_file=>create(:imported_file, :module_type=>"Product"))
      [@p1, @p2].each {|p| fir.change_records.create!(:recordable_id=>p.id, :recordable_type=>"Product")}
      sr = fir.imported_file.search_runs.create!
      sr.user = @u
      products = []
      sr.find_all_object_keys {|k| products << Product.find(k)}
      expect(products).to eq([@p1, @p2])
      expect(sr.total_objects).to eq(2)
    end
    it "should find based on imported file with a user search" do
      fir = create(:file_import_result, :imported_file=>create(:imported_file, :module_type=>"Product"))
      fir.imported_file.search_criterions.create! model_field_uid: 'prod_uid', operator: 'eq', value: @p1.unique_identifier
      [@p1, @p2].each {|p| fir.change_records.create!(:recordable_id=>p.id, :recordable_type=>"Product")}
      sr = fir.imported_file.search_runs.create!
      sr.user = @u

      products = []
      expect(sr.total_objects).to eq(1)
      sr.find_all_object_keys {|k| products << Product.find(k)}
      expect(products).to eq([@p1])
    end
    it "should find based on custom file" do
      cf = create(:custom_file)
      [@p2, @p3].each {|p| cf.custom_file_records.create!(:linked_object_id=>p.id, :linked_object_type=>"Product")}
      sr = cf.search_runs.create!
      products = []
      sr.find_all_object_keys {|k| products << Product.find(k)}
      expect(products).to eq([@p2, @p3])
      expect(sr.total_objects).to eq(2)
    end
  end
end
