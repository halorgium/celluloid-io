require 'celluloid/io/version'

require 'celluloid'
require 'celluloid/io/dns_resolver'
require 'celluloid/io/mailbox'
require 'celluloid/io/reactor'
require 'celluloid/io/stream'

require 'celluloid/io/tcp_server'
require 'celluloid/io/tcp_socket'
require 'celluloid/io/udp_socket'
require 'celluloid/io/unix_server'
require 'celluloid/io/unix_socket'

require 'celluloid/io/ssl_server'
require 'celluloid/io/ssl_socket'

module Celluloid
  # Actors with evented IO support
  module IO
    def self.included(klass)
      klass.send :include, Celluloid
      klass.reactor_classes << Celluloid::IO::Reactor
    end

    def self.reactor
      Thread.current[:celluloid_io_reactor]
    end

    def self.evented?
      !!reactor
    end

    def wait_readable(io)
      io = io.to_io
      if IO.reactor
        IO.reactor.wait_readable(io)
      else
        Kernel.select([io])
      end
      nil
    end
    module_function :wait_readable

    def wait_writable(io)
      io = io.to_io
      if IO.reactor
        IO.reactor.wait_writable(io)
      else
        Kernel.select([], [io])
      end
      nil
    end
    module_function :wait_writable
  end
end
