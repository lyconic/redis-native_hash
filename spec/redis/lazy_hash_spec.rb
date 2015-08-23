require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

# MOST OF THIS COPIED FROM native_hash_spec !!!!
# Redis::LazyHash should behave pretty much the same as Redis::LazyHash
# only, lazier...

describe Redis::LazyHash do
  before :each do
    @hash = Redis::LazyHash.new :test
    @hash.update("foo" => "bar")
    @hash.save
    @hash = Redis::LazyHash.new :test => @hash.key
  end

  describe "#loaded?" do
    it "should not be loaded when no read/write has occurred" do
      @hash.loaded?.should be(false)
    end
    it "should be loaded after a read occurs" do
      @hash[:foo]
      @hash.loaded?.should be(true)
    end
  end

  describe "#save" do
    it "should presist changes to existing hash key" do
      @hash["foo"] = "something else"
      @hash.save
      hash = Redis::LazyHash.find :test => @hash.key
      hash["foo"].should == "something else"
    end
    it "should persist new hash keys" do
      @hash["yin"] = "yang"
      @hash.save
      hash = Redis::LazyHash.find :test => @hash.key
      hash["yin"].should == "yang"
    end
    it "should remove deleted keys from redis" do
      @hash["yin"] = "yang"
      @hash.delete("foo")
      @hash["foo"].should == nil
      @hash.save
      hash = Redis::LazyHash.find :test => @hash.key
      hash["foo"].should == nil
    end
    it "should respect changes made since last read from redis" do
      @hash.inspect # have to touch the hash first
      concurrent_edit = Redis::LazyHash.find :test => @hash.key
      concurrent_edit["foo"] = "race value"
      concurrent_edit.save
      @hash["yin"] = "yang"
      @hash["foo"] = "bad value"
      @hash.save
      hash = Redis::LazyHash.find :test => @hash.key
      hash["foo"].should == "race value"
      hash["yin"].should == "yang"
    end
    it "should respect removed hash keys since last read" do
      @hash.inspect
      concurrent_edit = Redis::LazyHash.find :test => @hash.key
      concurrent_edit["yin"] = "yang"
      concurrent_edit.delete("foo")
      concurrent_edit.save
      @hash["foo"] = "bad value"
      @hash.save
      hash = Redis::LazyHash.find :test => @hash.key
      hash["foo"].should == nil
      hash["yin"].should == "yang"
    end
    it "should allow overwrite of concurrent edit after #reload! is called" do
      @hash.inspect
      concurrent_edit = Redis::LazyHash.find :test => @hash.key
      concurrent_edit["yin"] = "yang"
      concurrent_edit.delete("foo")
      concurrent_edit.save
      @hash.reload!
      @hash["foo"].should == nil
      @hash["foo"] = "good value"
      @hash.save
      hash = Redis::LazyHash.find :test => @hash.key
      hash["foo"].should == "good value"
    end
    it "should treat string and symbolic keys the same" do
      @hash[:foo].should == "bar"
      @hash[:test] = "good value"
      @hash["test"].should == "good value"
      @hash.save
      hash = Redis::LazyHash.find :test => @hash.key
      hash[:test].should == "good value"
      hash["test"].should == "good value"
    end
    it "should properly store nested hashes" do
      @hash[:test] = { :foo => :bar, :x => { :y => "z" } }
      @hash[:test][:x][:y].should == "z"
      @hash.save
      hash = Redis::LazyHash.find :test => @hash.key
      hash[:test][:foo].should == :bar
      hash[:test][:x][:y].should == "z"
    end
  end

  describe "#renew" do
    it "should generate a new key" do
      old_key = @hash.key
      new_key = @hash.renew_key
      @hash.key.should eq(new_key)
      @hash.key.should_not eq(old_key)
    end
    it "should remove the old hash from redis" do
      old_key   = @hash.key
      namespace = @hash.namespace
      @hash.renew_key
      hash = Redis::LazyHash.find namespace => old_key
      hash.inspect
      hash.size.should == 0
    end
    it "should not persist the hash under the new key until #save is called" do
      @hash["good key"] = "good value"
      key = @hash.renew_key
      bad_hash = Redis::LazyHash.find :test => key
      bad_hash.size.should == 0
      @hash.save
      good_hash = Redis::LazyHash.find :test => key
      good_hash["good key"].should eq("good value")
      good_hash["foo"].should      eq("bar")
    end
  end

  describe "#key=" do
    it "should allow an arbitrary key to be used" do
      @hash.key = "blah@blah.com"
      @hash.save
      a_hash = Redis::LazyHash.find :test => "blah@blah.com"
      a_hash["foo"].should eq('bar')
    end
    it "should not leave the old hash behind when the key is changed" do
      old_key = @hash.key
      @hash.key = "carl@linkleaf.com"
      @hash.save
      bad_hash = Redis::LazyHash.find :test => old_key
      bad_hash.size.should == 0
    end
  end

  describe ".find" do
    it "should find an existing redis hash" do
      hash = Redis::LazyHash.find :test => @hash.key
      hash["foo"].should == "bar"
    end
    it "should return an empty hash when hash not found" do
      hash = Redis::LazyHash.find :foo => :doesnt_exist
      hash.size.should == 0
    end
  end


  after :each do
    @hash.destroy
  end
end
