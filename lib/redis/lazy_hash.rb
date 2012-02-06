require 'forwardable'

class Redis
  class LazyHash
    extend Forwardable
    def_delegators :@hash, :key, :namespace, :namespace=, :destroy,
                           :reload, :reload!, :expire

    def initialize(args = nil)
      @hash = NativeHash.new(args)
      @loaded = false
    end

    def method_missing(meth, *args, &block)
      if @hash.respond_to?(meth)
        self.class.send(:define_method, meth) do |*args, &block|
          lazy_load!
          @hash.send(meth, *args, &block)
        end
        send(meth, *args, &block)
      else
        super
      end
    end

    def inspect
      lazy_load!
      @hash.inspect
    end

    def save
      @hash.save if loaded?
    end

    def loaded?
      @loaded
    end

    def to_hash
      self
    end

    private

      def lazy_load!
        unless loaded?
          reload!
          @hash.retrack!
          @loaded = true
        end
      end
    
    class << self
      def find(args)
        case args
        when Hash
          self.new(args)
        when String,Symbol
          self.new(nil=>args)
        end
      end
    end
  end
end