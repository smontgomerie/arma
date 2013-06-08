# encoding: utf-8

module Arma
  class Server
    HEADER = "\xFE\xFD\x09\xFF\xFF\xFF\x01"
    PING = "\xFE\xFD\x09"
    REQUEST = "\xff\xff\xff"
    
    include Comparable
    include Arma::ServerAttributes
    include Socket::Constants
    
    attr_reader :host, :port, :updated_at, :mission, :players
    
    def initialize(host, port = 2302)
      @host, @port = host, port.to_i
    end
    
    def update!
      send!
    end
    
    def method_missing(method_name, *args, &block)
      attributes ? attributes[method_name] : nil
    end
    
    def [](key)
      attributes[key]
    end
    
    def <=>(other)
      name <=> other.name
    end
    
    private
      attr_reader :attributes, :data, :sock
      
      def connect!
        return if connected?
        @sock = UDPSocket.new
        sock.connect(host, port)
      end
      
      def disconnect!
        sock.close unless sock.nil? || sock.closed?
      end
      
      def connected?
        !(sock.nil? || sock.closed?)
      end
      
      def send!
        connect!
        sock.send("#{HEADER}", 0)
        receive(true)
      end
      
      def receive(challenge)
        timeout = 5
        @data, = ArmaTimeout.timeout(timeout) do
          sock.recvfrom(4096)
        end
        @updated_at = Time.now

        puts "Received response " +  (challenge ? "(first packet)" : "(challenge response)")
        if challenge
          parse_challenge
        else
          parse
        end
      rescue Timeout::Error
        raise ServerUnreachableError, "connection to #{host}:#{port} timed out after #{timeout} seconds "  + (challenge ? "(first packet)" : "(challenge response)")
      rescue Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        raise ServerUnreachableError, "could not connect to #{host}:#{port}"
      ensure
        disconnect!
      end

      def handle_chr(number)
       number = ((number % 256)+256) if number < 0
       number = number % 256 if number > 255

       puts number

       number
      end

      def parse_challenge

        puts @data.bytes.to_a.join(",")
        str = @data[5..-1].to_i
        puts "challenge number : #{str}"

        challenge_response = [handle_chr(str >> 24), handle_chr(str >> 16), handle_chr(str >> 8), handle_chr(str >> 0)].pack('c*')

        puts "challenge_response: " + challenge_response.bytes.to_a.join(",")  + " " + challenge_response.bytes.to_a.map {|i| i.to_s(16) }.join(",")

        base_packet = "\xFE\xFD\x00".force_encoding("ASCII-8BIT")
        challenge_packet = "\xFE\xFD\x09".force_encoding("ASCII-8BIT")
        random_id = "\x10\x20\x30\x40".force_encoding("ASCII-8BIT")
        info_packet = "\xFF\xFF\xFF\x01".force_encoding("ASCII-8BIT")

        full_packet = base_packet + random_id + challenge_response + info_packet

        puts "full_packet: " + full_packet.bytes.to_a.map {|i| i.to_s(16) }.join(",")

        sock.send(full_packet, 0)

        receive(false)
      end
      
      def parse
        puts data
        puts data.bytes.to_a.join(",")

        raise NoDataError unless data && !data.empty?
        
        scanner = StringScanner.new(data[14..-1])

        # Extract server attributes
        scanner.skip(/\0/)
        header = scanner.scan(/\0\0\0/)
        @attributes = extract_hash!(scanner)
        
        # Extract players
        player_count = scanner.scan(/./m)
        #player_count = player_count.unpack("n").first
        player_count = @attributes['numplayers'].to_i

        players = []

        while field = scanner.scan(/[^\0]+/m)
          field = field.chomp("_").to_sym
          scanner.skip(/\0/)
          scanner.skip(/\0/)

          index = 0
          extract_array!(scanner, player_count).each do |item|
            players[index] ||= {}
            players[index][field] = item
            index += 1
          end

          scanner.skip(/\0/)
        end


        @players = players.map {|p| Player.new(p) }
        
        if status == :playing
          @mission = Mission.new(attributes, players)
        else
          @mission = nil
        end
        
        true
      end
      
      def extract_hash!(scanner)
        hash = {}
        scanner.skip(/\0/)
        while key = scanner.scan(/[^\0]+/m)


          scanner.skip(/\0/)
          hash[key] = scanner.scan(/[^\0]+/m)
          scanner.skip(/\0/)
        end
        scanner.skip(/\0/)
        hash
      end

      def extract_array!(scanner, count)
        array = []
        (0..count-1).each do
          value = scanner.scan(/[^\0]+/m)
          array << value
          scanner.skip(/\0/)
        end
        array
      end
  end
end
