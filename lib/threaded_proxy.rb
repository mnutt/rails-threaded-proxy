require 'threaded_proxy/client'
require 'threaded_proxy/controller'

module ThreadedProxy
  def version
    File.open(File.expand_path("../../VERSION", __FILE__)).read.strip
  end

  extend self
end
