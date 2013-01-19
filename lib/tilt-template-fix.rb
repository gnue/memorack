require 'tilt'
require 'active_support/all'


module Tilt
  class KramdownTemplate
    def prepare_with_utf8
      data.force_encoding('UTF-8')
      prepare_without_utf8
    end

    alias_method_chain :prepare, :utf8
  end

  class BlueClothTemplate
    def prepare_with_utf8
      data.force_encoding('UTF-8')
      prepare_without_utf8
    end

    alias_method_chain :prepare, :utf8
  end

  class MarukuTemplate
    def prepare_with_utf8
      data.force_encoding('UTF-8')
      prepare_without_utf8
    end

    alias_method_chain :prepare, :utf8
  end

  class ScssTemplate
    def prepare_with_utf8
      data.force_encoding('UTF-8')
      prepare_without_utf8
    end

    alias_method_chain :prepare, :utf8
  end
end
