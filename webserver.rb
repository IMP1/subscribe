#!/usr/bin/ruby

##
## Test with this link (jimquisition playlist):
## localhost:2345/playlist/PLlRceUcRZcK0E1Id3NHchFaxikvCvAVQe
##

require 'socket'
require 'uri'
require 'net/http'
require 'json'
require 'date'

require_relative 'container'

Thread.abort_on_exception=true

class WebServer

    EMPTY_LINE =  "\r\n"

    def initialize(port)
        @port = port
        if File.exists?('keys/google_api')
            @api_key = File.read('keys/google_api')
        else
            puts "Could not find 'keys/google_api' file."
            puts "Please create a file (without an extension) in this location."
            puts "This file should contain only your google api key."
            system("pause")
            exit(0)
        end
    end

    def stop
        @thread.kill
        @server.close
    end

    def begin(block=false)
        @server = TCPServer.new('localhost', @port)
        puts "Listing on localhost:#{@port}..." 
        @thread = Thread.new { listen }
        @thread.join if block
    end

    def listen
        loop do
            Thread.start(@server.accept) do |connection|
                handle_connection(connection)
            end
        end
    end

    def handle_connection(socket)
        puts
        puts "Connected to socket: #{socket}"
        request = socket.gets
        handle_request(socket, request)
        socket.close
    end

    def handle_request(socket, request)
        puts "Received request: #{request}"
        request_method, *request_parts = request.split(" ")
        case request_method
        when "GET"
            path = request_parts[0].split('/')
            handle_get(socket, path)
        when "HEAD"
            handle_head(socket, request_parts)
        end
    end

    def handle_get(socket, path)
        action = path[1]
        case action
        when 'about'
        when 'playlist'
            serve_playlist(socket, path[2])
        else
            file_not_found(socket)
        end
    end

    def handle_head(socket, request_parts)

    end

    def serve_playlist(socket, playlist_id)
        model = playlist_model(playlist_id)        

        file_string = File.read("public/playlist.rxml")
        file_string.gsub!(/<ruby>(.+?)<\/ruby>/m) { eval($1).to_s }

        socket.print http_header(200, "OK", 'text/xml', file_string.bytesize)
        socket.print EMPTY_LINE
        socket.print file_string 
    end

    def playlist_model(playlist_id)
        model = Container.new

        uri = URI("https://www.googleapis.com/youtube/v3/playlistItems?" + 
                  "part=snippet&maxResults=10&playlistId=#{playlist_id}&key=#{@api_key}")
        response = Net::HTTP.get(uri)
        json = JSON.parse(response)
        playlist_data = json['items'][0]

        model.add('info')
        model.info.add('playlist_id', playlist_id)
        model.info.add('title', playlist_data['snippet']['title'])
        model.info.add('description', playlist_data['snippet']['description'])
        model.info.add('publication_datetime', playlist_data['snippet']['publishedAt'])
        model.info.add('last_update', DateTime.now)

        model.add('videos', [])

        uri = URI("https://www.googleapis.com/youtube/v3/playlistItems?" + 
                  "part=snippet&maxResults=10&playlistId=#{playlist_id}&key=#{@api_key}")
        response = Net::HTTP.get(uri)
        json = JSON.parse(response)
        playlist_items = json['items']
        playlist_items.each do |video|
            v = Container.new
            v.add('id', video['id'])
            v.add('title', video['snippet']['title'])
            v.add('link', video['snippet']['resourceId']['videoId'])
            v.add('datetime', video['snippet']['publishedAt'])
            v.add('description', video['snippet']['description'])
            model.videos.push(v)
        end

        return model
    end


    def file_not_found(socket)
        message = "File not found\n"
        socket.print http_header(404, "Not Found", "text/plain", message.size)
        socket.print EMPTY_LINE
        socket.print message
    end

    def http_header(status_code, status_message, content_type, content_length)
        response = "HTTP/1.1 #{status_code} #{status_message}\r\n" + 
                   "Content-Type: #{content_type}\r\n" + 
                   "Content-Length: #{content_length}\r\n" + 
                   "Connection: close\r\n"
        response
    end

end

puts
webserver = WebServer.new(2345)
webserver.begin

loop do
    command = gets.chomp
    if command == "q"
        break
    end
end

webserver.stop