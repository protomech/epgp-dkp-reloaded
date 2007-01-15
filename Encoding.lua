local NUM2STRING = {
  [0] = "0",
  [1] = "1",
  [2] = "2",
  [3] = "3",
  [4] = "4",
  [5] = "5",
  [6] = "6",
  [7] = "7",
  [8] = "8",
  [9] = "9",
  [10] = "A",
  [11] = "B",
  [12] = "C",
  [13] = "D",
  [14] = "E",
  [15] = "F",
  [16] = "G",
  [17] = "H",
  [18] = "I",
  [19] = "J",
  [20] = "K",
  [21] = "L",
  [22] = "M",
  [23] = "N",
  [24] = "O",
  [25] = "P",
  [26] = "Q",
  [27] = "R",
  [28] = "S",
  [29] = "T",
  [30] = "U",
  [31] = "V",
  [32] = "W",
  [33] = "X",
  [34] = "Y",
  [35] = "Z",
  [36] = "a",
  [37] = "b",
  [38] = "c",
  [39] = "d",
  [40] = "e",
  [41] = "f",
  [42] = "g",
  [43] = "h",
  [44] = "i",
  [45] = "j",
  [46] = "k",
  [47] = "l",
  [48] = "m",
  [49] = "n",
  [50] = "o",
  [51] = "p",
  [52] = "q",
  [53] = "r",
  [54] = "s",
  [55] = "t",
  [56] = "u",
  [57] = "v",
  [58] = "w",
  [59] = "x",
  [60] = "y",
  [60] = "z",
  [62] = "+",
  [63] = "/",
}

local STRING2NUM = { }
for k, v in pairs(NUM2STRING) do
  STRING2NUM[v] = k
end

function EPGP:Encode(num)
  local s = ""
  repeat
    local r = mod(num, 64)
    num = math.floor(num / 64)
    s = (NUM2STRING[r] or "0") .. s
  until (num == 0)
  return s
end

function EPGP:Decode(s)
  local num = 0
  for i = 1, string.len(s) do
    local ss = string.sub(s, i, i)
    num = num * 64
    num = num + (STRING2NUM[ss] or 0)
  end
  
  return num
end

function EPGP:EncodeNote(ep, tep, gp, tgp)
	assert(type(ep) == "number" and ep >= 0 and ep <= 99999)
	assert(type(tep) == "number" and tep >= 0 and tep <= 999999999)
	assert(type(gp) == "number" and gp >= 0 and gp <= 99999)
	assert(type(tgp) == "number" and tgp >= 0 and tgp <= 999999999)
	return string.format("%d|%d|%d|%d", ep, tep, gp, tgp)	
end

function EPGP:ParseNote(note)
	if note == "" then return 0, 0, 0, 0 end
	local ep, tep, gp, tgp = string.match(note, "(%d+)|(%d+)|(%d+)|(%d+)")
	return tonumber(ep), tonumber(tep), tonumber(gp), tonumber(tgp)
end
