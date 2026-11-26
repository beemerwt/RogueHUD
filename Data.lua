local _, RH = ...
if not RH.isRogue then return end

-- Recipe spells and resulting items, ordered from lowest rank to highest rank.
-- Item IDs are checked against the installed Forever QuestieDB item metadata.
RH.poisons = {
  instant = {name = "Instant Poison", ranks = {{8681, 6947}, {8687, 6949}, {8691, 6950}, {11341, 8926}, {11342, 8927}, {11343, 8928}}},
  deadly = {name = "Deadly Poison", ranks = {{2835, 2892}, {2837, 2893}, {11357, 8984}, {11358, 8985}, {25347, 20844}}},
  crippling = {name = "Crippling Poison", ranks = {{3420, 3775}, {3421, 3776}}},
  wound = {name = "Wound Poison", ranks = {{13220, 10918}, {13228, 10920}, {13229, 10921}, {13230, 10922}}},
  mind = {name = "Mind-numbing Poison", ranks = {{5763, 5237}, {8694, 6951}, {11400, 9186}}},
}

RH.spells = {
  stealth = {1784, 1785, 1786, 1787},
  slice = {5171, 6774},
  rupture = {1943, 8639, 8640, 11273, 11274, 11275},
  riposte = {14251},
  eviscerate = {2098, 6760, 6761, 6762, 8623, 8624, 11299, 11300, 31016},
  kick = {1766, 1767, 1768, 1769},
  sprint = {2983, 8696, 11305},
  vanish = {1856, 1857},
  evasion = {5277},
  blind = {2094},
  gouge = {1776, 1777, 8629, 11285, 11286},
  kidney = {408, 8643},
  sap = {6770, 2070, 11297},
  distract = {1725},
  feint = {1966, 6768, 8637, 11303, 25302},
  pickpocket = {921},
  preparation = {14185},
  shadowstep = {36554},
  adrenaline = {13750},
  bladeflurry = {13877},
  coldblood = {14177},
  premeditation = {14183},
  mutilate = {1310707, 399956, 1241582, 1241584},
  sinister = {1752, 1757, 1758, 1759, 1760, 8621, 11293, 11294},
}

RH.essentialFallback = {"slice", "rupture", "adrenaline", "bladeflurry", "coldblood", "premeditation"}
RH.utilityFallback = {"kick", "sprint", "vanish", "evasion", "blind", "gouge", "kidney", "sap", "distract", "feint", "preparation", "shadowstep"}

function RH.SpellKeyForID(id)
  for key, ranks in pairs(RH.spells) do
    for _, rankID in ipairs(ranks) do if rankID == id then return key end end
  end
end

function RH.BestKnownForID(id)
  local key = RH.SpellKeyForID(id)
  return key and RH.KnownRank(RH.spells[key]) or (RH.Knows(id) and id or nil)
end
