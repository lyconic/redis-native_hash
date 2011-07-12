require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Redis::TrackedHash do
  before :each do
    @hash = Redis::TrackedHash[:a=>33,:b=>34,:c=>35,:d=>36]
  end

  describe "#added" do
    it "should track new keys added" do
      @hash.track!
      @hash[:dolphin] = "value"
      @hash.added.should == [:dolphin]
    end
    it "should not track additions if #track not called" do
      @hash[:dolphin] = "mammal"
      @hash.added.should == []
    end
  end

  describe "#changed" do
    it "tracks changes to existing keys" do
      @hash.track!
      @hash[:b] += 2
      @hash.changed.should == [:b]
    end
    it "doesn't track changes if #track has not been called" do
      @hash[:b] += 3
      @hash.changed.should == []
    end
    it "should track new keys" do
      @hash.track!
      @hash[:test] = 47
      @hash.changed.should == [:test]
    end
  end

  describe "#deleted" do
    it "should track when you delete a key" do
      @hash.track!
      @hash.delete(:b)
      @hash.deleted.should == [:b]
    end
    it "should allow you to assign to a key that has been deleted" do
      @hash.track!
      @hash.delete(:b)
      @hash[:b] = "new value"
      @hash.deleted.should == []
      @hash[:b].should == "new value"
    end
  end

  describe "#merge!" do
    before :each do
      @other_hash = @hash.dup
      @hash.track!; @other_hash.track!
    end
    it "maintains change from both Redis::TrackedHash" do
      @hash[:a] = 64; @other_hash[:c]=96
      @hash.merge!(@other_hash).should == {:a=>64,:b=>34,:c=>96,:d=>36}
    end
    it "gives precedence to changes in other_hash" do
      @hash[:b] = 14; @other_hash[:b] = 77
      @hash.merge!(@other_hash)
      @hash[:b].should == 77
    end
    it "always deletes keys deleted in other_hash" do
      @other_hash.delete(:d)
      @hash[:d] = "foo"
      @hash.merge!(@other_hash)
      @hash.has_key?(:d).should == false
    end
    it "allows assignment to a key that has been deleted after a #merge" do
      @other_hash.delete(:d)
      @hash.merge!(@other_hash)
      @hash[:d] = 77
      @hash.deleted.should == []
      @hash[:d].should == 77
    end
    it "should merge everything from a regular hash" do
      @hash.merge!( { :c => "bar", :foo => "poo" } )
      @hash.changed.should include(:c, :foo)
    end
  end
end

