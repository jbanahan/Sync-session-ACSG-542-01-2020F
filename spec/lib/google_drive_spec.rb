require 'spec_helper'

# This set of specs takes quite a while to complete (25 seconds or so) as there are a number of HTTP 
# requests that are sent to the Google Drive API, each one from .5 to 1 second in length.
describe OpenChain::GoogleDrive do

  before :all do
    @user_email = "integration-dev@vandegriftinc.com"
    @test_folder = "spec-" + Random.rand(1000000).to_s
  end

  context :actions_on_existing_files do
    before :all do
      # Use windows newlines to ensure we're using binmode
      @contents = "This is the file contents.\r\nContents."
      @path = "#{@test_folder}/file.txt"

      # This is purely a time-saving measure.  These tests can take 3-4 seconds a piece,
      # so any time we can save time and upload a single file for the whole context is a win
      @file_id = OpenChain::GoogleDrive.upload_file @user_email, @path, StringIO.new(@contents)
    end

    after :all do
      OpenChain::GoogleDrive.delete_folder @user_email, @test_folder
    end

    before :each do
      @cleanup = []
    end

    after :each do
      @cleanup.each do |id|
        OpenChain::GoogleDrive.delete_by_id @user_email, id
      end
    end

    context :upload_file do
      it "should upload data to a folder" do
        @file_id.should_not be_nil
        @file_id.should eq OpenChain::GoogleDrive.find_file_id @user_email, @path
      end

      it "should upload data to a folder and update it inline" do
        # Basically, we just want to make sure we don't create multiple 
        # copies of the file..if the file exists, we're updating it.
        data = StringIO.new "This is the file contents.\r\nUpdated."
        second_id = OpenChain::GoogleDrive.upload_file @user_email, @path, data
        second_id.should eq @file_id

        # Verify the updated contents
        contents = OpenChain::GoogleDrive.download_to_tempfile(@user_email, @path) do |t|
          t.read
        end
        data.rewind
        contents.should eq data.read
      end

      it "should upload data to a folder at add a second identical file" do
        data = StringIO.new "This is the file contents.\r\nUpdated."
        second_id = OpenChain::GoogleDrive.upload_file @user_email, @path, data, overwrite_existing: false
        @cleanup << second_id
        second_id.should_not eq @file_id
      end
    end

    describe :find_folder_id do
      it "should find an id for the test folder" do
        # Just find an id for a folder we know should be there
        # The underlying method this uses already has thorough test coverage 
        # via all the other upload/download methods, so this is mostly just here as
        # a regression test on the API.
        id = OpenChain::GoogleDrive.find_folder_id @user_email, @test_folder
        id.should_not be_nil
      end
    end
    
    describe :find_file_id do
      it "should find a file id" do
        # Just find an id for a file we know should be there
        second_id = OpenChain::GoogleDrive.find_file_id @user_email, @path
        second_id.should eq @file_id
      end
    end

    context :download_to_tempfile do

      it "should download data to a tempfile and return the tempfile" do
        t = OpenChain::GoogleDrive.download_to_tempfile @user_email, @path
        begin
          # Makes sure the tempfile was rewound by just reading straight from the returned file
          # Because we're making consessions to running time, and are updateing the file data above
          # just make sure the file starts with the expected data.
          t.read.should match /^This is the file contents.\r\n/
        ensure
          t.close! if t
        end
      end

      it "should yield a tempfile with downloaded data to a block" do
        t_path = nil
        data = OpenChain::GoogleDrive.download_to_tempfile(@user_email, @path) do |t|
          t_path = t.path
          t.read
        end

        # Because we're making consessions to running time, and are updateing the file data above
        # just make sure the file starts with the data that remains the same across all cases.
        data.should match /^This is the file contents.\r\n/
        File.exists?(t_path).should be_false
      end

      it "should clean up tempfiles if block raises an exception" do
        t_path = nil
        expect {
          OpenChain::GoogleDrive.download_to_tempfile(@user_email, @path) do |t|
            t_path = t.path
            raise Exception, "Error!"
          end
        }.to raise_error Exception

        File.exists?(t_path).should be_false
      end
    end

  end

  context :delete do
    after :each do
      OpenChain::GoogleDrive.delete_folder @user_email, @test_folder
    end

    it "should delete a file" do
      path = "#{@test_folder}/file.txt"
      data = StringIO.new "This is the file contents."

      id = OpenChain::GoogleDrive.upload_file @user_email, path, data
      id.should_not be_nil

      OpenChain::GoogleDrive.delete @user_email, path

      id = OpenChain::GoogleDrive.find_file_id @user_email, path
      id.should be_nil
    end
  end

  context :delete_folder do
    after :each do
      OpenChain::GoogleDrive.delete_folder @user_email, @test_folder
    end

    it "should delete a folder and all files in the folder" do
      path = "#{@test_folder}/file.txt"
      data = StringIO.new "This is the file contents."

      id = OpenChain::GoogleDrive.upload_file @user_email, path, data
      id.should_not be_nil

      OpenChain::GoogleDrive.delete_folder @user_email, @test_folder

      id = OpenChain::GoogleDrive.find_file_id @user_email, path
      id.should be_nil

      id = OpenChain::GoogleDrive.find_folder_id @user_email, @test_folder
      id.should be_nil
    end
  end

  context :cached_get_client do
    it "should cache client creation" do
      OpenChain::GoogleDrive.find_file_id @user_email, "file.txt"
      OpenChain::GoogleDrive.should_not_receive(:initialize_client_info)
      OpenChain::GoogleDrive.find_file_id @user_email, "file.txt"
    end
  end

  context :default_user_account do
    it "should default based on environment" do
      OpenChain::GoogleDrive.default_user_account.should eq "integration-dev@vandegriftinc.com"
    end

    it "should default to integration-dev in any non-production environment" do
      OpenChain::GoogleDrive.default_user_account("madeup").should eq "integration-dev@vandegriftinc.com"
    end

    it "should default to integration in production environment" do
      OpenChain::GoogleDrive.default_user_account("production").should eq "integration@vandegriftinc.com"
    end
  end

end