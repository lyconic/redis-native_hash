class Redis
  class Marshaller
    def self.dump(value)
      case value
      when String
        value
      when Fixnum
        value
      else
        ::Marshal.dump(value) rescue nil
      end
    end

    def self.load(value)
      return nil if value.nil?
      return value unless value.start_with?("\004")
      ::Marshal.load(value) rescue value
    end
  end
end

