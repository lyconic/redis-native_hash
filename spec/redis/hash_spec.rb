describe Redis::Hash do
  before :each do
    @hash = Redis::Hash.new :test, "foo" => "bar"
    @hash.save
  end

  describe "#save" do
    it "should presist changes to existing hash key" do
      @hash["foo"] = "something else"
      @hash.save
      hash = Redis::Hash.find :test => @hash.key
      hash["foo"].should == "something else"
    end
    it "should persist new hash keys" do
      @hash["yin"] = "yang"
      @hash.save
      hash = Redis::Hash.find :test => @hash.key
      hash["yin"].should == "yang"
    end
    it "should remove deleted keys from redis" do
      @hash["yin"] = "yang"
      @hash.delete("foo")
      @hash["foo"].should == nil
      @hash.save
      hash = Redis::Hash.find :test => @hash.key
      hash["foo"].should == nil
    end
    it "should respect changes made since last read from redis" do
      concurrent_edit = Redis::Hash.find :test => @hash.key
      concurrent_edit["foo"] = "race value"
      concurrent_edit.save
      @hash["yin"] = "yang"
      @hash["foo"] = "bad value"
      @hash.save
      hash = Redis::Hash.find :test => @hash.key
      hash["foo"].should == "race value"
      hash["yin"].should == "yang"
    end
    it "should respect removed hash keys since last read" do
      concurrent_edit = Redis::Hash.find :test => @hash.key
      concurrent_edit["yin"] = "yang"
      concurrent_edit.delete("foo")
      concurrent_edit.save
      @hash["foo"] = "bad value"
      @hash.save
      hash = Redis::Hash.find :test => @hash.key
      hash["foo"].should == nil
      hash["yin"].should == "yang"
    end
    it "should allow overwrite of concurrent edit after #reload! is called" do
      concurrent_edit = Redis::Hash.find :test => @hash.key
      concurrent_edit["yin"] = "yang"
      concurrent_edit.delete("foo")
      concurrent_edit.save
      @hash.reload!
      @hash["foo"].should == nil
      @hash["foo"] = "good value"
      @hash.save
      hash = Redis::Hash.find :test => @hash.key
      hash["foo"].should == "good value"
    end
    it "should treat string and symbolic keys the same" do
      @hash[:foo].should == "bar"
      @hash[:test] = "good value"
      @hash["test"].should == "good value"
      @hash.save
      hash = Redis::Hash.find :test => @hash.key
      hash[:test].should == "good value"
      hash["test"].should == "good value"
    end
    it "should properly store nested hashes" do
      @hash[:test] = { :foo => :bar, :x => { :y => "z" } }
      @hash[:test][:x][:y].should == "z"
      @hash.save
      hash = Redis::Hash.find :test => @hash.key
      hash[:test][:foo].should == :bar
      hash[:test][:x][:y].should == "z"
    end
  end

  describe ".find" do
    it "should find an existing redis hash" do
      hash = Redis::Hash.find :test => @hash.key
      hash["foo"].should == "bar"
    end
    it "should return nil when hash not found" do
      hash = Redis::Hash.find :foo => :doesnt_exist
      hash.should == nil
    end
  end

  after :each do
    #@hash.destroy
  end
end

