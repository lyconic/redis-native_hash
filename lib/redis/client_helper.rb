class Redis
  class Client
    def self.default
      @@default_connection ||= ::Redis.new
    end
    def self.default=(connection)
      @@default_connection = connection
    end
  end
  module ClientHelper
    def self.included(base)
      base.send(:extend,  ClassMethods)
      base.send(:include, InstanceMethods)
    end
    module InstanceMethods
      def redis
        @redis ||= self.class.redis
      end
      def redis=(connection)
        @redis = connection
      end
    end
    module ClassMethods
      def redis
        @@redis ||= ::Redis::Client.default
      end
      def redis=(connection)
        @@redis = connection
      end
    end
  end
end
