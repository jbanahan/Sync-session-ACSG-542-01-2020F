require 'spec_helper'

describe ApplicationController do

  describe :strip_uri_params do
    it "should remove specified parameters from a URI string" do
      uri = "http://www.test.com/file.html?id=1&k=2&val[nested]=2#hash"
      r = controller.strip_uri_params uri, "id"
      r.should == "http://www.test.com/file.html?k=2&val[nested]=2#hash"
    end

    it "should not leave a dangling ? if query string is blank" do
      uri = "http://www.test.com/?k=2"
      r = controller.strip_uri_params uri, "k"
      r.should == "http://www.test.com/"
    end

    it "should handle blank query strings" do
      uri = "http://www.test.com"
      r = controller.strip_uri_params uri, "k"
      r.should == "http://www.test.com"
    end

    it "should handle missing keys" do
      uri = "http://www.test.com"
      r = controller.strip_uri_params uri
      r.should == "http://www.test.com"
    end
  end

end
