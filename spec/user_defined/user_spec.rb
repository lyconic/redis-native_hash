require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class User < RedisHash
  attr_persist :username, :password, :email
  #attr_index :username
end

describe User do
  before :each do
    @user = User.new :username => "test", :email => "test@test.com", :random_key => "random value"
    @user.save
  end

  describe ".find" do
    it "should find the user by key" do
      user = User.find(@user.key)
      user.username.should      == "test"
      user.email.should         == "test@test.com"
      user[:random_key].should  == "random value"
    end
  end

  after :each do
    @user.destroy
  end
end

