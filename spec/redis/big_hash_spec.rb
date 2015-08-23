require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Redis::BigHash do
  before :each do
    @hash = Redis::BigHash.new
    @hash[:foo] = "bar"
    @hash[:yin] = "yang"
  end

  describe "#[]" do
    it "should read an existing value" do
      @hash[:foo].should == "bar"
    end
    it "should get nil for a value that doesn't exist" do
      @hash[:bad_key].should be_nil
    end
    it "should allow lookup of multiple keys, returning an array" do
      @hash[:foo, :yin, :bad_key].should == ["bar", "yang", nil]
    end
  end

  describe "#[]=" do
    it "should store string values" do
      str = "This is a test string"
      @hash[:test] = str
      @hash[:test].should == str
    end
    it "should store arbitrary objects" do
      t = Time.now
      @hash[:test] = t
      @hash[:test].should == t
    end
  end

  describe "#add" do
    it "should not overwrite an existing value" do
      @hash.add(:foo, "bad value")
      @hash[:foo].should == "bar"
    end
    it "should set a value when it doesn't exist" do
      @hash.add(:new_key, "good value")
      @hash[:new_key].should == "good value"
    end
  end

  describe "#key=" do
    it "should change the key used" do
      @hash[:testing] = "key change"
      @hash.key = "some_new_key"
      @hash.key.should == "some_new_key"
    end
    it "should move all hash data to a new key" do
      @hash[:testing] = "hash migration"
      @hash.key = "some_new_key"
      @hash[:foo].should == "bar"
    end
    it "should not whine when the hash is empty" do
      hash = Redis::BigHash.new :frequent => :plyer
      hash.key = :flyer
      hash.key.should == :flyer
    end
  end

  describe "#keys" do
    it "should return a list of all keys" do
      @hash.keys.should == ["foo", "yin"]
    end
  end

  describe "#key?" do
    it "should return true when a key is present" do
      @hash.key?(:foo).should be(true)
    end
    it "should return false when a key is not present" do
      @hash.key?(:fubar).should be(false)
    end
  end

  describe "#update" do
    it "should update BigHash with values from another hash" do
      @hash.update :test1 => "value1", :test2 => "value2"
      @hash[:test1].should == "value1"
      @hash[:test2].should == "value2"
    end
    it "should allow values to be arbitrary ruby objects" do
      t = Time.now; r = Rational(22,7)
      @hash.update :test1 => t, :test2 => r
      @hash[:test1].should == t
      @hash[:test2].to_s.should == "22/7"
    end
  end

  describe "#delete" do
    it "should return the current value" do
      @hash.delete(:foo).should == "bar"
    end
    it "should remove the value" do
      @hash.delete(:foo)
      @hash[:foo].should be_nil
    end
  end

  describe "#namespace" do
    it "should prepend the namespace onto the key" do
      @hash.namespace = "test_namespace"
      @hash.redis_key.should =~ /^test_namespace:/
    end
    it "should migrate existing values over" do
      @hash.namespace = "test_namespace"
      @hash[:foo].should == "bar"
    end
  end

  after :each do
    @hash.destroy
  end
end

