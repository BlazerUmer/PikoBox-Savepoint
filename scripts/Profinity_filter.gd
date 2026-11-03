class_name NameFilter
extends RefCounted
#name profanity filter (English + romanized Urdu/Hindi + a few Urdu-script words).
#usage: if not NameFilter.is_clean(text): ...
#
#strong words are blocked anywhere inside the name, even with spaces/_/- between
#the letters ("mad_arch od") or number swaps 
#weak words are only blocked when they are a whole word, because they sit inside
#innocent names ("Lundgren", "Sexton", "Randi").

#curse words below.be careful










const STRONG := [
	#English
	"fuck", "shit", "bitch", "cunt", "nigger", "nigga", "faggot", "fagot",
	"whore", "slut", "asshole", "bastard", "pussy","fucker","boob","vagina","randi",
	#Romanized Urdu / Hindi / Punjabi
	"chutiya", "chutia", "chutiye", "chutya",
	"madarchod", "maderchod", "madrchod", "madarchd",
	"behenchod", "bhenchod", "benchod", "bhnchod", "behnchod",
	"bhosdike", "bhosdi", "bhosda", "bhosad",
	"harami", "haramzada", "haramzade", "haramkhor",
	"gandu", "gaandu", "lauda", "lavda", "loda",
	"kanjar", "kanjri", "rundi",
	#Urdu script
	"چوتیا", "مادرچود", "بہنچود", "گانڈو", "حرامی",
]

const WEAK := [
	"lund", "lun", "gand", "gaand", "chut", "randi",
	"kutta", "kutti", "kuta", "tatti",
	"bkl", "mkc", "bsdk",
	"dick", "cock", "sex", "porn", "rape", "nazi",
]

const LEET := {
	"0": "o", "1": "i", "3": "e", "4": "a", "5": "s",
	"7": "t", "@": "a", "$": "s", "!": "i",
}


static func is_clean(name_text: String) -> bool:
	var lowered: String = _leet(name_text.strip_edges().to_lower())

	# 1)Strong words anywhere, ignoring separators
	var compact: String = lowered.replace(" ", "").replace("_", "").replace("-", "")
	compact = _squash(compact)
	for w in STRONG:
		if compact.contains(str(w)):
			return false

	# 2)Weak words only as whole words
	var spaced: String = lowered.replace("_", " ").replace("-", " ")
	for token in spaced.split(" ", false):
		var t: String = _squash(token)
		for w in WEAK:
			if t == str(w):
				return false

	return true


#swaps look-alike digits/symbols for letters (ch00tiya -> chootiya)
static func _leet(s: String) -> String:
	var out := ""
	for ch in s:
		out += LEET.get(ch, ch)
	return out


#shortens runs of 3+ identical letters to one (fuuuck -> fuck); double letters stay
static func _squash(s: String) -> String:
	var out := ""
	var i := 0
	while i < s.length():
		var ch := s[i]
		var j := i
		while j < s.length() and s[j] == ch:
			j += 1
		var run := j - i
		out += ch if run >= 3 else ch.repeat(run)
		i = j
	return out
