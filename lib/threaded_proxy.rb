# frozen_string_literal: true

require 'threaded_proxy/client'
require 'threaded_proxy/controller'

module ThreadedProxy
  def version
    File.open(File.expand_path('../VERSION', __dir__)).read.strip
  end
end
