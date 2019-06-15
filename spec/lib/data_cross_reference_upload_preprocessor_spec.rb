describe OpenChain::DataCrossReferenceUploadPreprocessor do
  describe "preprocessor_for_xref" do
    context "if xref-type missing/unrecognized" do
      it "returns an 'identity' lambda if xref-type unrecognized" do
        preproc = described_class.preprocessors["none"]
        expect(preproc.call("x", "y")).to eq({key: "x", value: "y"})
      end
    end

    context "asce_mid" do
      let(:target) { "2017-03-15" }
      let(:preproc) { described_class.preprocessors["asce_mid"] }

      it "parses date for M-D-Y, M/D/Y, Y/M/D, Y-M-D" do
        expect(preproc.call("x", "3/15/2017")).to eq({key: 'x', value: target})
        expect(preproc.call("x", "3-15-2017")).to eq({key: 'x', value: target})
        expect(preproc.call("x", "2017-3-15")).to eq({key: 'x', value: target})
        expect(preproc.call("x", "2017/3/15")).to eq({key: 'x', value: target})
      end

      it "returns nil for bad input" do
        expect(preproc.call("x", "3/foo/2017")).to eq({key: 'x', value: nil})
        expect(preproc.call("x", "3/35/2017")).to eq({key: 'x', value: nil})
      end
    end
  end

end