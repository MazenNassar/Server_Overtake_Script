local scores = {}
local json = require('json')

ac.onSharedEvent("scoreUpdate", function(data, senderName, senderType, senderID)
  local d = json.decode(data)
  scores[d.name] = {
    name = d.name,
    drift = d.drift,
    overtake = d.overtake,
    total = d.total,
    highest = d.highest
  }

  -- Sort and rebroadcast
  local list = {}
  for _, v in pairs(scores) do table.insert(list, v) end
  table.sort(list, function(a, b) return a.highest > b.highest end)

  ac.broadcastSharedEvent("leaderboardData", json.encode(list))
end)