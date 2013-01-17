require 'spec_helper'

describe AttachmentArchiveManifestsController do
 describe :create do
  it "should create manifest and delay manifest generation"
  it "should fail if user cannot view archives"
 end
 describe :get do
  it "should respond with 204 if manifest not done"
  it "should respond with 200 and attachment if done"
  it "should fail if user cannot view "
 end
end
