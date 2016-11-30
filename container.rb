class Container

    def initialize
        @table = {}
    end

    def add(key, value=nil)
        set(key, value.nil? ? Container.new : value)
    end

    def []=(key, value)
        set(key, value)
    end

    def [](key)
        get(key)
    end

    def set(key, value)
        @table[key] = value
        define_singleton_method key do
            return value
        end 
    end

    def get(key)
        return @table[key]
    end

end