require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe RedisHash do
  before :each do
    @hash = RedisHash.new :test, "foo" => "bar"
    @hash.save
  end

  describe "#save" do
    it "should presist changes to existing hash key" do
      @hash["foo"] = "something else"
      @hash.save
      hash = RedisHash.find :test => @hash.key
      hash["foo"].should == "something else"
    end
    it "should persist new hash keys" do
      @hash["yin"] = "yang"
      @hash.save
      hash = RedisHash.find :test => @hash.key
      hash["yin"].should == "yang"
    end
    it "should remove deleted keys from redis" do
      @hash["yin"] = "yang"
      @hash.delete("foo")
      @hash["foo"].should == nil
      @hash.save
      hash = RedisHash.find :test => @hash.key
      hash["foo"].should == nil
    end
    it "should respect changes made since last read from redis" do
      concurrent_edit = RedisHash.find :test => @hash.key
      concurrent_edit["foo"] = "race value"
      concurrent_edit.save
      @hash["yin"] = "yang"
      @hash["foo"] = "bad value"
      @hash.save
      hash = RedisHash.find :test => @hash.key
      hash["foo"].should == "race value"
      hash["yin"].should == "yang"
    end
    it "should respect removed hash keys since last read" do
      concurrent_edit = RedisHash.find :test => @hash.key
      concurrent_edit["yin"] = "yang"
      concurrent_edit.delete("foo")
      concurrent_edit.save
      @hash["foo"] = "bad value"
      @hash.save
      hash = RedisHash.find :test => @hash.key
      hash["foo"].should == nil
      hash["yin"].should == "yang"
    end
    it "should allow overwrite of concurrent edit after #reload! is called" do
      concurrent_edit = RedisHash.find :test => @hash.key
      concurrent_edit["yin"] = "yang"
      concurrent_edit.delete("foo")
      concurrent_edit.save
      @hash.reload!
      @hash["foo"].should == nil
      @hash["foo"] = "good value"
      @hash.save
      hash = RedisHash.find :test => @hash.key
      hash["foo"].should == "good value"
    end
    it "should treat string and symbolic keys the same" do
      @hash[:foo].should == "bar"
      @hash[:test] = "good value"
      @hash["test"].should == "good value"
      @hash.save
      hash = RedisHash.find :test => @hash.key
      hash[:test].should == "good value"
      hash["test"].should == "good value"
    end
    it "should properly store nested hashes" do
      @hash[:test] = { :foo => :bar, :x => { :y => "z" } }
      @hash[:test][:x][:y].should == "z"
      @hash.save
      hash = RedisHash.find :test => @hash.key
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
      hash = RedisHash.find namespace => old_key
      hash.should be_nil
    end
    it "should not persist the hash under the new key until #save is called" do
      @hash["good key"] = "good value"
      key = @hash.renew_key
      bad_hash = RedisHash.find :test => key
      bad_hash.should be_nil
      @hash.save
      good_hash = RedisHash.find :test => key
      good_hash["good key"].should eq("good value")
      good_hash["foo"].should      eq("bar")
    end
  end

  describe ".find" do
    it "should find an existing redis hash" do
      hash = RedisHash.find :test => @hash.key
      hash["foo"].should == "bar"
    end
    it "should return nil when hash not found" do
      hash = RedisHash.find :foo => :doesnt_exist
      hash.should == nil
    end
  end

  after :each do
    @hash.destroy
  end
end

