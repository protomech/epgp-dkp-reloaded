assert(loadfile(arg[1]), "Could not load " .. arg[1])()

for guild_name, guild in pairs(EPGP_Cache_DB.profiles) do
  print("Standings table for "..guild_name)
  print("<table>")
  print("<tr>", "<th>Name</th><th>EP</th><th>GP</th><th>PR</th>", "</tr>")
  for name, tbl in pairs(guild.data) do
    local EP, GP = tbl[1]+tbl[2], tbl[3]+tbl[4]
    print("<tr>")
    print("<td>", name, "</td>")
    print("<td>", EP, "</td>") -- EP
    print("<td>", GP, "</td>") -- GP
    print("<td>", GP == 0 and EP or EP/GP, "</td>") -- PR
    print("</tr>")
  end
  print("</table>")
end
