describe OpenChain::CustomHandler::CustomFileToImportedFilePassthroughHandler do

  subject {
    Class.new do
      include OpenChain::CustomHandler::CustomFileToImportedFilePassthroughHandler
    end.new
  }

  describe "process_file" do
    let(:user) { Factory(:user) }
    let(:search_setup_attributes) { {name: "Search", user_id: user.id, module_type: "Product"} }
    let(:search_column_uids) { [:prod_uid, :prod_name] }
    let(:file_data) {[["uid", "name"], ["uid2", "name2"]]}
    let (:custom_file) {
      custom_file = CustomFile.new attached_file_name: "file.xlsx"
      allow(custom_file).to receive(:path).and_return "/path/to/file.xlsx"
      custom_file
    }


    context "with full setup", :without_partial_double_verification do
      before :each do
        allow(subject).to receive(:search_setup_attributes).and_return search_setup_attributes
        allow(subject).to receive(:search_column_uids).and_return search_column_uids
        allow(subject).to receive(:foreach).and_yield(file_data[0]).and_yield(file_data[1])
      end

      context "with multi-dimensional array returned" do
        before :each do
          allow(subject).to receive(:translate_file_line) do |row|
            [row.map {|v| v.to_s + " translated" }, row.map {|v| v.to_s + " translated" }]
          end
        end
        it "generates a new search setup and runs an imported file through it" do
          expect_any_instance_of(ImportedFile).to receive(:process).with user
          contents = nil
          expect_any_instance_of(ImportedFile).to receive(:attached=) do |instance, f|
            contents = f.read
          end
          subject.process_file custom_file, user

          f = ImportedFile.first
          expect(f.update_mode).to eq "any"
          expect(f.starting_row).to eq 1
          expect(f.starting_column).to eq 1
          expect(f.module_type).to eq "Product"
          expect(f.user).to eq user
          expect(contents).to eq "uid translated,name translated\nuid translated,name translated\nuid2 translated,name2 translated\nuid2 translated,name2 translated\n"

          ss = f.search_setup
          expect(ss).not_to be_nil
          expect(ss.name).to eq "Search"
          expect(ss.user).to eq user
          expect(ss.module_type).to eq "Product"

          # Make sure the expected search columns are created and in the expected order
          uids = ss.search_columns.map(&:model_field_uid)

          expect(uids).to eq search_column_uids.map(&:to_s)
        end

        it "re-uses an existing search setup" do
          expect_any_instance_of(ImportedFile).to receive(:process).with user
          ss = SearchSetup.create! name: "Search", module_type: "Product", user_id: user.id
          search_column_uids.each {|uid| ss.search_columns.create! model_field_uid: uid}

          subject.process_file custom_file, user

          f = ImportedFile.first
          expect(f.search_setup).to eq ss
        end

        it "errors if existing search setup does not match the expected format" do
          ss = SearchSetup.create! name: "Search", module_type: "Product", user_id: user.id
          ss.search_columns.create! model_field_uid: :prod_name

          expect { subject.process_file(custom_file, user) }.to raise_error "Expected to find the field 'Unique Identifier' in column 1, but found field 'Name' instead."
        end
      end

      context "with array returned from translate file line" do
        before :each do
          allow(subject).to receive(:translate_file_line) do |row|
            row.map {|v| v.to_s + " translated" }
          end
        end

        it "handles returning an array from translate_file_line" do
          expect_any_instance_of(ImportedFile).to receive(:process).with user
          contents = nil
          expect_any_instance_of(ImportedFile).to receive(:attached=) do |instance, f|
            contents = f.read
          end
          subject.process_file custom_file, user

          f = ImportedFile.first
          expect(contents).to eq "uid translated,name translated\nuid2 translated,name2 translated\n"
        end
      end
    end
  end
end