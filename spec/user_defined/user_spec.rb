require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class User < RedisHash
  def namespace
    :user
  end

  def self.find(key)
    super(:user=>key)
  end
end

describe User do
  before :each do
    @user = User.new :username => "test", :email => "test@test.com"
    puts "about to call save #{@user.inspect} (#{@user.key})"
    @user.save
    puts "after save (#{@user.key})"
  end

  describe ".find" do
    it "should find the user by key" do
      user = User.find(@user.key)
      user[:username].should == "test"
    end
  end
end

