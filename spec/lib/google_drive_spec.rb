require 'spec_helper'
require 'socket'

# This set of specs takes quite a while to complete (25 seconds or so) as there are a number of HTTP 
# requests that are sent to the Google Drive API, each one from .5 to 1 second in length.
describe OpenChain::GoogleDrive do

  before :all do
    @user_email = "integration-dev@vandegriftinc.com"
    @test_folder = "spec-" + Random.rand(1000000).to_s + "-" + Socket.gethostname
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
      # Basically, we're just retrying and only finishing the test if the folder is actually gone
      folder_id = nil
      count = 0
      begin
        OpenChain::GoogleDrive.delete_folder @user_email, @test_folder
        folder_id = OpenChain::GoogleDrive.find_folder_id @user_email, @test_folder
      end while (count += 1) < 5 && !folder_id.nil? && sleep(0.5)
    end

    before :each do
      @cleanup = []
    end

    after :each do
      @cleanup.each do |id|
        retry_expect(retry_count: 5, retry_wait: 0.5, additional_rescue_from: [StandardError]) {
          OpenChain::GoogleDrive.delete_by_id @user_email, id
          expect(OpenChain::GoogleDrive.find_file_id(@user_email, @path)).to be_nil
        } rescue Google::APIClient::ClientError
      end if @cleanup
    end

    context :upload_file do
      it "should upload data to a folder" do
        retry_expect(additional_rescue_from: [StandardError]) {
          expect(OpenChain::GoogleDrive.find_file_id(@user_email, @path)).to eq @file_id
        }
      end

      it "should upload data to a folder and update it inline" do
        # Basically, we just want to make sure we don't create multiple 
        # copies of the file..if the file exists, we're updating it.
        data = StringIO.new "This is the file contents.\r\nUpdated."
        second_id = OpenChain::GoogleDrive.upload_file @user_email, @path, data
        expect(second_id).to eq @file_id
        data.rewind

        expected_data = data.read

        retry_expect(additional_rescue_from: [StandardError]) {
          # Verify the updated contents
          contents = OpenChain::GoogleDrive.download_to_tempfile(@user_email, @path) do |t|
            t.read
          end
          expect(contents).to eq expected_data
        }
        
      end

      it "should upload data to a folder at add a second identical file" do
        data = StringIO.new "This is the file contents.\r\nUpdated."
        second_id = OpenChain::GoogleDrive.upload_file @user_email, @path, data, overwrite_existing: false
        @cleanup << second_id
        expect(second_id).not_to eq @file_id
      end
    end

    describe "find_folder_id" do
      it "should find an id for the test folder" do
        # Just find an id for a folder we know should be there
        # The underlying method this uses already has thorough test coverage 
        # via all the other upload/download methods, so this is mostly just here as
        # a regression test on the API.
        retry_expect(additional_rescue_from: [StandardError]) {
          expect(OpenChain::GoogleDrive.find_folder_id(@user_email, @test_folder)).not_to be_nil
        }
      end
    end
    
    describe "find_file_id" do
      it "should find a file id" do
        # Just find an id for a file we know should be there
        retry_expect(additional_rescue_from: [StandardError]) {
          expect(OpenChain::GoogleDrive.find_file_id(@user_email, @path)).to eq @file_id
        }
      end
    end

    context :download_to_tempfile do

      it "should download data to a tempfile and return the tempfile" do
        retry_expect(additional_rescue_from: [StandardError]) {
          t = OpenChain::GoogleDrive.download_to_tempfile @user_email, @path
          begin
            # Makes sure the tempfile was rewound by just reading straight from the returned file
            # Because we're making consessions to running time, and are updateing the file data above
            # just make sure the file starts with the expected data.
            expect(t.read).to match /^This is the file contents.\r\n/
          ensure
            t.close! if t
          end
        }
        
      end

      it "should yield a tempfile with downloaded data to a block" do
        retry_expect(additional_rescue_from: [StandardError]) {
          t_path = nil
          data = OpenChain::GoogleDrive.download_to_tempfile(@user_email, @path) do |t|
            t_path = t.path
            t.read
          end

          # Because we're making consessions to running time, and are updateing the file data above
          # just make sure the file starts with the data that remains the same across all cases.
          expect(data).to match /^This is the file contents.\r\n/
          expect(File.exists?(t_path)).to be_falsey
        }
      end

      it "should clean up tempfiles if block raises an exception" do
        retry_expect(additional_rescue_from: [StandardError]) {
          t_path = nil
          expect {
            OpenChain::GoogleDrive.download_to_tempfile(@user_email, @path) do |t|
              t_path = t.path
              raise ArgumentError, "Error!"
            end
          }.to raise_error ArgumentError

          expect(File.exists?(t_path)).to be_falsey
        }
      end
    end

    context "get_file_owner_email" do
      it "returns the owner email" do
        retry_expect(additional_rescue_from: [StandardError]) {
          expect(OpenChain::GoogleDrive.get_file_owner_email(@user_email, @path)).to eq @user_email
        }
      end

      it "returns nil if owner can't be found" do
        expect(OpenChain::GoogleDrive.get_file_owner_email(@user_email, "notafile")).to be_nil
      end
    end

    describe "remove_file_from_folder" do
      it "removes a file from the given parent's folder" do
        expect(OpenChain::GoogleDrive.remove_file_from_folder(@user_email, @path))

        retry_expect(additional_rescue_from: [StandardError]) {
          expect(OpenChain::GoogleDrive.find_file_id(@user_email, @path)).to be_nil
        }
      end
    end
  end

  context :delete do
    after :each do
      # Basically, we're just retrying and only finishing the test if the folder is actually gone
      folder_id = nil
      count = 0
      begin
        OpenChain::GoogleDrive.delete_folder @user_email, @test_folder
        folder_id = OpenChain::GoogleDrive.find_folder_id @user_email, @test_folder
      end while (count += 1) < 5 && !folder_id.nil? && sleep(0.5)
    end

    it "should delete a file" do
      path = "#{@test_folder}/file.txt"
      data = StringIO.new "This is the file contents."

      retry_expect {
        expect(OpenChain::GoogleDrive.upload_file(@user_email, path, data)).not_to be_nil
      }

      OpenChain::GoogleDrive.delete @user_email, path

      retry_expect(additional_rescue_from: [StandardError]) {
        expect(OpenChain::GoogleDrive.find_file_id(@user_email, path)).to be_nil
      }
    end
  end

  context :delete_folder do
    after :each do
      # Basically, we're just retrying and only finishing the test if the folder is actually gone
      retry_expect(retry_count: 5, retry_wait: 0.5) {
        OpenChain::GoogleDrive.delete_folder @user_email, @test_folder
        expect(OpenChain::GoogleDrive.find_folder_id(@user_email, @test_folder)).to be_nil
      }
    end

    it "should delete a folder and all files in the folder" do
      path = "#{@test_folder}/file.txt"
      data = StringIO.new "This is the file contents."

      retry_expect {
        expect(OpenChain::GoogleDrive.upload_file(@user_email, path, data)).not_to be_nil
      }

      OpenChain::GoogleDrive.delete_folder @user_email, @test_folder

      retry_expect(additional_rescue_from: [StandardError]) {
        expect(OpenChain::GoogleDrive.find_file_id(@user_email, path)).to be_nil
      }

      retry_expect(additional_rescue_from: [StandardError]) {
        expect(OpenChain::GoogleDrive.find_folder_id(@user_email, @test_folder)).to be_nil
      }
    end
  end

  context :cached_get_client do
    it "should cache client creation" do
      OpenChain::GoogleDrive.find_file_id @user_email, "file.txt"
      expect(OpenChain::GoogleDrive).not_to receive(:initialize_client_info)
      OpenChain::GoogleDrive.find_file_id @user_email, "file.txt"
    end
  end

  context :default_user_account do
    it "should default based on environment" do
      expect(OpenChain::GoogleDrive.default_user_account).to eq "integration-dev@vandegriftinc.com"
    end

    it "should default to integration-dev in any non-production environment" do
      expect(OpenChain::GoogleDrive.default_user_account("madeup")).to eq "integration-dev@vandegriftinc.com"
    end

    it "should default to integration in production environment" do
      expect(OpenChain::GoogleDrive.default_user_account("production")).to eq "integration@vandegriftinc.com"
    end
  end

end