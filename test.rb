$LOAD_PATH << './lib'

require "arma"

server = Arma::Server.new("74.121.190.162", 2302)
# server = Arma::Server.new("91.121.143.123", 2392)
# server = Arma::Server.new("198.154.117.2", 4802)
server.update!

# puts "password: " + server.password?            #=> true
puts "status: " + server.status.to_s #=> :playing
puts "mod: #{server['mod']}"

if server.mission
  puts "Mission Name: #{server.mission.name}" #=> "CO 11 Foxtrot Uniform v3"
  puts "Mission Difficulty: " + server.mission.difficulty.to_s #=> :veteran
end

puts "Max Players: " + server.max_players.to_s #=> 64
puts "Players: " + server.players.size.to_s #=> 18

if server.players.size > 0
  puts "First player name: " + server.players.first.name #=> "RevDrMosesPLester"
  puts "First player deaths: " + server.players.first.deaths.to_s #=> 69
end